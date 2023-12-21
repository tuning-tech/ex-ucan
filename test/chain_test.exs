defmodule ChainTest do
  @moduledoc false
  alias Ucan.ProofChains
  alias Ucan.Keymaterial
  alias Ucan.Builder
  alias Ucan.Capability
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

    {:ok, _cid, store} = UcanStore.write(%MemoryStoreJwt{}, Ucan.encode(leaf_ucan))

    assert {:ok, %ProofChains{} = proof_chain} =
             ProofChains.from_token_string(Ucan.encode(delegated_token), store)

    assert length(proof_chain.proofs) == 1
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

  @tag :chain
  test "it_decodes_deep_ucan_chains_3", meta do
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

    {:ok, _cid, store} = UcanStore.write(%MemoryStoreJwt{}, Ucan.encode(leaf_ucan))

    assert {:ok, %ProofChains{} = proof_chain} =
             ProofChains.from_token_string(Ucan.encode(delegated_token), store)

    assert length(proof_chain.proofs) == 1

    assert Ucan.audience(proof_chain.ucan) == Keymaterial.get_did(meta.mallory_keypair)
    [prf_chain_2 | _t] = proof_chain.proofs
    assert Ucan.issuer(prf_chain_2.ucan) == Keymaterial.get_did(meta.alice_keypair)
  end

  @tag :chain
  test "it_fails_with_incorrect_chaining", meta do
    leaf_ucan =
      Builder.default()
      |> Builder.issued_by(meta.alice_keypair)
      |> Builder.for_audience(Keymaterial.get_did(meta.bob_keypair))
      |> Builder.with_lifetime(60)
      |> Builder.build!()
      |> Ucan.sign(meta.alice_keypair)

    delegated_token =
      Builder.default()
      |> Builder.issued_by(meta.alice_keypair)
      |> Builder.for_audience(Keymaterial.get_did(meta.mallory_keypair))
      |> Builder.with_lifetime(50)
      |> Builder.witnessed_by(leaf_ucan)
      |> Builder.build!()
      |> Ucan.sign(meta.alice_keypair)

    {:ok, _cid, store} = UcanStore.write(%MemoryStoreJwt{}, Ucan.encode(leaf_ucan))

    assert {:error, "Invalid UCAN link:" <> _} =
             ProofChains.from_token_string(Ucan.encode(delegated_token), store)
  end

  @tag :chain
  test "it_can_be_instantiated_by_cid", meta do
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

    {:ok, _cid, store} = UcanStore.write(%MemoryStoreJwt{}, Ucan.encode(leaf_ucan))
    {:ok, cid, store} = UcanStore.write(store, Ucan.encode(delegated_token))

    assert {:ok, _} =
             ProofChains.from_cid(cid, store)
  end

  @tag :chain_rs
  test "it_can_handle_multiple_leaves", meta do
    leaf_ucan =
      Builder.default()
      |> Builder.issued_by(meta.alice_keypair)
      |> Builder.for_audience(Keymaterial.get_did(meta.bob_keypair))
      |> Builder.with_lifetime(60)
      |> Builder.build!()
      |> Ucan.sign(meta.alice_keypair)

    leaf_ucan_2 =
      Builder.default()
      |> Builder.issued_by(meta.mallory_keypair)
      |> Builder.for_audience(Keymaterial.get_did(meta.bob_keypair))
      |> Builder.with_lifetime(60)
      |> Builder.build!()
      |> Ucan.sign(meta.mallory_keypair)

    delegated_token =
      Builder.default()
      |> Builder.issued_by(meta.bob_keypair)
      |> Builder.for_audience(Keymaterial.get_did(meta.alice_keypair))
      |> Builder.with_lifetime(50)
      |> Builder.witnessed_by(leaf_ucan)
      |> Builder.witnessed_by(leaf_ucan_2)
      |> Builder.build!()
      |> Ucan.sign(meta.bob_keypair)

    {:ok, _cid, store} = UcanStore.write(%MemoryStoreJwt{}, Ucan.encode(leaf_ucan))
    {:ok, _cid, store} = UcanStore.write(store, Ucan.encode(leaf_ucan_2))

    assert {:ok, _} =
             ProofChains.from_token_string(Ucan.encode(delegated_token), store)
  end

  @tag :redel
  test "redelegations", meta do
    cap_bar = Capability.new("prf:2", "ucan/DELEGATE", Jason.encode!(%{}))

    leaf_ucan =
      Builder.default()
      |> Builder.issued_by(meta.alice_keypair)
      |> Builder.for_audience(Keymaterial.get_did(meta.bob_keypair))
      |> Builder.with_lifetime(60)
      |> Builder.build!()
      |> Ucan.sign(meta.alice_keypair)

    delegated_ucan =
      Builder.default()
      |> Builder.issued_by(meta.bob_keypair)
      |> Builder.for_audience(Keymaterial.get_did(meta.mallory_keypair))
      |> Builder.with_lifetime(50)
      |> Builder.claiming_capability(cap_bar)
      |> Builder.witnessed_by(leaf_ucan)
      |> Builder.build!()
      |> Ucan.sign(meta.bob_keypair)

    {:ok, _cid, store} = UcanStore.write(%MemoryStoreJwt{}, Ucan.encode(leaf_ucan))

    assert {:error, "Unable to redelegate proof" <> _} =
             ProofChains.from_token_string(Ucan.encode(delegated_ucan), store)
  end

  @tag :redel_2
  test "redelegations with proof index", meta do
    cap_bar = Capability.new("prf:0", "ucan/DELEGATE", Jason.encode!(%{}))

    leaf_ucan =
      Builder.default()
      |> Builder.issued_by(meta.alice_keypair)
      |> Builder.for_audience(Keymaterial.get_did(meta.bob_keypair))
      |> Builder.with_lifetime(60)
      |> Builder.build!()
      |> Ucan.sign(meta.alice_keypair)

    delegated_ucan =
      Builder.default()
      |> Builder.issued_by(meta.bob_keypair)
      |> Builder.for_audience(Keymaterial.get_did(meta.mallory_keypair))
      |> Builder.with_lifetime(50)
      |> Builder.witnessed_by(leaf_ucan)
      |> Builder.claiming_capability(cap_bar)
      |> Builder.build!()
      |> Ucan.sign(meta.bob_keypair)

    {:ok, _cid, store} = UcanStore.write(%MemoryStoreJwt{}, Ucan.encode(leaf_ucan))

    assert {:ok, %ProofChains{redelegations: [0]}} =
             ProofChains.from_token_string(Ucan.encode(delegated_ucan), store)
  end

  @tag :redel_3
  test "redelegations-unscoped", meta do
    cap_bar = Capability.new("prf:*", "ucan/DELEGATE", Jason.encode!(%{}))

    leaf_ucan =
      Builder.default()
      |> Builder.issued_by(meta.alice_keypair)
      |> Builder.for_audience(Keymaterial.get_did(meta.bob_keypair))
      |> Builder.with_lifetime(60)
      |> Builder.build!()
      |> Ucan.sign(meta.alice_keypair)

    delegated_ucan =
      Builder.default()
      |> Builder.issued_by(meta.bob_keypair)
      |> Builder.for_audience(Keymaterial.get_did(meta.mallory_keypair))
      |> Builder.with_lifetime(50)
      |> Builder.witnessed_by(leaf_ucan)
      |> Builder.claiming_capability(cap_bar)
      |> Builder.build!()
      |> Ucan.sign(meta.bob_keypair)

    {:ok, _cid, store} = UcanStore.write(%MemoryStoreJwt{}, Ucan.encode(leaf_ucan))

    assert {:ok, %ProofChains{redelegations: []}} =
             ProofChains.from_token_string(Ucan.encode(delegated_ucan), store)
  end
end
