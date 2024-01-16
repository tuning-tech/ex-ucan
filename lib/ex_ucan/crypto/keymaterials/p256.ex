defmodule Ucan.Keymaterial.P256 do
  @moduledoc """
  Implements `Keymaterial` protocol for P256 Algorithm
  """

  alias Ucan.Keymaterial

  @typedoc """
  A Keypair struct holds the generate keypairs and its metadata

  jwt_alg - JWT algorithm used, ex: ecDSA, RS256 etc..
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
  defstruct [:secret_key, :public_key, jwt_alg: "ES256", magic_bytes: <<0x80, 0x24>>]

  @doc """
  Creates a keypair with P-256 algorithm

  This keypair can be later used for create UCAN tokens

  https://atproto.com/specs/cryptography#public-key-encoding
  P-256 aka `NIST P-256`/`secp256r1`, supported in webcryptoAPI.

  SO thers seems to be conversion of multicodec prefixes into varint values
  presumably for efficient storage. For ex multicodec prefix of P-256 is
  0x1200, [ref](https://w3c-ccg.github.io/did-method-key/#signature-method-creation-algorithm)
  But for varint encoding we use <<0x80, 0x24>>
  """
  @spec create :: t()
  def create do
    {pub, priv} = :crypto.generate_key(:eddsa, :ed25519)
    %__MODULE__{}
    |> Map.put(:public_key, pub)
    |> Map.put(:secret_key, priv)
  end

  defimpl Keymaterial do
    alias Ucan.DidParser
    alias Ucan.Keymaterial.P256

    def get_jwt_algorithm_name(%P256{} = keymaterial) do
      keymaterial.jwt_alg
    end

    def get_did(%P256{} = keymaterial) do
      DidParser.publickey_to_did(keymaterial.public_key, keymaterial.magic_bytes)
    end

    def sign(%P256{} = keymaterial, payload) do
      :public_key.sign(
        payload,
        :ignored,
        {:ed_pri, :ed25519, keymaterial.public_key, keymaterial.secret_key},
        []
      )
    end

    # We don't use the keymaterial obj's pubkey, we use the passed pub_key.
    def verify(%P256{}, pub_key, payload, signature) do
      :public_key.verify(
        payload,
        :ignored,
        signature,
        {:ed_pub, :ed25519, pub_key}
      )
    end

    def get_magic_bytes(%P256{} = keymaterial) do
      keymaterial.magic_bytes
    end

    def get_pub_key(%P256{} = keymaterial) do
      keymaterial.public_key
    end
  end
end
