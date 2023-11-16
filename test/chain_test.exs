defmodule ChainTest do
  @moduledoc false
  alias Ucan.Keymaterial
  alias Ucan.MemoryStoreJwt
  alias Ucan.Builder
  use ExUnit.Case

  setup do
    alice_keypair = Ucan.create_default_keypair()
    bob_keypair = Ucan.create_default_keypair()
    mallory_keypair = Ucan.create_default_keypair()

    %{alice_keypair: alice_keypair, bob_keypair: bob_keypair, mallory_keypair: mallory_keypair}
  end

  @tag :chain
  test "it_decodes_deep_ucan_chains", meta do
    leaf_ucan =
      Builder.default()
      |> Builder.issued_by(meta.alice_keypair)
      |> Builder.for_audience(Keymaterial.get_did(meta.bob_keypair))
      |> Builder.with_lifetime(60)
      |> Builder.build!()
      |> Ucan.sign(meta.alice_keypair)

    delegated_token =
      Builder.default()
      |> Builder.issued_by(meta.bob_keypair)
      |> Builder.for_audience(Keymaterial.get_did(meta.mallory_keypair))
      |> Builder.with_lifetime(60)
      |> Builder.witnessed_by(leaf_ucan)
      |> Builder.build!()
      |> Ucan.sign(meta.bob_keypair)

    store = Ucan.Store.write(%MemoryStoreJwt{}, Ucan.encode(leaf_ucan))
    # We create a proof chain
    # then checks if the chain's last audience is mallory
    # and chains root issuer is alice


  end
end
