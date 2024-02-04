defmodule Ucan.Keymaterial.Rsa do
  @moduledoc """
  Implements `Keymaterial` protocol for RSA Algorithm

  More on RSA for devs
  https://cryptobook.nakov.com/asymmetric-key-ciphers/the-rsa-cryptosystem-concepts

  Records -> erlang records are tuples

  What is ASN1/ASN.1?
  syntax for encoding and decoding RSA (any DS) in a standardized way
  """

  alias Ucan.Keymaterial
  import Ucan.Crypto.Asn1

  @exponent 65_537
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
          magic_bytes: binary(),
          size: non_neg_integer()
        }

  # https://github.com/multiformats/multicodec/blob/e9ecf587558964715054a0afcc01f7ace220952c/table.csv#L146
  @derive [Jason.Encoder, {Inspect, only: [:jwt_alg, :public_key, :magic_bytes]}]
  defstruct [:secret_key, :public_key, jwt_alg: "RS256", magic_bytes: <<0x85, 0x24>>, size: 2048]

  @doc """
  Creates a keypair with RSA algorithm (2048 bits)

  This keypair can be later used for create UCAN tokens
  """
  @spec create(size :: non_neg_integer()) :: t()
  def create(size \\ 2048)

  def create(size) do
    private_key = :public_key.generate_key({:rsa, size, @exponent})
    rsa_private_key(modulus: mod, publicExponent: e) = private_key
    public_key = rsa_public_key(modulus: mod, publicExponent: e)

    %__MODULE__{}
    |> Map.put(:secret_key, private_key)
    |> Map.put(:public_key, public_key)
  end

  defimpl Keymaterial do
    alias Ucan.DidParser
    alias Ucan.Keymaterial.Rsa

    def get_jwt_algorithm_name(%Rsa{} = keymaterial) do
      keymaterial.jwt_alg
    end

    # prolly need to conver to binary format before calcing did
    def get_did(%Rsa{public_key: pub} = keymaterial) do
      :public_key.der_encode(:RSAPublicKey, pub)
      |> DidParser.publickey_to_did(keymaterial.magic_bytes)
    end

    def sign(%Rsa{} = keymaterial, payload) do
      :public_key.sign(
        payload,
        :sha256,
        keymaterial.secret_key
      )
    end

    # We don't use the keymaterial obj's pubkey, we use the passed pub_key.
    def verify(%Rsa{}, pub_key, payload, signature) do
      :public_key.verify(
        payload,
        :sha256,
        signature,
        pub_key
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
