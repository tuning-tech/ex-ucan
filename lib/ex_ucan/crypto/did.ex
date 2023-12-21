defmodule Ucan.DidParser do
  @moduledoc """
  A parser that can convert from a DID string to corresponding `Ucan.Keymaterial`
  """

  @typedoc """
  {magic bytes, Keymaterial}
  """
  @type key_constructor :: {binary(), Ucan.Keymaterial.t()}

  # https://github.com/multiformats/multicodec/blob/e9ecf587558964715054a0afcc01f7ace220952c/table.csv#L94 */
  @edwards_did_prefix <<0xED, 0x01>>

  # z is the multibase prefix for base58btc byte encoding
  # @base58_did_prefix "did:key:z"

  alias Ucan.Crypto

  @type t :: %__MODULE__{
          # Map<String.t()><String.t()>
          key_constructors: map(),
          # Map<String.t()><Ucan.Keymaterial.t()>
          key_cache: map()
        }

  defstruct key_constructors: %{}, key_cache: %{}

  # TODO: docs
  @spec new(list(Crypto.key_constructor())) :: __MODULE__.t()
  def new(key_constructors) do
    Enum.reduce(key_constructors, %{}, fn {magic_bytes, keymaterial}, acc ->
      Map.put(acc, magic_bytes, keymaterial)
    end)
    |> then(
      &%__MODULE__{
        key_constructors: &1,
        key_cache: %{}
      }
    )
  end

  # TODO: docs
  @spec parse(__MODULE__.t(), String.t()) ::
          {:ok, Ucan.Keymaterial.t(), __MODULE__.t()} | {:error, String.t()}
  def parse(%__MODULE__{} = parser, "did:key:z" <> did) do
    if Map.has_key?(parser, did) do
      {:ok, parser[did], parser}
    end

    <<a::size(8), b::size(8), pub_key::binary>> = _did_bytes = Base58.decode(did)
    magic_bytes = <<a, b>>

    case Map.get(parser.key_constructors, magic_bytes) do
      nil ->
        {:error, "Unrecognized magic bytes: #{magic_bytes}"}

      constructor ->
        keymaterial = Ucan.Keymaterial.create(constructor, pub_key)
        parser = Map.put(parser, magic_bytes, keymaterial)
        {:ok, keymaterial, parser}
    end
  end

  def parse(_, did), do: {:error, "Expected valid did:key, got: #{did}"}

  @spec get_default_constructors :: list(key_constructor())
  def get_default_constructors do
    [
      {@edwards_did_prefix, %{}}
    ]
  end
end
