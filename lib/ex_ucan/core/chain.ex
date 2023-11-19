defmodule Ucan.ProofChains do
  alias Ucan.Token
  alias Ucan

  @type t :: %__MODULE__{
          ucan: Ucan.t(),
          proofs: list(__MODULE__.t()),
          redelegations: map()
        }
  defstruct [:ucan, :proofs, :redelegations]

  # TODO: docs
  # TODO: Redelegations, for that we need capabilitySemantics
  @spec from_ucan(Ucan.t(), store :: UcanStore.t()) ::
          {:ok, __MODULE__.t()} | {:error, String.t()}
  def from_ucan(ucan, store) do
    _ = UcanStore.impl_for!(store)

    with :ok <- Token.validate(ucan),
         {:ok, prf_chains} <- create_proof_chains(ucan, store) do
      {:ok,
       %__MODULE__{
         ucan: ucan,
         proofs: prf_chains,
         redelegations: %{}
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
end
