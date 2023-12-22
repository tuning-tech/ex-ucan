defmodule Ucan do
  @moduledoc """
  Documentation for `Ucan`.
  """
  alias Ucan.DidParser
  alias Ucan.Keymaterial
  alias Ucan.Keymaterial.Ed25519
  alias Ucan.Token

  alias Ucan.UcanHeader
  alias Ucan.UcanPayload

  @typedoc """
  Ucan structure

  header - Token Header

  payload - Token payload

  signed_data - Data that would be eventually signed

  signature - Base64Url encoded signature
  """
  @type t :: %__MODULE__{
          header: UcanHeader.t(),
          payload: UcanPayload.t(),
          signed_data: String.t(),
          signature: String.t()
        }

  defstruct [:header, :payload, :signed_data, :signature]

  @doc """
  Creates a default `Ucan.DidParser` which has a default support for
  ed25519 algorithm's `Ucan.Keymaterial` implementation.

  Keymaterial generated with different algorithms like RSA will be coming soon..
  """
  @spec create_default_did_parser :: DidParser.t()
  def create_default_did_parser do
    DidParser.new(DidParser.get_default_constructors())
  end

  @doc """
  Creates a default Keymaterial implementation of Ed25519 algorithm
  """
  @spec create_default_keymaterial :: Keymaterial.t()
  def create_default_keymaterial do
    Ed25519.create()
  end

  @doc """
  Signs the payload with Keymaterial and returns a UCAN struct

  - payload - `Ucan.UcanPayload`
  - Keymaterial - A `Ucan.Keymaterial` implemented struct
  """
  @spec sign(payload :: UcanPayload.t(), Keymaterial.t()) :: __MODULE__.t()
  def sign(%UcanPayload{} = payload, keymaterial) do
    Token.sign_with_payload(payload, keymaterial)
  end

  @doc """
  Encode the `Ucan.t()` struct to JWT token string
  """
  @spec encode(__MODULE__.t()) :: String.t()
  def encode(%Ucan{} = ucan) do
    Token.encode(ucan)
  end

  @doc """
  Validate the UCAN token's signature and timestamps

  - token - `Ucan` token or encoded jwt token string
  - did_parser - `Ucan.DidParser`
  """
  @spec validate(String.t() | __MODULE__.t(), DidParser.t()) :: :ok | {:error, String.t()}
  def validate(token, did_parser) when is_binary(token) or is_struct(token) do
    Token.validate(token, did_parser)
  end

  @doc """
  Converts a ucan jwt token string to `Ucan`.

  - token - jwt ucan token string
  """
  @spec from_jwt_token(String.t()) :: {:ok, __MODULE__.t()} | {:error, String.t() | map()}
  def from_jwt_token(token) when is_binary(token) do
    Token.decode(token)
  end

  @doc """
  Returns list of proofs (CID encoded) in a given UCAN
  """
  @spec proofs(__MODULE__.t()) :: list(String.t())
  def proofs(%Ucan{} = ucan) do
    ucan.payload.prf
  end

  @doc """
  Returns the audience DID of the given ucan.
  """
  @spec audience(__MODULE__.t()) :: String.t()
  def audience(%Ucan{} = ucan) do
    ucan.payload.aud
  end

  @doc """
  Returns the issuer DID of given ucan
  """
  @spec issuer(__MODULE__.t()) :: String.t()
  def issuer(%Ucan{} = ucan) do
    ucan.payload.iss
  end

  @doc """
  Returns the `not_before` unix time of given UCAN
  """
  @spec not_before(__MODULE__.t()) :: integer()
  def not_before(%Ucan{payload: %UcanPayload{nbf: nbf}}), do: nbf

  @doc """
  Returns the `expires_at` unix time of given UCAN
  """
  @spec expires_at(__MODULE__.t()) :: integer()
  def expires_at(%Ucan{payload: %UcanPayload{exp: exp}}), do: exp

  @doc """
  Return capabilities of UCAN in map structure using (`Ucan.Capabilities.sequence_to_map()`)
  """
  @spec capabilities(__MODULE__.t()) :: map()
  def capabilities(%Ucan{} = ucan) do
    ucan.payload.cap
  end

  @doc """
  Checks if first ucan survives longer than the second
  """
  @spec lifetime_encompasses?(__MODULE__.t(), __MODULE__.t()) :: boolean()
  def lifetime_encompasses?(%Ucan{} = ucan_a, %Ucan{} = ucan_b) do
    lifetime_begins_before?(ucan_a, ucan_b) and lifetime_ends_after?(ucan_a, ucan_b)
  end

  # Returns true if this UCAN_a lifetime begins no later than the UCAN_b
  # Note that if a UCAN specifies an NBF but the other does not, the
  # other has an unbounded start time and this function will return
  # false.

  @spec lifetime_begins_before?(__MODULE__.t(), __MODULE__.t()) :: boolean()
  defp lifetime_begins_before?(%Ucan{} = ucan_a, %Ucan{} = ucan_b) do
    case {ucan_a.payload.nbf, ucan_b.payload.nbf} do
      {ucan_a_nbf, nil} when not is_nil(ucan_a_nbf) -> false
      {nil, _ucan_b_nbf} -> true
      {ucan_a_nbf, ucan_b_nbf} -> ucan_a_nbf <= ucan_b_nbf
    end
  end

  defp lifetime_ends_after?(%Ucan{} = ucan_a, %Ucan{} = ucan_b) do
    case {ucan_a.payload.exp, ucan_b.payload.exp} do
      {ucan_a_nbf, nil} when not is_nil(ucan_a_nbf) -> false
      {nil, _} -> true
      {ucan_a_nbf, ucan_b_nbf} -> ucan_a_nbf >= ucan_b_nbf
    end
  end
end
