defprotocol Ucan.Keymaterial do
  @moduledoc """
  This protocol must be implemented by a struct that encapsulates cryptographic
  keypair data. The protocol represent the minimum required API capability for
  producing a signed UCAN from a cryptographic keypair, and verifying such
  signatures.

  This protocol requires four functions to be implemented, `get_jwt_algorithm_name/1`,
  `get_did/1`, `sign/2` and `verify/3`
  """

  @doc """
  Returns the Jwt algorithm used by the Keypair to create Ucan
  """
  @spec get_jwt_algorithm_name(t()) :: String.t()
  def get_jwt_algorithm_name(keymaterial)

  @doc """
  Retursn the did (Decentralized Identifiers) generated using the keypair
  """
  @spec get_did(t()) :: String.t()
  def get_did(keymaterial)

  @doc """
  Creates signature on the given payload with the keypair
  """
  @spec sign(t(), binary()) :: binary()
  def sign(keymaterial, payload)

  @doc """
  Verifies the signature with the keymaterial and pub_key
  """
  @spec verify(t(), binary(), binary(), binary()) :: boolean()
  def verify(keymaterial, pub_key, payload, signature)

  @doc """
  Returns the magic_bytes used for the algorithm
  """
  @spec get_magic_bytes(t()) :: binary()
  def get_magic_bytes(keymaterial)

  @doc """
  Returns the public key from the keypair
  """
  @spec get_pub_key(t()) :: binary()
  def get_pub_key(keymaterial)
end
