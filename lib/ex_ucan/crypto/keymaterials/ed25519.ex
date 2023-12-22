defmodule Ucan.Keymaterial.Ed25519 do
  @moduledoc """
  Implements `Keymaterial` protocol for Ed25519 Algorithm
  """

  alias Ucan.Keymaterial

  @typedoc """
  A Keypair struct holds the generate keypairs and its metadata

  jwt_alg - JWT algorithm used, ex: edDSA, HMAC etc..
  secret_key - Private key bytes
  public_key - Public key bytes
  """
  @type t :: %__MODULE__{
          jwt_alg: String.t(),
          secret_key: binary(),
          public_key: binary(),
          magic_bytes: binary()
        }

  @derive [Jason.Encoder, {Inspect, only: [:jwt_alg, :public_key, :magic_bytes]}]
  defstruct [:jwt_alg, :secret_key, :public_key, magic_bytes: <<0xED, 0x01>>]

  @doc """
  Creates a keypair with EdDSA algorithm

  This keypair can be later used for create UCAN tokens
  """
  @spec create :: t()
  def create do
    {pub, priv} = :crypto.generate_key(:eddsa, :ed25519)

    %__MODULE__{
      jwt_alg: "EdDSA",
      secret_key: priv,
      public_key: pub,
      # https://github.com/multiformats/multicodec/blob/e9ecf587558964715054a0afcc01f7ace220952c/table.csv#L94 */
      magic_bytes: <<0xED, 0x01>>
    }
  end

  defimpl Keymaterial do
    alias Ucan.DidParser
    alias Ucan.Keymaterial.Ed25519

    def get_jwt_algorithm_name(%Ed25519{} = keymaterial) do
      keymaterial.jwt_alg
    end

    def get_did(%Ed25519{} = keymaterial) do
      DidParser.publickey_to_did(keymaterial.public_key, keymaterial.magic_bytes)
    end

    def sign(%Ed25519{} = keymaterial, payload) do
      :public_key.sign(
        payload,
        :ignored,
        {:ed_pri, :ed25519, keymaterial.public_key, keymaterial.secret_key},
        []
      )
    end

    # We don't use the keymaterial obj's pubkey, we use the passed pub_key.
    def verify(%Ed25519{}, pub_key, payload, signature) do
      :public_key.verify(
        payload,
        :ignored,
        signature,
        {:ed_pub, :ed25519, pub_key}
      )
    end

    def get_magic_bytes(%Ed25519{} = keymaterial) do
      keymaterial.magic_bytes
    end

    def get_pub_key(%Ed25519{} = keymaterial) do
      keymaterial.public_key
    end
  end
end
