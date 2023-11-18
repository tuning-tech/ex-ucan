defmodule Ucan.Capability.View do
end

defprotocol Ucan.Capability.Scope do
  @spec contains?(any(), any()) :: boolean()
  def contains?(scope, other_scope)
end

defmodule Ucan.Capability.ResourceUri do
  defmodule Scoped do
    @type t :: %__MODULE__{
            scope: any()
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
  alias Ucan.Capability
  @fallback_to_any true
  @spec parse_scope(any(), String.t()) :: :ok | nil
  def parse_scope(semantics, scope)

  @spec parse_scope(any(), String.t()) :: :ok | nil
  def parse_action(semantics, ability)

  @spec extract_did(any(), String.t()) :: {String.t(), String.t()} | nil
  def extract_did(semantics, path)

  @spec parse_resource(any(), String.t()) :: String.t() | nil
  def parse_resource(semantics, resource)

  @spec parse_caveat(any(), map()) :: map()
  def parse_caveat(semantics, value)

  @spec parse(any(), String.t(), String.t(), map() | nil) :: Ucan.Capability.View | nil
  def parse(semantics, resource, ability, caveat)

  @spec parse_capability(any(), Capability.t()) :: Ucan.Capability.View | nil
  def parse_capability(semantics, capability)
end

defimpl Ucan.Capability.Semantics, for: Any do
  alias Ucan.Capability.Resource.As
  alias Ucan.Capability.Resource.My
  alias Ucan.Capability.Resource
  alias Ucan.Capability.Resource.ResourceType
  def parse_scope(_semantics, _scope), do: :ok
  def parse_action(_semantics, _ability), do: :ok
  def extract_did(_semantics, _path), do: {"", ""}
  def parse_resource(_semantics, _resource), do: ""
  def parse_caveat(_semantics, _value), do: %{}

  def parse(semantics, resource, ability, caveat) do
    uri = URI.decode(resource)
    uri_scheme = String.split(":") |> List.first()

    cap_resource =
      case uri_scheme do
        "my" ->
          %Resource{type: %My{kind: parse_resource(semantics, uri)}}

        "as" ->
          # TODO: extract_did can return nil.., handle it later
          {did, resource} = extract_did(semantics, uri)
          # TODO: don't know if we really have to pass the semantics
          # TODO: There's a URI parsing in rust, check later
          %Resource{type: %As{did: did, kind: parse_resource(semantics, resource)}}

        _ ->
          %Resource{type: %ResourceType{kind: parse_resource(semantics, uri)}}
      end
  end

  def parse_capability(semantics, capability) do;
    parse(semantics, capability.resource, capability.ability, capability.caveat)
  end
end
