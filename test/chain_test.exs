defmodule ChainTest do
  @moduledoc false
  alias Ucan.ProofChains
  alias Ucan.Keymaterial
  alias Ucan.Builder
  use ExUnit.Case

  setup do
    alice_keypair = Ucan.create_default_keypair()
    bob_keypair = Ucan.create_default_keypair()
    mallory_keypair = Ucan.create_default_keypair()

    %{alice_keypair: alice_keypair, bob_keypair: bob_keypair, mallory_keypair: mallory_keypair}
  end

  @tag :chain
  test "it_decodes_deep_ucan_chains_1, valid proof chain", meta do
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

    # delegated_token_2 =
    #   Builder.default()
    #   |> Builder.issued_by(meta.mallory_keypair)
    #   |> Builder.for_audience(Keymaterial.get_did(meta.alice_keypair))
    #   |> Builder.with_lifetime(86_400)
    #   |> Builder.witnessed_by(delegated_token)
    #   |> Builder.build!()
    #   |> Ucan.sign(meta.mallory_keypair)

    {:ok, _cid, store} = UcanStore.write(%MemoryStoreJwt{}, Ucan.encode(leaf_ucan))
    # {:ok, cid, store} = UcanStore.write(store, Ucan.encode(delegated_token))

    assert {:ok, %ProofChains{} = proof_chain} =
             ProofChains.from_token_string(Ucan.encode(delegated_token), store)

    assert length(proof_chain.proofs) == 1
    # We create a proof chain
    # then checks if the chain's last audience is mallory
    # and chains root issuer is alice
  end

  @tag :chain
  test "it_decodes_deep_ucan_chains_2, invalid proof chain, invalid attenuation", meta do
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

    # this token has a lifetime more than the token from which it delegates
    delegated_token_2 =
      Builder.default()
      |> Builder.issued_by(meta.mallory_keypair)
      |> Builder.for_audience(Keymaterial.get_did(meta.alice_keypair))
      |> Builder.with_lifetime(86_400)
      |> Builder.witnessed_by(delegated_token)
      |> Builder.build!()
      |> Ucan.sign(meta.mallory_keypair)

    {:ok, _cid, store} = UcanStore.write(%MemoryStoreJwt{}, Ucan.encode(leaf_ucan))
    {:ok, _cid, store} = UcanStore.write(store, Ucan.encode(delegated_token))

    assert {:error, "Invalid UCAN link: lifetime exceeds attenuation"} =
             ProofChains.from_token_string(Ucan.encode(delegated_token_2), store)
  end

  @tag :chain
  test "it_decodes_deep_ucan_chains_2, invalid proof chain, invalid iss-aud", meta do
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

    # The token proof doesn't actually delegates to mallory, instead it delegates to Bob
    delegated_token_2 =
      Builder.default()
      |> Builder.issued_by(meta.mallory_keypair)
      |> Builder.for_audience(Keymaterial.get_did(meta.alice_keypair))
      |> Builder.with_lifetime(60)
      |> Builder.witnessed_by(leaf_ucan)
      |> Builder.build!()
      |> Ucan.sign(meta.mallory_keypair)

    {:ok, _cid, store} = UcanStore.write(%MemoryStoreJwt{}, Ucan.encode(leaf_ucan))
    {:ok, _cid, store} = UcanStore.write(store, Ucan.encode(delegated_token))

    assert {:error, "Invalid UCAN link:" <> _} =
             ProofChains.from_token_string(Ucan.encode(delegated_token_2), store)
  end

end
