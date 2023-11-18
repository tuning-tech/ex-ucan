defmodule Ucan.ProofSelection.Index do
  @type t :: %__MODULE__{
          value: integer()
        }

  defstruct [:value]
end

defmodule Ucan.ProofSelection do
  @type t :: %__MODULE__{
          type: Ucan.ProofSelection.Index.t() | :all
        }

  defstruct [:type]

  defimpl Ucan.Capability.Scope do
    def contains?(scope, other_scope) do
      scope.type == other_scope.type or scope.type == :all
    end
  end
end

defmodule Ucan.ProofAction do
  def delegate(), do: :delegate
end

defmodule Ucan.ProofDelegationSemantics do
  # implement Capability.Semantics protocol
end
