defprotocol Ucan.Keymaterial do
  @moduledoc """
  This protocol must be implemented by a struct that encapsulates cryptographic
  keypair data. The protocol represent the minimum required API capability for
  producing a signed UCAN from a cryptographic keypair, and verifying such
  signatures.

  This protocol requires four functions to be implemented, `get_jwt_algorithm_name/1`,
  `get_did/1`, `sign/2` and `verify/3`
  """

  @spec create(t(), binary()) :: t()
  def create(type, pub_key)

  @doc """
  Returns the Jwt algorithm used by the Keypair to create Ucan
  """
  @spec get_jwt_algorithm_name(any()) :: String.t()
  def get_jwt_algorithm_name(type)

  @doc """
  Retursn the did (Decentralized Identifiers) generated using the keypair
  """
  @spec get_did(any()) :: String.t()
  def get_did(type)

  @doc """
  Creates signature on the given payload with the keypair
  """
  @spec sign(any(), binary()) :: binary()
  def sign(type, payload)

  @doc """
  Verifies the signature with the keypair
  """
  @spec verify(any(), binary(), binary()) :: boolean()
  def verify(type, payload, signature)
end
