defprotocol Ucan.Keymaterial do
  @moduledoc """
  Keymaterial protocol used by Keypair generation modules like `Ucan.Keymaterial.Ed25519.Keypair`

  This protocol requires four functions to be implemented, `get_jwt_algorithm_name/1`,
  `get_did/1`, `sign/2` and `verify/3`
  """

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
