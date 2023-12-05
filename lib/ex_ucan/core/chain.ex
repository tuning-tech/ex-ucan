defmodule Ucan.ProofChains do
  alias Ucan.ProofSelection
  alias Ucan.ProofSelection.Index
  alias Ucan.Capability.ResourceUri.Scoped
  alias Ucan.Capability.Resource.ResourceType
  alias Ucan.Capability.ResourceUri
  alias Ucan.Capability.Resource
  alias Ucan.Capability.View
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
         redelegations when is_list(redelegations) <- create_redelegations(ucan, prf_chains) do
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
        %View{
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

        %View{
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
          redelegations
      end
    end)
  end
end
