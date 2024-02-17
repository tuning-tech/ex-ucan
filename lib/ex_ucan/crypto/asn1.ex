defmodule Ucan.Crypto.Asn1 do
  @moduledoc """
  Abstract Syntax Notation One.

  For Describing adta structures cross-platform in a standard way
  for serializing and deserializing.

  In case of RSA and ECDSA we use x509 standard
  x509 defines the format of public key cetificates
  """
  require Record
  alias X509.ASN1.OIDImport

  # records to import from :public_key's hrl files
  @records [
    # RSA keys
    rsa_private_key: :RSAPrivateKey,
    rsa_public_key: :RSAPublicKey,
    ec_private_key: :ECPrivateKey,
    ec_point: :ECPoint
  ]

  Enum.each(@records, fn
    {name, :ECPoint} ->
      Record.defrecord(
        name,
        :ECPoint,
        Record.extract(:ECPoint, from_lib: "public_key/include/public_key.hrl")
      )

    {name, record} ->
      Record.defrecord(
        name,
        record,
        try do
          Record.extract(record, from_lib: "public_key/include/OTP-PUB-KEY.hrl")
        rescue
          ArgumentError ->
            Record.extract(record, from_lib: "public_key/include/PKCS-FRAME.hrl")
        end
      )
  end)
end
