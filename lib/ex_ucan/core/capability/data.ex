defmodule Ucan.Core.Capability do
  @moduledoc """
  Capabilities are a list of `resources`, and the `abilities` that we
  can make on the `resource` with some optional `caveats`.
  """
  @type t :: %__MODULE__{
          resource: String.t(),
          ability: String.t(),
          caveat: list(map())
        }
  defstruct [:resource, :ability, :caveat]

  @doc """
  Creates a new capability with given resource, ability and caveat

  See `/test/capability_test.exs`
  """
  @spec new(String.t(), String.t(), list()) :: __MODULE__.t()
  def new(resource, ability, caveat) do
    %__MODULE__{
      resource: resource,
      ability: ability,
      caveat: caveat
    }
  end
end

defmodule Ucan.Core.Capabilities do
  @moduledoc """
  Handling conversions of different type of group of capabilities

  `Capabilities` are always maps of maps

  type reference - map<String: map<String: list()>>
  """
  alias Ucan.Core.Capability

  @doc """
  Convert capabilites represented in maps to list of capabilites

  See `/test/capability_test.exs`
  """
  @spec map_to_sequence(map()) :: list(Capability.t())
  def map_to_sequence(capabilities) do
    capabilities
    |> Enum.reduce([], fn {resource, ability}, caps ->
      [{ability, caveat}] = Map.to_list(ability)
      caps ++ [Capability.new(resource, ability, caveat)]
    end)
  end

  @doc """
  Convert capabilites represented as list of capabilities to maps of maps

  See `/test/capability_test.exs`
  """
  @spec sequence_to_map(list(Capability.t())) :: map()
  def sequence_to_map(capabilites) do
    capabilites
    |> Enum.reduce(%{}, fn %Capability{} = cap, caps ->
      Map.put(caps, cap.resource, %{cap.ability => cap.caveat})
    end)
  end
end
