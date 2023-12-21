defmodule Ucan.Token do
  @moduledoc """
  Core functions for the creation and management of UCAN tokens
  """
  alias Ucan.Builder
  alias Ucan.Capabilities
  alias Ucan.UcanHeader
  alias Ucan.UcanPayload
  alias Ucan.Utils
  alias Ucan.Keymaterial
  alias Ucan.Keymaterial.Ed25519.Crypto
  alias Ucan.Keymaterial.Ed25519.Keypair

  @token_type "JWT"
  @version %{major: 0, minor: 10, patch: 0}

  @doc """
  Takes a UcanBuilder and generates a UCAN payload

  Returns an error tuple with reason, if failed to generate payload
  """
  @spec build_payload(params :: Builder.t()) :: {:ok, UcanPayload.t()} | {:error, String.t()}
  def build_payload(%Builder{issuer: nil}), do: {:error, "must call issued_by/2"}
  def build_payload(%Builder{audience: nil}), do: {:error, "must call for_audience/2"}

  def build_payload(%Builder{lifetime: life, expiration: exp}) when life == nil and exp == nil,
    do: {:error, "must call with_lifetime/2 or with_expiration/2"}

  def build_payload(params) do
    did = Keymaterial.get_did(params.issuer)

    with {:iss, true} <- {:iss, String.starts_with?(did, "did")},
         {:aud, true} <- {:aud, String.starts_with?(params.audience, "did")},
         {:ok, caps} <- Capabilities.sequence_to_map(params.capabilities) do
      current_time_in_seconds = DateTime.utc_now() |> DateTime.to_unix()
      exp = params.expiration || current_time_in_seconds + params.lifetime

      {:ok,
       %UcanPayload{
         ucv: "#{@version.major}.#{@version.minor}.#{@version.patch}",
         iss: did,
         aud: params.audience,
         nbf: params.not_before,
         exp: exp,
         nnc: add_nonce(params.add_nonce? || false),
         fct: params.facts,
         cap: caps,
         prf: params.proofs
       }}
    else
      {:iss, false} -> {:error, "The issuer must be a DID"}
      {:aud, false} -> {:error, "The audience must be a DID"}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec encode(Ucan.t()) :: String.t()
  def encode(%Ucan{} = ucan) do
    "#{ucan.signed_data}.#{ucan.signature}"
  end

  @spec decode(String.t()) :: {:ok, Ucan.t()} | {:error, String.t() | map()}
  def decode(encoded_token) do
    with {:ok, {header, payload}} <- parse_encoded_ucan(encoded_token) do
      [enc_header, enc_payload, enc_signature] = String.split(encoded_token, ".")

      {:ok,
       %Ucan{
         header: header,
         payload: payload,
         signed_data: "#{enc_header}.#{enc_payload}",
         signature: enc_signature
       }}
    end
  end

  @doc """
  Validate the UCAN token's signature and timestamps

  - encoded_token - Ucan token
  """
  @spec validate(String.t() | Ucan.t()) :: :ok | {:error, String.t() | map()}
  def validate(ucan) when is_binary(ucan) do
    with {:ok, {_header, payload}} <- parse_encoded_ucan(ucan),
         {false, _} <- {is_expired?(payload), :expired},
         {false, _} <- {is_too_early?(payload), :early} do
      [encoded_header, encoded_payload, encoded_sign] = String.split(ucan, ".")
      {:ok, signature} = Base.url_decode64(encoded_sign, padding: false)
      data = "#{encoded_header}.#{encoded_payload}"
      verify_signature(payload.iss, data, signature)
    else
      {true, :expired} -> {:error, "Ucan token is already expired"}
      {true, :early} -> {:error, "Ucan token is not yet active"}
      err -> err
    end
  end

  def validate(%Ucan{} = ucan) do
    with {false, _} <- {is_expired?(ucan.payload), :expired},
         {false, _} <- {is_too_early?(ucan.payload), :early} do
      {:ok, signature} = Base.url_decode64(ucan.signature, padding: false)
      verify_signature(ucan.payload.iss, ucan.signed_data, signature)
    else
      {true, :expired} -> {:error, "Ucan is already expired"}
      {true, :early} -> {:error, "Ucan is not yet active"}
      err -> err
    end
  end

  @doc """
  Signs the payload with keypair and returns a UCAN struct

  - payload - Ucan payload type
  - keypair - A Keymaterial implemented struct
  """
  @spec sign_with_payload(payload :: UcanPayload.t(), keypair :: Keypair.t()) :: Ucan.t()
  def sign_with_payload(payload, keypair) do
    header = %UcanHeader{alg: keypair.jwt_alg, typ: @token_type}
    encoded_header = encode_ucan_parts(header)
    encoded_payload = encode_ucan_parts(payload)

    signed_data = "#{encoded_header}.#{encoded_payload}"
    signature = Keymaterial.sign(keypair, signed_data)

    %Ucan{
      header: header,
      payload: payload,
      signed_data: signed_data,
      signature: Base.url_encode64(signature, padding: false)
    }
  end

  @doc """
  Converts a give Raw UCAN/encoded Ucan string to Cid, hashed by the given hash
  """
  @spec to_cid(Ucan.t() | String.t(), Builder.hash_type()) ::
          {:ok, String.t()} | {:error, Stirng.t()}
  def to_cid(ucan, hash_type \\ :blake3)

  def to_cid(ucan, hash_type) do
    Cid.cid(ucan, hash_type)
  end

  @doc """
  Converts a give Raw UCAN/encoded Ucan string to Cid, hashed by the given hash

  A runtime exception is raised if build payloads fails.
  """
  @spec to_cid!(Ucan.t() | String.t(), Builder.hash_type()) :: String.t()
  def to_cid!(ucan, hash_type) do
    case Cid.cid(ucan, hash_type) do
      {:ok, cid} -> cid
      {:error, err} -> raise err
    end
  end

  @spec encode_ucan_parts(UcanHeader.t() | UcanPayload.t()) :: String.t()
  defp encode_ucan_parts(data) do
    data
    |> Jason.encode!()
    |> Base.url_encode64(padding: false)
  end

  @spec is_expired?(UcanPayload.t()) :: boolean()
  defp is_expired?(%UcanPayload{} = ucan_payload) do
    ucan_payload.exp < DateTime.utc_now() |> DateTime.to_unix()
  end

  @spec is_too_early?(UcanPayload.t()) :: boolean()
  defp is_too_early?(%UcanPayload{nbf: nil}), do: false

  defp is_too_early?(%UcanPayload{nbf: nbf}) do
    nbf > DateTime.utc_now() |> DateTime.to_unix()
  end

  @spec parse_encoded_ucan(String.t()) ::
          {:ok, {UcanHeader.t(), UcanPayload.t()}} | {:error, String.t() | map()}
  def parse_encoded_ucan(encoded_ucan) do
    opts = [padding: false]

    with {:ok, {header, payload, _sign}} <- tear_into_parts(encoded_ucan),
         {:ok, decoded_header} <- Base.url_decode64(header, opts),
         {:ok, header} <- Jason.decode(decoded_header, keys: :atoms),
         {:ok, decoded_payload} <- Base.url_decode64(payload, opts),
         {:ok, payload} <- Jason.decode(decoded_payload, keys: :atoms) do
      {:ok, {struct(UcanHeader, header), to_ucanpayload(payload)}}
    end
  end

  @spec tear_into_parts(String.t()) ::
          {:ok, {String.t(), String.t(), String.t()}} | {:error, String.t()}
  defp tear_into_parts(encoded_ucan) do
    err_msg =
      "Can't parse UCAN: #{encoded_ucan}: Expected JWT format: 3 dot-separated base64url-encoded values."

    case String.split(encoded_ucan, ".") |> List.to_tuple() do
      {"", _, _} -> {:error, err_msg}
      {_, "", _} -> {:error, err_msg}
      {_, _, ""} -> {:error, err_msg}
      ucan_parts -> {:ok, ucan_parts}
    end
  end

  @spec verify_signature(String.t(), String.t(), String.t()) :: :ok | {:error, String.t()}
  defp verify_signature(did, data, signature) do
    with {:ok, public_key} <- Crypto.did_to_publickey(did),
         true <- :public_key.verify(data, :ignored, signature, {:ed_pub, :ed25519, public_key}) do
      :ok
    else
      false -> {:error, "Failed to verify signature, check the params and try again"}
      err -> err
    end
  end

  defp add_nonce(true), do: Utils.generate_nonce()
  defp add_nonce(false), do: nil

  @spec to_ucanpayload(map()) :: UcanPayload.t()
  defp to_ucanpayload(payload) do
    %UcanPayload{
      ucv: payload.ucv,
      iss: payload.iss,
      aud: payload.aud,
      nbf: payload.nbf,
      exp: payload.exp,
      nnc: payload.nnc,
      fct: payload.fct,
      # Since we decode the entire payload using Jason.decode!(keys: atoms)
      # even the capability maps will be converted, which we don't want.
      # So we do a encoding decoding to convert caps to keys as strings
      cap: Jason.encode!(payload.cap) |> Jason.decode!(),
      prf: payload.prf
    }
  end
end
