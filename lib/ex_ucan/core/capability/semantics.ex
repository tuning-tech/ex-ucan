defprotocol Ucan.Capability.Scope do
  @spec contains?(t(), t()) :: boolean()
  def contains?(scope, other_scope)
end

defmodule Ucan.Capability.ResourceUri do
  defmodule Scoped do
    @type t :: %__MODULE__{
            scope: Scope
          }
    defstruct [:scope]
  end

  @type t :: %__MODULE__{
          type: Scoped | :unscoped
        }

  defstruct [:type]

  defimpl Ucan.Capability.Scope do
    def contains?(resource_uri, other_resource_uri) do
      case resource_uri.type do
        :unscoped ->
          true

        %Scoped{scope: scope} ->
          case other_resource_uri.type do
            %Scoped{scope: other_resource_scope} ->
              contains?(scope, other_resource_scope)

            _ ->
              false
          end
      end
    end
  end

  defimpl String.Chars do
    def to_string(resource_uri) do
      case resource_uri.type do
        %Scoped{scope: scope} -> Kernel.to_string(scope)
        :unscoped -> "*"
      end
    end
  end
end

defmodule Ucan.Capability.Resource do
  defmodule ResourceType do
    alias Ucan.Capability.ResourceUri

    @type t :: %__MODULE__{
            kind: ResourceUri.t()
          }
    defstruct [:kind]
  end

  defmodule My do
    alias Ucan.Capability.ResourceUri

    @type t :: %__MODULE__{
            kind: ResourceUri.t()
          }
    defstruct [:kind]
  end

  defmodule As do
    alias Ucan.Capability.ResourceUri

    @type t :: %__MODULE__{
            did: String.t(),
            kind: ResourceUri.t()
          }
    defstruct [:did, :kind]
  end

  @type t :: %__MODULE__{
          type: ResourceType.t() | My.t() | As.t()
        }

  defstruct [:type]

  defimpl Ucan.Capability.Scope do
    def contains?(resource, other_resource) do
      case {resource, other_resource} do
        {%{type: %ResourceType{kind: res}}, %{type: %ResourceType{kind: other_res}}} ->
          contains?(res, other_res)

        {%{type: %My{kind: res}}, %{type: %My{kind: other_res}}} ->
          contains?(res, other_res)

        {%{type: %As{did: did, kind: res}}, %{type: %As{did: other_did, kind: other_res}}} ->
          if did == other_did, do: contains?(res, other_res), else: false
      end
    end
  end

  defimpl String.Chars do
    def to_string(resource) do
      case resource.type do
        %ResourceType{kind: kind} -> Kernel.to_string(kind)
        %My{kind: kind} -> "my:#{Kernel.to_string(kind)}"
        %As{did: did, kind: kind} -> "as:#{did}:#{Kernel.to_string(kind)}"
      end
    end
  end
end

defmodule Ucan.Capability.View do
  alias Ucan.Capability.Scope
  alias Ucan.Capability.Caveats
  alias Ucan.Capability.Resource

  @type t :: %__MODULE__{
          resource: Resource.t(),
          ability: any(),
          caveat: any()
        }

  defstruct [:resource, :ability, :caveat]

  @spec new(Resource.t(), any()) :: __MODULE__.t()
  def new(resource, ability) do
    %__MODULE__{
      resource: resource,
      ability: ability,
      caveat: Jason.encode!(%{})
    }
  end

  @spec new_with_caveat(Resource.t(), any(), String.t()) :: __MODULE__.t()
  def new_with_caveat(resource, ability, caveat) do
    %__MODULE__{
      resource: resource,
      ability: ability,
      caveat: caveat
    }
  end

  @spec enables?(__MODULE__.t(), __MODULE__.t()) :: boolean()
  def enables?(cap_view, other_cap_view) do
    case {Caveats.from(cap_view.caveat), Caveats.from(other_cap_view.caveat)} do
      {{:ok, caveat}, {:ok, other_caveat}} ->
        Scope.contains?(cap_view.resource, other_cap_view.resource) and
          cap_view.ability >= other_cap_view.ability and
          Caveats.enables?(caveat, other_caveat)

      _ ->
        false
    end
  end
