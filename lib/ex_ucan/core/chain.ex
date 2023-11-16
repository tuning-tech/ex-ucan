defmodule Ucan.ProofChains do
  alias Ucan.Core.Structs.UcanRaw
  @type t :: %__MODULE__{
    ucan: UcanRaw.t(),
    proofs: list(__MODULE__.t()),
    redelegations: map()
  }
  defstruct [:ucan, :proofs, :redelegations]

end

defmodule Ucan.Chain do
  @moduledoc false
  # TODO: module docs

end
