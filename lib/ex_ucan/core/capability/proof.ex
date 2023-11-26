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
  end

  defimpl Ucan.Utility do
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
end

defmodule Ucan.ProofAction do
  @type t :: %__MODULE__{type: :delegate}
  defstruct type: :delegate

  defimpl Ucan.Utility do
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
end

defmodule Ucan.ProofDelegationSemantics do
  alias Ucan.ProofSelection.Index
  # implement Capability.Semantics protocol
  @type t :: %__MODULE__{
          scope: Ucan.ProofSelection.t(),
          ability: Ucan.ProofAction.t()
        }
  defstruct [:scope, :ability]

  # TODO: doc
  @spec new(integer()) :: __MODULE__.t()
  def new(prf_index \\ nil)

  def new(prf_index) do
    scope =
      if is_nil(prf_index) do
        %Ucan.ProofSelection{type: :all}
      else
        %Ucan.ProofSelection{type: %Index{value: prf_index}}
      end

    %__MODULE__{
      scope: scope,
      ability: %Ucan.ProofAction{}
    }
  end
end
