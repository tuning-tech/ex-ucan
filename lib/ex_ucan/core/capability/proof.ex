defmodule Ucan.ProofSelection do
  defmodule Index do
    @type t :: %__MODULE__{
            value: integer()
          }

    defstruct [:value]
  end

  @type t :: %__MODULE__{
          type: Ucan.ProofSelection.Index.t() | :all
        }

  defstruct [:type]

  defimpl Ucan.Capability.Scope do
    def contains?(scope, other_scope) do
      scope.type == other_scope.type or scope.type == :all
    end

    @spec from(Scope, URI.t() | String.t()) :: {:ok, Scope} | {:error, String.t()}
    def from(_scope, %URI{} = value) do
      case value.scheme do
        "prf" ->
          index = String.to_integer(value.path)
          %Ucan.ProofSelection{type: %Index{value: index}}

        _ ->
          {:error, "Unrecognized URI scheme"}
      end
    end

    def from(_scope, value) when is_binary(value) do
      case value do
        "*" -> {:ok, %Ucan.ProofSelection{type: :all}}
        value -> {:ok, %Ucan.ProofSelection{type: %Index{value: String.to_integer(value)}}}
      end
    end
  end


end

defmodule Ucan.ProofAction do
  @type t :: %__MODULE__{type: :delegate}
  defstruct type: :delegate
end

defmodule Ucan.ProofDelegationSemantics do
  # implement Capability.Semantics protocol
  @type t :: %__MODULE__{
          scope: Ucan.ProofSelection.t(),
          action: Ucan.ProofAction.t()
        }
  defstruct [:scope, :action]

  # TODO: doc
  @spec new() :: __MODULE__.t()
  def new() do
    %__MODULE__{
      scope: %Ucan.ProofSelection{type: :all},
      action: %Ucan.ProofAction{}
    }
  end
end
