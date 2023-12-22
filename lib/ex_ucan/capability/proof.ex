defmodule Ucan.ProofSelection do
  @moduledoc false
  defmodule Index do
    @moduledoc false
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
  end

  defimpl Ucan.Utility.Convert do
    @spec from(Scope, URI.t() | String.t()) :: {:ok, Scope} | {:error, String.t()}
    def from(_scope, %URI{} = value) do
      case value.scheme do
        "prf" ->
          index = String.to_integer(value.path)
          {:ok, %Ucan.ProofSelection{type: %Index{value: index}}}

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

  defimpl String.Chars do
    alias Ucan.ProofSelection

    def to_string(proof_selection) do
      case proof_selection do
        %ProofSelection{type: nil} -> "prf:*"
        %ProofSelection{type: %Index{value: value}} -> "prf:#{Kernel.to_string(value)}"
      end
    end
  end
end

defmodule Ucan.ProofAction do
  @moduledoc false
  @type t :: %__MODULE__{type: :delegate}
  defstruct type: :delegate

  defimpl Ucan.Utility.Convert do
    alias Ucan.ProofAction

    def from(_ability, value) do
      case value do
        "ucan/DELEGATE" -> {:ok, %ProofAction{}}
        _ -> {:error, "Unsupported action for proof resource #{value}"}
      end
    end
  end

  defimpl String.Chars do
    def to_string(proof_action) do
      case proof_action.type do
        :delegate -> "ucan/DELEGATE"
        _ -> ""
      end
    end
  end

  defimpl Ucan.Utility.PartialOrder do
    alias Ucan.ProofAction

    @proof_action_order %{
      delegate: 0
    }
    def compare(%ProofAction{} = ability, %ProofAction{} = other_ability) do
      case {@proof_action_order[ability.type], @proof_action_order[other_ability.type]} do
        {order_a, order_a} -> :eq
        {order_a, order_b} when order_a > order_b -> :gt
        _ -> :lt
      end
    end
  end
end

defmodule Ucan.ProofDelegationSemantics do
  @moduledoc false
  alias Ucan.ProofAction
  alias Ucan.ProofSelection

  @type t :: %__MODULE__{
          scope: Ucan.ProofSelection.t(),
          ability: Ucan.ProofAction.t()
        }
  defstruct scope: %ProofSelection{}, ability: %ProofAction{}
end
