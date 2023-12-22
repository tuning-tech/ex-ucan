defmodule Ucan.DidParser do
  @moduledoc """
  DID Utilities
  """
  alias Ucan.Keymaterial
  alias Ucan.Keymaterial.Ed25519

  # z is the multibase prefix for base58btc byte encoding
  @base58_did_prefix "did:key:z"

  @type key_constructor :: {binary(), Keymaterial.t()}
  @type t :: %__MODULE__{
          # Map<String.t()><String.t()>
          key_constructors: map()
        }

  defstruct key_constructors: %{}

  @doc """
  Creates a DidParser by caching the given list of keyMaterials.
  """
  @spec new(list(key_constructor())) :: __MODULE__.t()
  def new(key_constructors) do
    Enum.reduce(key_constructors, %{}, fn {magic_bytes, keymaterial}, acc ->
      Map.put(acc, magic_bytes, keymaterial)
    end)
    |> then(
      &%__MODULE__{
        # Caches magic_bytes/prefix -> Keymaterial
        key_constructors: &1
      }
    )
  end

  @doc """
  Returns the public key and corresponding `Keymaterial` for given DID
  """
  @spec parse(__MODULE__.t(), String.t()) ::
          {:ok, pub_key :: binary(), Ucan.Keymaterial.t()} | {:error, String.t()}
  def parse(%__MODULE__{} = parser, "did:key:z" <> did) do
    <<a::size(8), b::size(8), pub_key::binary>> = _did_bytes = Base58.decode(did)
    magic_bytes = <<a, b>>

    case Map.get(parser.key_constructors, magic_bytes) do
      nil ->
        {:error, "Unrecognized magic bytes: #{magic_bytes}"}

      keymaterial ->
        {:ok, pub_key, keymaterial}
    end
  end

  def parse(_, did), do: {:error, "Expected valid did:key, got: #{did}"}

  @doc """
  Generate DID from publickey bytes

  - publickey_bytes - Public key
  - magic_bytes - byte prefix for the algorithm using for signing, (<<0xed, 0x01>> for EdDSA)
  """
  @spec did_to_publickey(did :: String.t(), magic_bytes :: binary()) ::
          {:ok, binary()} | {:error, String.t()}
  def did_to_publickey("did:key:z" <> non_prefix_did, magic_bytes) do
    bytes = Base58.decode(non_prefix_did)
    <<a::size(8), b::size(8), pub::binary>> = bytes

    if <<a, b>> == magic_bytes do
      {:ok, pub}
    else
      {:error, "Expected prefix #{inspect(magic_bytes)}"}
    end
  end

  def did_to_publickey(_did, _),
    do: {:error, "Please use a base58-encoded DID formatted `did:key:z..."}

  @doc """
  Generate DID from publickey bytes

  - publickey_bytes - Public key
  - magic_bytes - byte prefix for the algorithm using for signing, (<<0xed, 0x01>> for EdDSA)
  """
  @spec publickey_to_did(pubkey :: binary(), magic_bytes :: binary()) :: String.t()
  def publickey_to_did(pubkey, magic_bytes) do
    bytes = <<magic_bytes::binary, pubkey::binary>>
    base58key = Base58.encode(bytes)
    @base58_did_prefix <> base58key
  end

  @spec get_default_constructors :: list(key_constructor())
  def get_default_constructors do
    [
      {Keymaterial.get_magic_bytes(%Ed25519{}), %Ed25519{}}
    ]
  end
end
