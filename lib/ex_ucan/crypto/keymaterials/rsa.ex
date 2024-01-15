defmodule Ucan.Keymaterial.Rsa do
  @moduledoc """
  Implements `Keymaterial` protocol for RSA Algorithm
  """

  alias Ucan.Keymaterial

  @typedoc """
  A Keypair struct holds the generate keypairs and its metadata

  jwt_alg - JWT algorithm used, ex: RSA, HMAC etc..
  secret_key - Private key bytes
  public_key - Public key bytes
  """
  @type t :: %__MODULE__{
          jwt_alg: String.t(),
          secret_key: binary(),
          public_key: binary(),
          magic_bytes: binary()
        }

  # https://github.com/multiformats/multicodec/blob/e9ecf587558964715054a0afcc01f7ace220952c/table.csv#L146
  @derive [Jason.Encoder, {Inspect, only: [:jwt_alg, :public_key, :magic_bytes]}]
  defstruct [:secret_key, :public_key, jwt_alg: "RS256", magic_bytes: <<0x85, 0x24>>]

  @doc """
  Creates a keypair with RSA algorithm (2048 bits)

  This keypair can be later used for create UCAN tokens
  """
  @spec create :: t()
  def create do
    # {pub, priv} = :crypto.generate_key(:rsa, {4096, 65537})

    {:RSAPrivateKey, _, modulus, publicExponent, _, _, _, _exponent1, _, _, _otherPrimeInfos} =
      rsa_private_key = :public_key.generate_key({:rsa, 2048, 65537})

    rsa_public_key = {:RSAPublicKey, modulus, publicExponent}

    private_key =
      [:public_key.pem_entry_encode(:RSAPrivateKey, rsa_private_key)]
      |> :public_key.pem_encode()

    public_key =
      [:public_key.pem_entry_encode(:RSAPublicKey, rsa_public_key)]
      |> :public_key.pem_encode()

    {private_key, public_key}

    %__MODULE__{}
    |> Map.put(:secret_key, private_key)
    |> Map.put(:public_key,  public_key)
  end

  defimpl Keymaterial do
    alias Ucan.DidParser
    alias Ucan.Keymaterial.Rsa

    def get_jwt_algorithm_name(%Rsa{} = keymaterial) do
      keymaterial.jwt_alg
    end

    def get_did(%Rsa{} = keymaterial) do
      DidParser.publickey_to_did(keymaterial.public_key, keymaterial.magic_bytes)
    end

    def sign(%Rsa{} = keymaterial, payload) do
      :public_key.sign(
        payload,
        :ignored,
        {:ed_pri, :Rsa, keymaterial.public_key, keymaterial.secret_key},
        []
      )
    end

    # We don't use the keymaterial obj's pubkey, we use the passed pub_key.
    def verify(%Rsa{}, pub_key, payload, signature) do
      :public_key.verify(
        payload,
        :ignored,
        signature,
        {:ed_pub, :Rsa, pub_key}
      )
    end

    def get_magic_bytes(%Rsa{} = keymaterial) do
      keymaterial.magic_bytes
    end

    def get_pub_key(%Rsa{} = keymaterial) do
      keymaterial.public_key
    end
  end
end
