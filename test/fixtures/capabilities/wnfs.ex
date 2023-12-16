# Defining wnfs semantics with wnfs scope and wnfs action

defmodule Ucan.WnfsScope do
  @moduledoc """
  WnfsScope is the scope, so must implement the given protocols
  - Ucan.Capability.Scope
  - Ucan.Utility.Convert
  - Kernel.to_string
  """
  alias Ucan.Capability.Scope

  # TODO: typedoc
  @type t :: %__MODULE__{
          origin: String.t(),
          path: String.t()
        }

  defstruct [:origin, :path]

  defimpl Scope do
    def contains?(%{origin: origin}, %{origin: other_origin}) when origin != other_origin,
      do: false

    def contains?(%{path: path}, %{path: other_path})
        when is_binary(path) and is_binary(other_path) do
      path_parts = String.split(path, "/")
      other_path_parts = String.split(other_path, "/")
      is_path_parent?(path_parts, other_path_parts)
    end

    def contains?(_, _), do: false

    @spec is_path_parent?(list(String.t()), list(String.t())) :: boolean()
    defp is_path_parent?(path_parts, other_path_parts)
    defp is_path_parent?([], _), do: true
    defp is_path_parent?(_, []), do: false

    defp is_path_parent?([parent_h | _parent_t], [other_h | _other_t]) when parent_h != other_h,
      do: false

    defp is_path_parent?([parent_h | parent_t], [parent_h | other_t]) do
      is_path_parent?(parent_t, other_t)
    end
  end

  defimpl Ucan.Utility.Convert do
    alias Ucan.WnfsScope

    def from(_, %URI{scheme: "wnfs", path: path, host: host})
        when is_binary(path) and is_binary(host) do
      {:ok, %WnfsScope{origin: host, path: path}}
    end

    def from(_, %URI{} = value) do
      {:error, "Cannot interpret URI as WNFS scope: #{value}"}
    end

    def from(_, value) do
      {:error, "Not a valid URI: #{value}"}
    end
  end

  defimpl String.Chars do
    alias Ucan.WnfsScope

    def to_string(%WnfsScope{} = wnfs_scope) do
      "wnfs://#{wnfs_scope.origin}#{wnfs_scope.path}"
    end
  end
end

defmodule Ucan.WnfsCapLevel do
  @moduledoc """
  WnfsCapLevel is the ability part. Ability's are mostly behave like Enum.
  It should implement
  - Ucan.Utility.Convert
  - Kernel.to_string
  """

  @type t :: %__MODULE__{
          type: :create | :revise | :softdelete | :overwrite | :superuser
        }
  defstruct [:type]

  defimpl String.Chars do
    alias Ucan.WnfsCapLevel

    def to_string(%WnfsCapLevel{} = action) do
      case action.type do
        :create -> "wnfs/create"
        :revise -> "wnfs/revise"
        :softdelete -> "wnfs/softdelete"
        :overwrite -> "wnfs/overwrite"
        :superuser -> "wnfs/superuser"
      end
    end
  end

  defimpl Ucan.Utility.Convert do
    alias Ucan.WnfsCapLevel

    def from(_action, value) do
      case value do
        "wnfs/create" -> {:ok, %WnfsCapLevel{type: :create}}
        "wnfs/revise" -> {:ok, %WnfsCapLevel{type: :revise}}
        "wnfs/soft_delete" -> {:ok, %WnfsCapLevel{type: :softdelete}}
        "wnfs/overwrite" -> {:ok, %WnfsCapLevel{type: :overwrite}}
        "wnfs/super_user" -> {:ok, %WnfsCapLevel{type: :superuser}}
        _ -> {:error, "No such WNFS capability level: #{value}"}
      end
    end
  end

  defimpl Ucan.Utility.PartialOrder do
    alias Ucan.WnfsCapLevel
    @wnfs_cap_order %{
        create: 0,
        revise: 1,
        softdelete: 2,
        overwrite: 3,
        superuser: 4
    }
    def compare(%WnfsCapLevel{} = ability, %WnfsCapLevel{} = other_ability) do
      case {@wnfs_cap_order[ability.type], @wnfs_cap_order[other_ability.type]} do
        {order_a, order_a} -> :eq
        {order_a, order_b} when order_a > order_b -> :gt
        _ -> :lt
      end
    end
  end
end

defmodule Ucan.WnfsSemantics do
  @moduledoc """
  WnfsSemantics can implement Capability.Semantics protocol, or go with the
  default implementations. If we are going with default implmentations
  The semantics struct should have a `scope` and `ability` field
  """

  @type t :: %__MODULE__{
          scope: Ucan.WnfsScope.t(),
          ability: Ucan.WnfsCapLevel.t()
        }

  defstruct scope: %Ucan.WnfsScope{}, ability: %Ucan.WnfsCapLevel{}
end
