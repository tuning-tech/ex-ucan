defmodule Ucan.Core.Structs.UcanHeader do
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

defmodule Ucan.Core.Structs.UcanPayload do
  @moduledoc """
  Ucan Payload representation
  """
  alias Ucan.Core.Capability

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
          cap: list(Capability.t()),
          prf: list(String.t())
        }

  @derive Jason.Encoder
  defstruct [:ucv, :iss, :aud, :nbf, :exp, :nnc, :fct, :cap, :prf]
end

defmodule Ucan.Core.Structs.UcanRaw do
  @moduledoc """
  UCAN struct
  """
  alias Ucan.Core.Structs.UcanHeader
  alias Ucan.Core.Structs.UcanPayload

  @typedoc """
  header - Token Header
  payload - Token payload
  signed_data - Data that would be eventually signed
  signature - Base64Url encoded signature
  """
  @type t :: %__MODULE__{
          header: UcanHeader.t(),
          payload: UcanPayload.t(),
          signed_data: String.t(),
          signature: String.t()
        }

  defstruct [:header, :payload, :signed_data, :signature]
end
