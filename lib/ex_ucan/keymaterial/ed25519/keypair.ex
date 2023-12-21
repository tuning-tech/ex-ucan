defmodule Ucan.Keymaterial.Ed25519.Keypair do
  @moduledoc """
  Encapsulates Ed25519 Keypair generation and implements `Keymaterial` protocol
  """

  alias Ucan.Keymaterial
  alias Ucan.Keymaterial.Ed25519.Crypto

  @typedoc """
  A Keypair struct holds the generate keypairs and its metadata

  jwt_alg - JWT algorith used, ex: edDSA, HMAC etc..
  secret_key - Private key bytes
  public_key - Public key bytes
  """
  @type t :: %__MODULE__{
          jwt_alg: String.t(),
          secret_key: binary(),
          public_key: binary()
        }

  @derive [Jason.Encoder, {Inspect, only: [:jwt_alg, :public_key]}]
  defstruct [:jwt_alg, :secret_key, :public_key]

  @doc """
  Creates a keypair with EdDSA algorithm

  This keypair can be later used for create UCAN tokens
  """
  @spec create :: __MODULE__.t()
  def create do
    {pub, priv} = :crypto.generate_key(:eddsa, :ed25519)

    %__MODULE__{
      jwt_alg: "EdDSA",
      secret_key: priv,
      public_key: pub
    }
  end

  defimpl Keymaterial do

    def create(_type, _pub_key) do
      :ok
    end

    def get_jwt_algorithm_name(keypair) do
      keypair.jwt_alg
    end

    def get_did(keypair) do
      Crypto.publickey_to_did(keypair.public_key)
    end

    def sign(keypair, payload) do
      :public_key.sign(
        payload,
        :ignored,
        {:ed_pri, :ed25519, keypair.public_key, keypair.secret_key},
        []
      )
    end

    def verify(keypair, payload, signature) do
      :public_key.verify(payload, :ignored, signature, {:ed_pub, :ed25519, keypair.public_key})
    end
  end
end
