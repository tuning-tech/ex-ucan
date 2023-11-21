defmodule Ucan.Capability.View do
end

defprotocol Ucan.Capability.Scope do
  @spec contains?(Scope, any()) :: boolean()
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
end

defprotocol Ucan.Capability.Semantics do
  alias Ucan.Capability.ResourceUri
  alias Ucan.Capability.Ability
  alias Ucan.Capability.Semantics
  alias Ucan.Capability.Scope
  alias Ucan.Capability
  @fallback_to_any true

  @spec get_scope(Semantics) :: Scope
  def get_scope(semantics)

  @spec get_ability(Semantics) :: Scope
  def get_ability(semantics)

  @spec parse_scope(any(), URI.t()) :: Scope | nil
  def parse_scope(semantics, scope)

  @spec parse_action(any(), String.t()) :: Ability | nil
  def parse_action(semantics, ability)

  @spec extract_did(any(), String.t()) :: {String.t(), String.t()} | nil
  def extract_did(semantics, path)

  @spec parse_resource(any(), URI.t()) :: ResourceUri | nil
  def parse_resource(semantics, resource)

  @spec parse_caveat(any(), map()) :: map()
  def parse_caveat(semantics, value)

  @spec parse(any(), String.t(), String.t(), map() | nil) ::
          {:ok, Ucan.Capability.View} | {:error, String.t()}
  def parse(semantics, resource, ability, caveat)

  @spec parse_capability(any(), Capability.t()) :: Ucan.Capability.View | nil
  def parse_capability(semantics, capability)
end

defimpl Ucan.Capability.Semantics, for: Any do
  alias Ucan.Utils
  alias Ucan.Utility
  alias Ucan.Capability.ResourceUri.Scoped
  alias Ucan.Capability.Ability
  alias Ucan.Capability.Semantics
  alias Ucan.Capability.Scope
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
    Utility.from(get_scope(semantics), uri) |> Utils.ok()
  end

  def parse_action(semantics, ability) do
    Utility.from(get_ability(semantics), ability) |> Utils.ok()
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
          # TODO: extract_did can return nil.., handle it later
          {did, resource} = extract_did(semantics, uri.path)
          %Resource{type: %As{did: did, kind: parse_resource(semantics, URI.parse(resource))}}

        _ ->
          %Resource{type: %ResourceType{kind: parse_resource(semantics, uri)}}
      end
  end

  def parse_capability(semantics, capability) do
    parse(semantics, capability.resource, capability.ability, capability.caveats)
  end
end
