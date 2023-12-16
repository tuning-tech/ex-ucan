defmodule Ucan.ProofChains do
  alias Ucan.Capability
  alias Ucan.CapabilityInfo
  alias Ucan.ProofSelection
  alias Ucan.ProofSelection.Index
  alias Ucan.Capability.ResourceUri.Scoped
  alias Ucan.Capability.Resource.ResourceType
  alias Ucan.Capability.ResourceUri
  alias Ucan.Capability.Resource
  alias Ucan.Capability.Semantics
  alias Ucan.ProofDelegationSemantics
  alias Ucan.Capabilities
  alias Ucan.Token
  alias Ucan

  require IEx

  @type t :: %__MODULE__{
          ucan: Ucan.t(),
          proofs: list(__MODULE__.t()),
          redelegations: list()
        }
  defstruct [:ucan, :proofs, :redelegations]

  # TODO: docs
  @spec from_ucan(Ucan.t(), store :: UcanStore.t()) ::
          {:ok, __MODULE__.t()} | {:error, String.t()}
  def from_ucan(ucan, store) do
    _ = UcanStore.impl_for!(store)

    with :ok <- Token.validate(ucan),
         {:ok, prf_chains} <- create_proof_chains(ucan, store),
         redelegations when is_list(redelegations) <-
           create_redelegations(ucan, prf_chains) do
      {:ok,
       %__MODULE__{
         ucan: ucan,
         proofs: prf_chains,
         redelegations: redelegations
       }}
    end
  end

  # TODO: docs
  @spec from_token_string(String.t(), UcanStore) :: {:ok, __MODULE__.t()} | {:error, String.t()}
  def from_token_string(ucan_token, store) do
    with {:ok, ucan} <- Token.decode(ucan_token) do
      from_ucan(ucan, store)
    end
  end

  # TODO: docs
  @spec from_cid(String.t(), UcanStore.t()) :: {:ok, __MODULE__.t()} | {:error, String.t()}
  def from_cid(cid, store) do
    with {:ok, token} <- UcanStore.read(store, cid) do
      from_token_string(token, store)
    end
  end

  @spec reduce_capabilities(__MODULE__.t(), Semantics.t()) :: list(CapabilityInfo.t())
  def reduce_capabilities(%__MODULE__{} = chain, %_{} = semantics) do
    # get ancestral attentuations or inherited attenuations, excluding redelegations

    ancestral_capability_infos =
      Enum.with_index(chain.proofs)
      |> Enum.flat_map(fn {ancestor_chain, index} ->
        if index in chain.redelegations do
          []
        else
          reduce_capabilities(ancestor_chain, semantics)
        end
      end)

    # get redelegated caps by prf resource
    redelegated_capability_infos =
      chain.redelegations
      |> Enum.flat_map(fn index ->
        Enum.at(chain.proofs, index)
        |> reduce_capabilities(semantics)
        |> Enum.map(fn %CapabilityInfo{} = cap_info ->
          %CapabilityInfo{
            originators: cap_info.originators,
            capability: cap_info.capability,
            not_before: Ucan.not_before(chain.ucan),
            expires_at: Ucan.expires_at(chain.ucan)
          }
        end)
      end)

    # cross-checking the claimed caps with ancestor's
    # if no proofs, then iter through valid capability (views)
    # create capabilityInfo with originator being ucan's issuer, and nbf, exp being ucan's

    self_capability_stream =
      Ucan.capabilities(chain.ucan)
      |> Capabilities.map_to_sequence()
      |> Stream.map(fn %Capability{} = capability ->
        Semantics.parse(
          semantics,
          to_string(capability.resource),
          to_string(capability.ability),
          capability.caveat
        )
      end)
      |> Stream.take_while(fn elem -> is_struct(elem) end)

    self_capability_infos =
      if Enum.empty?(chain.proofs) do
        self_capability_stream
        |> Enum.map(fn %Capability.View{} = cap ->
          %CapabilityInfo{
            originators: [Ucan.issuer(chain.ucan)],
            capability: cap,
            not_before: Ucan.not_before(chain.ucan),
            expires_at: Ucan.expires_at(chain.ucan)
          }
        end)
      else
        # try to find the originators from the ancestral cap_infos..
        self_capability_stream
        |> Enum.map(fn %Capability.View{} = cap_view ->
          originators =
            Enum.reduce(ancestral_capability_infos, [], fn %CapabilityInfo{} =
                                                                         ancestor_cap_info,
                                                                       originators ->

              if Capability.View.enables?(ancestor_cap_info.capability, cap_view) do
                originators ++ ancestor_cap_info.originators
              else
                originators
              end
            end)
            |> case do
              [] -> [Ucan.issuer(chain.ucan)]
              originators -> originators
            end

          %CapabilityInfo{
            originators: originators,
            capability: cap_view,
            not_before: Ucan.not_before(chain.ucan),
            expires_at: Ucan.expires_at(chain.ucan)
          }
        end)
      end

    # Why these are appended??
    self_capability_infos =
      (self_capability_infos ++ redelegated_capability_infos)

    # merge all these caps into one , non-redundant (prolly)
    # ensuring discrete orignators

    Enum.reduce(
      Enum.reverse(self_capability_infos),
      {[], self_capability_infos},
      fn %CapabilityInfo{} = last_cap_info, merge_cap_info_tuple ->
        {_, remaining_cap_infos} = merge_cap_info_tuple
        # we don't need the last element, since we are going to operate against it.
        remaining_cap_infos = Enum.slice(remaining_cap_infos, 0, length(remaining_cap_infos) - 1)


        case consolidate_capability_info(remaining_cap_infos, last_cap_info) do
          {resulting_cap_info, false} ->
            {merge_cap_list, _remaining_cap_info} = merge_cap_info_tuple

            {merge_cap_list ++ [last_cap_info], resulting_cap_info}

          {resulting_cap_info, true} ->
            {merge_cap_list, _remaining_cap_info} = merge_cap_info_tuple
            {merge_cap_list, resulting_cap_info}
        end
      end
    )
    |> then(fn {merge_cap_list, _resulting_cap_infos} -> merge_cap_list end)
  end

  # We could say `last_cap_info` was the last element in `self_capability_infos` list
  @spec consolidate_capability_info(list(CapabilityInfo.t()), CapabilityInfo.t()) ::
          {list(CapabilityInfo.t()), consolidated? :: boolean()}
  defp consolidate_capability_info(remaining_cap_infos, %CapabilityInfo{} = last_cap_info)
       when is_list(remaining_cap_infos) do
    Enum.reduce_while(
      remaining_cap_infos,
      # {current_index, remaingin_cap_info, consolidated}
      {-1, remaining_cap_infos, false},
      fn %CapabilityInfo{} = remaining_cap_info, result ->
        if Capability.View.enables?(remaining_cap_info.capability, last_cap_info.capability) do
          # index is for knowing the current iterated remaingin_cap_info, so that we can replace it with
          # the modified one.
          {index, result_cap_infos, _consolidated?} = result

          %{
            remaining_cap_info
            | originators:
                :ordsets.union(
                  remaining_cap_info.originators,
                  last_cap_info.originators
                )
          }
          # This kind of makes a new remaining_cap_info, by replacing the consolidated cap_info element only.
          |> then(&List.replace_at(result_cap_infos, index + 1, &1))
          |> then(&{index + 1, &1, true})
          # Once we consolidated the last_cap_info, we can exit the loop, and send the new consolidate `remaining_cap_info` to the caller
          |> then(&{:halt, &1})
        else
          {index, result_cap_infos, consolidated?} = result
          {:cont, {index + 1, result_cap_infos, consolidated?}}
        end
      end
    )
    |> then(fn {_, result_cap_infos, consolidated?} -> {result_cap_infos, consolidated?} end)
  end

  @spec validate_link_to(__MODULE__.t(), Ucan.t()) :: :ok | {:error, String.t()}
  defp validate_link_to(proof_chain, ucan) do
    audience = Ucan.audience(proof_chain.ucan)
    issuer = Ucan.issuer(ucan)

    with {true, _} <- {issuer == audience, :eq},
         {true, _} <- {Ucan.lifetime_encompasses?(proof_chain.ucan, ucan), :lifetime} do
      :ok
    else
      {false, :eq} ->
        {:error,
         "Invalid UCAN link: audience - [#{audience}] does not match issuer - [#{issuer}]"}

      {false, :lifetime} ->
        {:error, "Invalid UCAN link: lifetime exceeds attenuation"}
    end
  end

  @spec create_proof_chains(Ucan.t(), UcanStore) ::
          {:ok, list(__MODULE__.t())} | {:error, String.t()}
  defp create_proof_chains(ucan, store) do
    Ucan.proofs(ucan)
    |> Enum.reduce_while([], fn prf, prf_chains ->
      with {:ok, ucan_token} <- UcanStore.read(store, prf),
           {:ok, proof_chain} <- from_token_string(ucan_token, store),
           :ok <- validate_link_to(proof_chain, ucan) do
        {:cont, [proof_chain | prf_chains]}
      else
        {:error, err} -> {:halt, {:error, err}}
      end
    end)
    |> case do
      res when is_list(res) -> {:ok, res}
      err -> err
    end
  end

  # Is this return type good??
  @spec create_redelegations(Ucan.t(), list(__MODULE__.t())) :: list() | {:error, String.t()}
  defp create_redelegations(%Ucan{} = ucan, proof_chains) when is_list(proof_chains) do
    proof_delegation_semantics = %ProofDelegationSemantics{}

    Ucan.capabilities(ucan)
    |> Capabilities.map_to_sequence()
    |> Enum.reduce_while(:ordsets.new(), fn capability, redelegations ->
      case Semantics.parse_capability(proof_delegation_semantics, capability) do
        %Capability.View{
          resource: %Resource{
            type: %ResourceType{
              kind: %ResourceUri{
                type: %Scoped{scope: %ProofSelection{type: %Index{value: index}}}
              }
            }
          }
        } ->
          if index < length(proof_chains) do
            {:cont, :ordsets.add_element(index, redelegations)}
          else
            {:halt, {:error, "Unable to redelegate proof; no proof at zero based index #{index}"}}
          end

        %Capability.View{
          resource: %Resource{
            type: %ResourceType{
              kind: %ResourceUri{type: %Scoped{scope: %ProofSelection{type: :all}}}
            }
          }
        } ->
          Enum.reduce(0..length(proof_chains), redelegations, fn index, redelegations ->
            {:cont, :ordsets.add_element(index, redelegations)}
          end)

        _ ->
          {:cont, redelegations}
      end
    end)
  end
end
