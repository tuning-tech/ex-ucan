# Defining email semantics with email scope and email action

defmodule Ucan.EmailAddress do
  @moduledoc """
  EmailAddress is the scope, so must implement the given protocols
  - Ucan.Capability.Scope
  - Ucan.Utility.Convert
  - Kernel.to_string
  """
  alias Ucan.Capability.Scope

  @type t :: %__MODULE__{
          address: String.t()
        }
  defstruct [:address]

  defimpl Scope do
    def contains?(%{address: addr}, %{address: addr}), do: true
    def contains?(_, _), do: false
  end

  defimpl Ucan.Utility.Convert do
    alias Ucan.EmailAddress

    def from(_email_addr, %URI{scheme: "mailto", path: path} = _value) do
      {:ok, %EmailAddress{address: path}}
    end

    def from(_email_addr, %URI{scheme: _} = value) do
      {:error, "Could not interpret URI as an email address: #{value}"}
    end

    def from(_email_addr, value) do
      {:error, "Not a valid URI: #{value}"}
    end
  end

  defimpl String.Chars do
    def to_string(email_addr) do
      "mailto:#{email_addr.address}"
    end
  end
end

defmodule Ucan.EmailAction do
  @moduledoc """
  EmailAction is the ability part. Ability's are mostly behave like Enum.
  It should implement
  - Ucan.Utility.Convert
  - Kernel.to_string
  """

  @type t :: %__MODULE__{
          type: :send
        }
  defstruct [:type]

  defimpl String.Chars do
    def to_string(action) do
      case action.type do
        :send -> "email/send"
      end
    end
  end

  defimpl Ucan.Utility.Convert do
    alias Ucan.EmailAction

    def from(_action, value) do
      case value do
        "email/send" -> {:ok, %EmailAction{type: :send}}
        _ -> {:error, "Unrecognized action: #{}"}
      end
    end
  end
end

defmodule Ucan.EmailSemantics do
  @moduledoc """
  EmailSemantics can implement Capability.Semantics protocol, or go with the
  default implementations. If we are going with default implmentations
  The semantics struct should have a `scope` and `ability` field
  """

  @type t :: %__MODULE__{
          scope: Ucan.EmailAddress.t(),
          ability: Ucan.EmailAction.t()
        }

  defstruct scope: %Ucan.EmailAddress{}, ability: %Ucan.EmailAction{}
end
