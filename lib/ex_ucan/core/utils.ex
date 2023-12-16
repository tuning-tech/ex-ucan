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

  @doc """
  Converts an `{:ok, t()}`, `:ok`, `{:error, err}`, `err` to  `t()`, `nil`, `:ok`

  This is a variant of ok() function in Rust which converts Result into Option while discarding the error
  """
  @spec ok({:ok, term()} | :ok | {:error, term()} | :error) :: term() | nil
  def ok({:ok, value}), do: value
  def ok(:ok), do: :ok
  def ok(_), do: nil
end

defprotocol Ucan.Utility.Convert do
  @doc """
  Takes any value and convert it to `{:ok, t()} | {:error, term()}`
  """
  @spec from(t(), URI.t() | String.t() | any()) :: {:ok, t()} | {:error, term()}
  def from(scope, value)
end

defprotocol Ucan.Utility.PartialOrder do
  @spec compare(t(), t()) :: :gt | :lt | :eq
  def compare(term_1, term_2)
end
