defmodule Ucan.Crypto do
  @moduledoc """
  Crypto Utilities
  """

  @typedoc """
  {magic bytes, Keymaterial}
  """
  @type key_constructor :: {binary(), Ucan.Keymaterial.t()}

  # https://github.com/multiformats/multicodec/blob/e9ecf587558964715054a0afcc01f7ace220952c/table.csv#L94 */
  @edwards_did_prefix <<0xED, 0x01>>

  # z is the multibase prefix for base58btc byte encoding
  @base58_did_prefix "did:key:z"

  @doc """
  Generate DID from publickey bytes

  - publickey_bytes - Public key
  - prefix - byte prefix for the algorithm using for signing, (<<0xed, 0x01>> for EdDSA)
  """
  @spec did_to_publickey(did :: String.t()) :: {:ok, binary()} | {:error, String.t()}
  def did_to_publickey("did:key:z" <> non_prefix_did) do
    bytes = Base58.decode(non_prefix_did)
    <<a::size(8), b::size(8), pub::binary>> = bytes

    if <<a, b>> == @edwards_did_prefix do
      {:ok, pub}
    else
      {:error, "Expected prefix #{inspect(@edwards_did_prefix)}"}
    end
  end

  def did_to_publickey(_did),
    do: {:error, "Please use a base58-encoded DID formatted `did:key:z..."}

  @doc """
  Generate DID from publickey bytes

  - publickey_bytes - Public key
  - prefix - byte prefix for the algorithm using for signing, (<<0xed, 0x01>> for EdDSA)
  """
  @spec publickey_to_did(pubkey :: binary()) :: String.t()
  def publickey_to_did(pubkey) do
    bytes = <<@edwards_did_prefix::binary, pubkey::binary>>
    base58key = Base58.encode(bytes)
    @base58_did_prefix <> base58key
  end

  @spec get_key_constructors :: list(key_constructor())
  def get_key_constructors do
    [
      {@edwards_did_prefix, %{}}
    ]
  end
end
