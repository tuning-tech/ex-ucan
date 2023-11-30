# Defining wnfs semantics with wnfs scope and wnfs action

defmodule Ucan.WnfsScope do
  @moduledoc """
  WnfsScope is the scope, so must implement the given protocols
  - Ucan.Capability.Scope
  - Ucan.Utility
  - Kernel.to_string
  """
  alias Ucan.Capability.Scope

  @type t :: %__MODULE__{
    origin: String.t(),
    path: String.t()
  }

  defstruct [:origin, :path]

  defimpl Scope do
    def contains?(%{origin: origin}, %{origin: other_origin}) when origin != other_origin, do: false
    def contains?(%{path: path}, %{path: other_path}) do
      path_parts = String.split(path, "/")
      other_path_parts = String.split(other_path, "/")
      is_path_parent?(path_parts, other_path_parts)
    end

    def contains?(_, _), do: false

    @spec is_path_parent?(list(String.t()), list(String.t())) :: boolean()
    defp is_path_parent?(path_parts, other_path_parts)
    defp is_path_parent?([], _), do: true
    defp is_path_parent?(_, []), do: false
    defp is_path_parent?([parent_h | parent_t], [other_h | other_t]) when parent_h != other_h, do: false
    defp is_path_parent?([parent_h | parent_t], [parent_h | other_t]) do
      is_path_parent?(parent_t, other_t)
    end
  end

  defimpl Ucan.Utility do
    alias Ucan.EmailAddress
    def from(_email_addr, %URI{scheme: "mailto", path: path} = value) do
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
  - Ucan.Utility
  - Kernel.to_string
  """

  @type t :: %__MODULE__{
    type: :send
  }
  defstruct [:type]

  defimpl String.Chars  do
    def to_string(action) do
      case action.type do
        :send -> "email/send"
      end
    end
  end

  defimpl Ucan.Utility do
    alias Ucan.EmailAction
    def from(action, value) do
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

  defstruct [:scope, :ability]

  def new() do
    %__MODULE__{
      scope: %Ucan.EmailAddress{address: "p@g.com"},
      ability: %Ucan.EmailAction{type: :send}
    }
  end
end
