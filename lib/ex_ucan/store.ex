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
  @type t :: %__MODULE__{
          data: map()
        }
  defstruct data: %{}
end

defimpl UcanStore, for: MemoryStoreJwt do
  alias Ucan.Token

  # defstruct [:store]
  # destructure()
  def write(store, token) do
    with {:ok, ucan} <- Token.decode(token),
         {:ok, token_cid} <- Token.to_cid(ucan, :blake3) do
      {:ok, token_cid, %{store | data: Map.put(store.data, token_cid, token)}}
    end
  end

  def read(store, cid) do
    if Map.has_key?(store.data, cid) do
      {:ok, store.data[cid]}
    else
      {:error, "CID not in the memory"}
    end
  end
end