end

defprotocol Ucan.Capability.Semantics do
  alias Ucan.Capability.ResourceUri
  alias Ucan.Capability.Semantics
  alias Ucan.Capability.Scope
  alias Ucan.Capability
  @fallback_to_any true

  @spec get_scope(Semantics) :: Scope
  def get_scope(semantics)

  @spec get_ability(Semantics) :: Module
  def get_ability(semantics)

  @spec parse_scope(t(), URI.t()) :: t() | nil
  def parse_scope(semantics, scope)

  @spec parse_action(t(), String.t()) :: t() | nil
  def parse_action(semantics, ability)

  @spec extract_did(any(), String.t()) :: {String.t(), String.t()} | nil
  def extract_did(semantics, path)

  @spec parse_resource(any(), URI.t()) :: ResourceUri | nil
  def parse_resource(semantics, resource)

  @spec parse_caveat(any(), map()) :: map()
  def parse_caveat(semantics, value)

  @spec parse(t(), String.t(), String.t(), map() | nil) ::
          Ucan.Capability.View | nil
  def parse(semantics, resource, ability, caveat)

  @spec parse_capability(any(), Capability.t()) :: Ucan.Capability.View | nil
  def parse_capability(semantics, capability)
end

defimpl Ucan.Capability.Semantics, for: Any do
  alias Ucan.Capability.View
  alias Ucan.Utils
  alias Ucan.Utility
  alias Ucan.Capability.ResourceUri.Scoped
  alias Ucan.Capability.Resource.As
  alias Ucan.Capability.Resource.My
  alias Ucan.Capability.Resource
  alias Ucan.Capability.Resource.ResourceType
  alias Ucan.Capability.ResourceUri

  def get_scope(semantics) do
    semantics.scope
  end

  def get_ability(semantics) do
    semantics.ability
  end

  def parse_scope(semantics, uri) do
    Utility.Convert.from(get_scope(semantics), uri) |> Utils.ok()
  end

  def parse_action(semantics, ability_str) do
    ability = get_ability(semantics)
    Utility.Convert.from(ability, ability_str) |> Utils.ok()
  end

  def extract_did(_semantics, path) do
    case String.split(path, ":") do
      ["did", "key", part3] -> {"did:key", part3}
      _ -> nil
    end
  end

  def parse_resource(semantics, resource) do
    resource_uri = URI.parse(resource)

    case resource_uri.path do
      "*" ->
        %ResourceUri{type: :unscoped}

      _ ->
        with scope when not is_nil(scope) <- parse_scope(semantics, resource) do
          %ResourceUri{type: %Scoped{scope: scope}}
        end
    end
  end

  def parse_caveat(_semantics, value) when is_nil(value), do: %{}
  def parse_caveat(_, value), do: value

  def parse(semantics, resource, ability, caveat) do
    uri = URI.parse(resource)

    cap_resource =
      case uri.scheme do
        "my" ->
          %Resource{type: %My{kind: parse_resource(semantics, uri)}}

        "as" ->
          with {did, resource} <- extract_did(semantics, uri.path) do
            %Resource{type: %As{did: did, kind: parse_resource(semantics, URI.parse(resource))}}
          end

        _ ->
          %Resource{type: %ResourceType{kind: parse_resource(semantics, uri)}}
      end

    cap_ability =
      with %_{} = ability <- parse_action(semantics, ability) do
        ability
      end

    cap_caveat = parse_caveat(semantics, caveat)

    with %Resource{} = cap_resource <- cap_resource,
         %_{} <- cap_ability do
      View.new_with_caveat(cap_resource, cap_ability, cap_caveat)
    end
  end

  def parse_capability(semantics, capability) do
    parse(semantics, capability.resource, capability.ability, capability.caveat)
  end
end
