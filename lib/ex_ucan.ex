defmodule Ucan do
  @moduledoc """
  Documentation for `Ucan`.
  """
  alias Ucan.Core.Structs.UcanRaw
  alias Ucan.Core.Token
  alias Ucan.Keymaterial.Ed25519.Keypair

  @doc """
  Creates a default keypair with EdDSA algorithm

  This keypair can be later used for create UCAN tokens
  Keypair generated with different algorithms like RSA will be coming soon..
  """
  @spec create_default_keypair :: Keypair.t()
  def create_default_keypair do
    Keypair.create()
  end

  @doc """
   Signs the payload with keypair and returns a UCAN struct

  - payload - Ucan payload type
  - keypair - A Keymaterial implemented struct
  """
  @spec sign(payload :: UcanPayload.t(), keypair :: struct()) :: UcanRaw.t()
  def sign(payload, keypair) do
    Token.sign_with_payload(payload, keypair)
  end

  @doc """
  Encode the Ucan.t() struct to JWT like token
  """
  @spec encode(UcanRaw.t()) :: String.t()
  def encode(ucan) do
    Token.encode(ucan)
  end

  @doc """
  Validate the UCAN token's signature and timestamps

  - encoded_token - Ucan token
  """
  @spec validate_token(String.t()) :: :ok | {:error, String.t()}
  def validate_token(encoded_token) do
    Token.validate(encoded_token)
  end
end
