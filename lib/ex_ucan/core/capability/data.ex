defmodule Ucan.Capability do
  @moduledoc """
  Capabilities are a list of `resources`, and the `abilities` that we
  can make on the `resource` with some optional `caveats`.
  """
  @type t :: %__MODULE__{
          resource: String.t(),
          ability: String.t(),
          caveats: list(map())
        }

  @derive Jason.Encoder
  defstruct [:resource, :ability, :caveats]

  @doc """
  Creates a new capability with given resource, ability and caveat

  See `/test/capability_test.exs`
  """
  @spec new(String.t(), String.t(), list()) :: __MODULE__.t()
  def new(resource, ability, caveat) when is_binary(resource) and is_binary(ability) do
    %__MODULE__{
      resource: resource,
      ability: ability,
      caveats: caveat
    }
  end
end

defmodule Ucan.Capabilities do
  @moduledoc """
  Handling conversions of different type of group of capabilities

  `Capabilities` are always maps of maps

  type reference - map<String: map<String: list()>>
  """
  alias Ucan.Capability

  @type t :: map()

  @doc """
  Convert capabilites represented in maps to list of capabilites

  Will ignore capabilities with empty caveats
  See `/test/capability_test.exs`
  """
  @spec map_to_sequence(map()) :: list(Capability.t())
  def map_to_sequence(capabilities) do
    Enum.reduce(capabilities, [], fn {resource, abilities}, caps ->
      caps ++
        Enum.reduce(abilities, [], fn
          {ability, caveats}, cap_list when length(caveats) >= 1 ->
            cap_list ++ [Capability.new(resource, ability, caveats)]

          {_ability, _caveats}, cap_list ->
            cap_list
        end)
    end)
  end

  @doc """
  Convert capabilites represented as list of capabilities to maps of maps

  See `/test/capability_test.exs`
  """
  @spec sequence_to_map(list(Capability.t())) :: {:ok, map()} | {:error, String.t()}
  def sequence_to_map(capabilites) do
    capabilites
    |> Enum.reduce(%{}, fn %Capability{} = cap, caps ->
      Map.update(caps, cap.resource, %{cap.ability => transform_caveats(cap.caveats)}, fn val ->
        Map.put(val, cap.ability, transform_caveats(cap.caveats))
      end)
    end)
    |> validate_resources()
  end

  @doc """
  Create Capabilities map from json or map, which does the validation too
  """
  @spec from(String.t() | map()) :: {:ok, map()} | {:error, String.t()}
  def from(value) when is_binary(value) do
    with {:ok, val} <- Jason.decode(value),
         {true, _} <- {is_map(val), "Capabilities must be a map"} do
      validate_resources(val)
    else
      {:error, err} when is_map(err) -> {:error, "Not a valid JSON"}
      {:error, err} -> {:error, err}
      {false, err} -> {:error, err}
    end
  end

  def from(value) when is_map(value) do
    validate_resources(value)
  end

  def from(_), do: {:error, "Capabilities must be a map"}

  @spec validate_resources(map()) :: {:ok, map()} | {:error, String.t()}
  defp validate_resources(value) when value == %{}, do: {:ok, value}

  defp validate_resources(value) do
    value
    |> Enum.reduce_while(%{}, fn {_resource, ability}, _resource_new ->
      with {true, _} <- {is_map(ability), :is_map},
           {true, _} <- {Map.keys(ability) |> length >= 1, :empty_map},
           {:ok, _} <- validate_ability(ability) do
        {:cont, {:ok, value}}
      else
        {false, :is_map} -> {:halt, {:error, "Abilities must be a map."}}
        {false, :empty_map} -> {:halt, {:error, "Resource must have atleast one ability."}}
        err -> {:halt, err}
      end
    end)
  end

  @spec validate_ability(map()) :: {:ok, map()} | {:error, String.t()}
  defp validate_ability(ability) do
    ability
    |> Enum.reduce_while(%{}, fn {_ability_b, caveats}, _ability_new ->
      with {true, _} <- {is_list(caveats), :list},
           {true, _} <- {Enum.all?(caveats, &is_map/1), :map} do
        {:cont, {:ok, ability}}
      else
        {false, :list} -> {:halt, {:error, "Caveats must be defined as a list."}}
        {false, :map} -> {:halt, {:error, "Caveat must be a map in #{inspect(caveats)}."}}
      end
    end)
  end

  @spec transform_caveats(any()) :: list()
  defp transform_caveats(caveats) when is_list(caveats), do: caveats
  defp transform_caveats(caveats), do: [caveats]
end
