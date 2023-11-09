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
  Converts a caveat in JSON string to map with validations
  """
  @spec from(String.t()) :: {:ok, map()} | {:error, String.t()}
  def from(value) when is_binary(value) do
    with {:ok, val} <- Jason.decode(value),
         true <- is_map(val) do
      {:ok, val}
    else
      {:error, _} -> {:error, "Not a valid JSON"}
      _ -> {:error, "Caveat must be a map"}
    end
  end

  def from(_), do: {:error, "Caveat is not JSON string"}

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
