defmodule Ucan.Utils do
  @moduledoc """
  Core utils
  """
  @chars "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

  @doc """
  Generate random string to use as a nonce

  ## Examples
      iex> Ucan.Utils.generate_nonce() |> String.length
      6
      iex> Ucan.Utils.generate_nonce(10) |> String.length
      10
  """
  def generate_nonce(len \\ 6)

  def generate_nonce(len) do
    Enum.reduce(1..len, "", fn _, nonce ->
      nonce <> String.at(@chars, :rand.uniform(String.length(@chars) - 1))
    end)
  end
end
