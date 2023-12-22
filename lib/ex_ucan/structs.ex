defmodule Ucan.UcanHeader do
  @moduledoc """
  Ucan header representation
  """

  @typedoc """
  alg - Algorithm used (ex EdDSA)
  typ - Type of token format (ex JWT)
  """
  @type t :: %__MODULE__{
          alg: String.t(),
          typ: String.t()
        }

  @derive Jason.Encoder
  defstruct [:alg, :typ]
end

defmodule Ucan.UcanPayload do
  @moduledoc """
  Ucan Payload representation
  """
  alias Ucan.Capabilities

  @typedoc """

  ucv: UCAN version.
  iss: Issuer, the DID of who sent this.
  aud: Audience, the DID of who it's intended for.
  nbf: Not Before, unix timestamp of when the jwt becomes valid.
  exp: Expiry, unix timestamp of when the jwt is no longer valid.
  nnc: Nonce value to increase the uniqueness of UCAN token.
  fct: Facts, an array of extra facts or information to attach to the jwt.
  cap: A list of resources and capabilities that the ucan grants.
  prf: Proof, an optional nested token with equal or greater privileges.

  """
  @type t :: %__MODULE__{
          ucv: String.t(),
          iss: String.t(),
          aud: String.t(),
          nbf: integer(),
          exp: integer(),
          nnc: String.t(),
          fct: map(),
          cap: Capabilities.t(),
          prf: list(String.t())
        }

  @derive Jason.Encoder
  defstruct [:ucv, :iss, :aud, :nbf, :exp, :nnc, :fct, :cap, :prf]
end
