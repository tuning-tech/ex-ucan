defmodule Ucan.Builder do
  @moduledoc """
  Concise builder functions for UCAN tokens
  """
  require Logger
  alias Ucan
  alias Ucan.Capability
  alias Ucan.Capability.Semantics
  alias Ucan.Capability.View
  alias Ucan.Keymaterial
  alias Ucan.ProofDelegationSemantics
  alias Ucan.Token
  alias Ucan.UcanPayload

  # @type hash_type :: :sha1 | :sha2_256 | :sha2_512 | :sha3 | :blake2b | :blake2s | :blake3

  @type hash_type :: :sha2_256 | :blake3

  @type t :: %__MODULE__{
          issuer: Keymaterial.t(),
          audience: String.t(),
          capabilities: list(Capability),
          lifetime: number(),
          expiration: number(),
          not_before: number(),
          facts: map(),
          proofs: list(String.t()),
          add_nonce?: boolean()
        }
  defstruct [
    :issuer,
    :audience,
    :capabilities,
    :lifetime,
    :expiration,
    :not_before,
    :facts,
    :proofs,
    :add_nonce?
  ]

  @doc """
    Creates an empty builder.
    Before finalising the builder, we need to at least call:
    - `issued_by`
    - `to_audience` and one of
    - `with_lifetime` or `with_expiration`.
    To finalise the builder, call its `build` method.
  """
  @spec default :: __MODULE__.t()
  def default do
    %__MODULE__{
      issuer: nil,
      audience: nil,
      capabilities: [],
      lifetime: nil,
      expiration: nil,
      not_before: nil,
      facts: %{},
      proofs: [],
      add_nonce?: false
    }
  end

  @doc """
  The UCAN must be signed with the private key of the issuer to be valid.
  """
  @spec issued_by(__MODULE__.t(), Keymaterial.t()) :: __MODULE__.t()
  def issued_by(%__MODULE__{} = builder, keymaterial) do
    %{builder | issuer: keymaterial}
  end

  @doc """
  This is the identity this UCAN transfers rights to.

  It could e.g. be the DID of a service you're posting this UCAN as a JWT to,
  or it could be the DID of something that'll use this UCAN as a proof to
  continue the UCAN chain as an issuer.
  """
  @spec for_audience(__MODULE__.t(), String.t()) :: __MODULE__.t()
  def for_audience(%__MODULE__{} = builder, audience) when is_binary(audience) do
    %{builder | audience: audience}
  end

  @doc """
  The number of seconds into the future (relative to when build() is
  invoked) to set the expiration. This is ignored if an explicit expiration
  is set.
  """
  @spec with_lifetime(__MODULE__.t(), integer()) :: __MODULE__.t()
  def with_lifetime(%__MODULE__{} = builder, seconds) when is_integer(seconds) do
    %{builder | lifetime: seconds}
  end

  @doc """
  Set the POSIX timestamp (in seconds) for when the UCAN should expire.
  Setting this value overrides a configured lifetime value.
  """
  @spec with_expiration(__MODULE__.t(), integer()) :: __MODULE__.t()
  def with_expiration(%__MODULE__{} = builder, timestamp) when is_integer(timestamp) do
    %{builder | expiration: timestamp}
  end

  @doc """
  Set the POSIX timestamp (in seconds) of when the UCAN becomes active.
  """
  @spec not_before(__MODULE__.t(), integer()) :: __MODULE__.t()
  def not_before(%__MODULE__{} = builder, timestamp) do
    %{builder | not_before: timestamp}
  end

  @doc """
  Add a fact or proof of knowledge to this UCAN.
  """
  @spec with_fact(__MODULE__.t(), String.t(), any()) :: __MODULE__.t()
  def with_fact(%__MODULE__{} = builder, key, fact) when is_binary(key) do
    %{builder | facts: Map.put(builder.facts, key, fact)}
  end

  @doc """
  Will ensure that the built UCAN includes a number used once.
  """
  @spec with_nonce(__MODULE__.t()) :: __MODULE__.t()
  def with_nonce(%__MODULE__{} = builder) do
    %{builder | add_nonce?: true}
  end

  @doc """
  Includes a UCAN in the list of proofs for the UCAN to be built.
  Note that the proof's audience must match this UCAN's issuer
  or else the proof chain will be invalidated!

  The proof is encoded into a [Cid], hashed with given hash (blake3 by default)
  algorithm, unless one is provided.
  """
  @spec witnessed_by(__MODULE__.t(), Ucan.t(), hash_type()) :: __MODULE__.t()
  def witnessed_by(builder, authority_ucan, hash_type \\ :blake3)

  def witnessed_by(%__MODULE__{} = builder, %Ucan{} = authority_ucan, hash_type) do
    case Token.to_cid(authority_ucan, hash_type) do
      {:ok, cid} ->
        %{builder | proofs: [cid | builder.proofs]}

      {:error, error} ->
        Logger.warning("Failed to add authority to proofs: #{error}")
        builder
    end
  end

  @doc """
  Claim a capability by inheritance (from an authorizing proof) or
  implicitly by ownership of the resource by this UCAN's issuer
  """
  @spec claiming_capability(__MODULE__.t(), Capability.t()) :: __MODULE__.t()
  def claiming_capability(builder, %Capability{} = capability) do
    %{builder | capabilities: builder.capabilities ++ [capability]}
  end

  @spec claiming_capability(__MODULE__.t(), Capability.View.t()) :: __MODULE__.t()
  def claiming_capability(builder, %Capability.View{} = capability_view) do
    capability = Capability.new(capability_view)
    %{builder | capabilities: builder.capabilities ++ [capability]}
  end

  @spec claiming_capabilities(__MODULE__.t(), list(Capability)) :: __MODULE__.t()
  def claiming_capabilities(builder, capabilities) when is_list(capabilities) do
    %{builder | capabilities: builder.capabilities ++ capabilities}
  end

  @doc """
  Delegate all capabilities from a given proof to the audience of the UCAN
  you're building.
  The proof is encoded into a CID, hashed with given hash (blake3 by default)
  algorithm, unless one is provided.
  """
  @spec delegating_from(__MODULE__.t(), Ucan.t(), hash_type()) :: __MODULE__.t()
  def delegating_from(builder, authority_ucan, hash_type \\ :blake3) do
    case Token.to_cid(%Ucan{} = authority_ucan, hash_type) do
      {:ok, cid} ->
        builder = %{builder | proofs: [cid | builder.proofs]}
        proof_index = length(builder.proofs) - 1
        proof_delegation = %ProofDelegationSemantics{}

        case Semantics.parse(proof_delegation, "prf:#{proof_index}", "ucan/DELEGATE", nil) do
          %View{} = cap_view ->
            capability = Capability.new(cap_view)
            %{builder | capabilities: builder.capabilities ++ [capability]}

          _ ->
            Logger.warning("Could not produce delegation capability")
            builder
        end

      {:error, err} ->
        Logger.warning("Could not encode authoritative UCAN: #{err}")
        builder
    end
  end

  @doc """
  Builds the UCAN `payload` from the `Builder` workflow

  A runtime exception is raised if build payloads fails.

  A sample builder workflow to create ucan payload

  ```Elixir
  alias Ucan.Builder

  keypair = Ucan.create_default_keypair()

  Ucan.Builder.default
  |> Builder.issued_by(keypair)
  |> Builder.for_audience("did:key:z6MkwDK3M4PxU1FqcSt4quXghquH1MoWXGzTrNkNWTSy2N")
  |> Builder.with_lifetime(864000)
  |> Builder.build!
  ```
  """
  @spec build!(__MODULE__.t()) :: UcanPayload.t()
  def build!(%__MODULE__{} = builder) do
    case Token.build_payload(builder) do
      {:ok, payload} -> payload
      {:error, err} -> raise err
    end
  end

  @doc """
  Builds the UCAN `payload` from the `Builder` struct

  An error tuple with reason is returned if build payloads fails.
  """
  @spec build(__MODULE__.t()) :: {:ok, UcanPayload.t()} | {:error, String.t()}
  def build(%__MODULE__{} = builder) do
    Token.build_payload(builder)
  end
end
