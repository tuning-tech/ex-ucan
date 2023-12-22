defmodule Ucan.Capability.Caveats do
  @moduledoc """
  Utilities for managing caveats
  """

  @doc """
  Determines if first caveat enables/allows second caveat
  """
  @spec enables?(map(), map()) :: boolean()
  def enables?(%{} = caveat_a, %{} = caveat_b) do
    cond do
      caveat_a == %{} ->
        true

      caveat_b == %{} ->
        false

      caveat_a == caveat_b ->
        true

      true ->
        # A should be a subset of B
        Enum.reduce_while(caveat_a, true, fn {k, v}, true ->
          satisfy_subset?(caveat_b, k, v)
        end)
    end
  end

  def enables?(_, _), do: false

  @doc """
  Parses a caveat JSON string or a map
  """
  @spec from(String.t() | map()) :: {:ok, map()} | {:error, String.t()}
  def from(value) when is_binary(value) do
    with {:ok, val} <- Jason.decode(value),
         true <- is_map(val) do
      {:ok, val}
    else
      {:error, _} -> {:error, "Not a valid JSON, got #{value}"}
      _ -> {:error, "Caveat must be a map, got #{value}"}
    end
  end

  def from(%{} = value) do
    {:ok, value}
  end

  def from(value), do: {:error, "Caveat must be a JSON string or map, got #{inspect(value)}"}

  # A should be a subset of B
  defp satisfy_subset?(caveat_b, k, v) do
    with true <- Map.has_key?(caveat_b, k),
         true <- Map.get(caveat_b, k) == v do
      {:cont, true}
    else
      _ -> {:halt, false}
    end
  end
end
