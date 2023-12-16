defmodule AttenuationTest do
  alias Ucan.CapabilityInfo
  alias Ucan.Capability
  alias Ucan.ProofChains
  alias Ucan.Capability.Semantics
  alias Ucan.Keymaterial
  alias Ucan.Builder
  alias Ucan.EmailSemantics
  use ExUnit.Case

  setup do
    keypair = Ucan.create_default_keypair()
    bob_keypair = Ucan.create_default_keypair()
    mallory_keypair = Ucan.create_default_keypair()

    %{alice_keypair: keypair, bob_keypair: bob_keypair, mallory_keypair: mallory_keypair}
  end

  @tag :atten
  test "it_works_with_simple_example", meta do
    email_semantics = %EmailSemantics{}

    send_email_as_alice =
      Semantics.parse(email_semantics, "mailto:alice@email.com", "email/send", nil)

    send_email_caps = Capability.new(send_email_as_alice)

    leaf_ucan =
      Builder.default()
      |> Builder.issued_by(meta.alice_keypair)
      |> Builder.for_audience(Keymaterial.get_did(meta.bob_keypair))
      |> Builder.with_lifetime(60)
      |> Builder.claiming_capability(send_email_caps)
      |> Builder.build!()
      |> Ucan.sign(meta.alice_keypair)

    delegated_token =
      Builder.default()
      |> Builder.issued_by(meta.bob_keypair)
      |> Builder.for_audience(Keymaterial.get_did(meta.mallory_keypair))
      |> Builder.with_lifetime(50)
      |> Builder.claiming_capability(send_email_caps)
      |> Builder.witnessed_by(leaf_ucan)
      |> Builder.build!()
      |> Ucan.sign(meta.bob_keypair)

    {:ok, _cid, store} = UcanStore.write(%MemoryStoreJwt{}, Ucan.encode(leaf_ucan))

    assert {:ok, prf_chain} =
             ProofChains.from_token_string(Ucan.encode(delegated_token), store)

    assert [_ | _] =
             capability_infos =
             ProofChains.reduce_capabilities(prf_chain, email_semantics)

    assert length(capability_infos) == 1
    %CapabilityInfo{} = info = List.first(capability_infos)
    assert to_string(info.capability.resource) == "mailto:alice@email.com"
    assert to_string(info.capability.ability) == "email/send"

    # Originator should be the issuer of leaf ucan
    assert [Keymaterial.get_did(meta.alice_keypair)] == info.originators
  end

  @tag :atten
  test "it reports the first issuer in the chain as the originator", meta do
    email_semantics = %EmailSemantics{}

    send_email_as_bob =
      Semantics.parse(email_semantics, "mailto:bob@email.com", "email/send", nil)

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
      |> Builder.with_lifetime(50)
      |> Builder.claiming_capability(send_email_as_bob)
      |> Builder.witnessed_by(leaf_ucan)
      |> Builder.build!()
      |> Ucan.sign(meta.bob_keypair)

    {:ok, _cid, store} = UcanStore.write(%MemoryStoreJwt{}, Ucan.encode(leaf_ucan))

    assert {:ok, prf_chain} =
             ProofChains.from_token_string(Ucan.encode(delegated_token), store)

    assert [_ | _] =
             capability_infos =
             ProofChains.reduce_capabilities(prf_chain, email_semantics)

    assert length(capability_infos) == 1
    %CapabilityInfo{} = info = List.first(capability_infos)

    assert [Keymaterial.get_did(meta.bob_keypair)] == info.originators
    assert info.capability == send_email_as_bob
  end

  @tag :attenz
  test "it finds the right proof chain for the originator", meta do
    email_semantics = %EmailSemantics{}

    send_email_as_bob =
      Semantics.parse(email_semantics, "mailto:bob@email.com", "email/send", nil)

    send_email_as_alice =
      Semantics.parse(email_semantics, "mailto:alice@email.com", "email/send", nil)

    leaf_ucan =
      Builder.default()
      |> Builder.issued_by(meta.alice_keypair)
      |> Builder.for_audience(Keymaterial.get_did(meta.mallory_keypair))
      |> Builder.with_lifetime(60)
      |> Builder.claiming_capability(send_email_as_alice)
      |> Builder.build!()
      |> Ucan.sign(meta.alice_keypair)

    leaf_ucan_bob =
      Builder.default()
      |> Builder.issued_by(meta.bob_keypair)
      |> Builder.for_audience(Keymaterial.get_did(meta.mallory_keypair))
      |> Builder.with_lifetime(60)
      |> Builder.claiming_capability(send_email_as_bob)
      |> Builder.build!()
      |> Ucan.sign(meta.bob_keypair)

    ucan =
      Builder.default()
      |> Builder.issued_by(meta.mallory_keypair)
      |> Builder.for_audience(Keymaterial.get_did(meta.alice_keypair))
      |> Builder.with_lifetime(50)
      |> Builder.witnessed_by(leaf_ucan)
      |> Builder.witnessed_by(leaf_ucan_bob)
      |> Builder.claiming_capability(send_email_as_alice)
      |> Builder.claiming_capability(send_email_as_bob)
      |> Builder.build!()
      |> Ucan.sign(meta.mallory_keypair)

    {:ok, _cid, store} = UcanStore.write(%MemoryStoreJwt{}, Ucan.encode(leaf_ucan))
    {:ok, _cid, store} = UcanStore.write(store, Ucan.encode(leaf_ucan_bob))

    assert {:ok, prf_chain} =
             ProofChains.from_token_string(Ucan.encode(ucan), store)

    assert [_ | _] =
             capability_infos =
             ProofChains.reduce_capabilities(prf_chain, email_semantics)

    assert length(capability_infos) == 2

    [send_email_as_bob_info, send_email_as_alice_info] = capability_infos

    assert send_email_as_alice_info == %CapabilityInfo{
             originators: [Keymaterial.get_did(meta.alice_keypair)],
             capability: send_email_as_alice,
             not_before: Ucan.not_before(ucan),
             expires_at: Ucan.expires_at(ucan)
           }

    assert send_email_as_bob_info == %CapabilityInfo{
             originators: [Keymaterial.get_did(meta.bob_keypair)],
             capability: send_email_as_bob,
             not_before: Ucan.not_before(ucan),
             expires_at: Ucan.expires_at(ucan)
           }
  end

  @tag :attenu
  test "it reports all chain options", meta do
    email_semantics = %EmailSemantics{}

    send_email_as_alice =
      Semantics.parse(email_semantics, "mailto:alice@email.com", "email/send", nil)

    leaf_ucan_alice =
      Builder.default()
      |> Builder.issued_by(meta.alice_keypair)
      |> Builder.for_audience(Keymaterial.get_did(meta.mallory_keypair))
      |> Builder.with_lifetime(60)
      |> Builder.claiming_capability(send_email_as_alice)
      |> Builder.build!()
      |> Ucan.sign(meta.alice_keypair)

    leaf_ucan_bob =
      Builder.default()
      |> Builder.issued_by(meta.bob_keypair)
      |> Builder.for_audience(Keymaterial.get_did(meta.mallory_keypair))
      |> Builder.with_lifetime(60)
      |> Builder.claiming_capability(send_email_as_alice)
      |> Builder.build!()
      |> Ucan.sign(meta.bob_keypair)

    ucan =
      Builder.default()
      |> Builder.issued_by(meta.mallory_keypair)
      |> Builder.for_audience(Keymaterial.get_did(meta.alice_keypair))
      |> Builder.with_lifetime(50)
      |> Builder.witnessed_by(leaf_ucan_alice)
      |> Builder.witnessed_by(leaf_ucan_bob)
      |> Builder.claiming_capability(send_email_as_alice)
      |> Builder.build!()
      |> Ucan.sign(meta.mallory_keypair)

    {:ok, _cid, store} = UcanStore.write(%MemoryStoreJwt{}, Ucan.encode(leaf_ucan_alice))
    {:ok, _cid, store} = UcanStore.write(store, Ucan.encode(leaf_ucan_bob))

    assert {:ok, prf_chain} =
             ProofChains.from_token_string(Ucan.encode(ucan), store)

    assert [_ | _] =
             capability_infos =
             ProofChains.reduce_capabilities(prf_chain, email_semantics)

    assert length(capability_infos) == 1

    [send_email_as_alice_info] = capability_infos

    assert send_email_as_alice_info == %CapabilityInfo{
             originators: [
               Keymaterial.get_did(meta.alice_keypair),
               Keymaterial.get_did(meta.bob_keypair)
             ],
             capability: send_email_as_alice,
             not_before: Ucan.not_before(ucan),
             expires_at: Ucan.expires_at(ucan)
           }
  end
end
