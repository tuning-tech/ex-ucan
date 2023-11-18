defprotocol UcanStore do
  @moduledoc """
  This protocol is to be implemented by storage backends suitable
  for storing UCAN token, which later will be referenced by other UCANs as
  proofs
  """

  @doc """
  Reads a value from the store by CID
  """
  @spec read(any(), cid :: String.t()) :: {:ok, any()} | {:error, String.t()}
  def read(store, cid)

  @doc """
  Writes a value to the store, and returns the CID of the value and store struct
  """
  @spec write(any(), any()) :: {:ok, cid :: String.t(), store :: any()} | {:error, String.t()}
  def write(store, token)
end

defmodule MemoryStoreJwt do
  @moduledoc """
  In-memory implementation of `UcanStore`, where tokens are stored as encoded JWT
  """
  defstruct [:cid, :token]
end

defimpl UcanStore, for: MemoryStoreJwt do
  alias Ucan.Token

  def write(_store, token) do
    with {:ok, token_cid} <- Token.to_cid(token, :blake3) do
      {:ok, token_cid, %MemoryStoreJwt{cid: token_cid, token: token}}
    end
  end

  def read(store, cid) do
    if Map.has_key?(store, cid) do
      {:ok, store.cid}
    else
      {:error, "CID not in the memory"}
    end
  end
end
