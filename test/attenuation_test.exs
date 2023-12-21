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

  @tag :atten_neo
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

  @tag :val_caveat
  test "it validates caveats" do
    resource = "mailto:alice@email.com"
    ability = "email/send"

    no_caveat = Capability.new(resource, ability, Jason.encode!(%{}))
    x_caveat = Capability.new(resource, ability, Jason.encode!(%{x: true}))
    y_caveat = Capability.new(resource, ability, Jason.encode!(%{y: true}))
    z_caveat = Capability.new(resource, ability, Jason.encode!(%{z: true}))
    yz_caveat = Capability.new(resource, ability, Jason.encode!(%{z: true, y: true}))

    valid = [
      {[no_caveat], [no_caveat]},
      {[x_caveat], [x_caveat]},
      {[no_caveat], [x_caveat]},
      {[x_caveat, y_caveat], [x_caveat]},
      {[x_caveat, y_caveat], [x_caveat, yz_caveat]}
    ]

    invalid = [
      {[x_caveat], [no_caveat]},
      {[x_caveat], [y_caveat]},
      {[x_caveat, y_caveat], [x_caveat, y_caveat, z_caveat]}
    ]

    for {proof_caps, delegated_caps} <- valid do
      is_success? = test_capabilities_delegation(proof_caps, delegated_caps)

      assert(
        is_success?,
        "#{render_caveats(proof_caps)} enables #{render_caveats(delegated_caps)}"
      )
    end

    for {proof_caps, delegated_caps} <- invalid do
      is_success? = test_capabilities_delegation(proof_caps, delegated_caps)

      assert(
        not is_success?,
        "#{render_caveats(proof_caps)} disallows #{render_caveats(delegated_caps)}"
      )
    end
  end

  @spec test_capabilities_delegation(list(Capability), list(Capability)) :: boolean()
  defp test_capabilities_delegation(proof_capabilities, delegated_capabilities) do
    alice_keypair = Ucan.create_default_keypair()
    mallory_keypair = Ucan.create_default_keypair()

    email_semantics = %EmailSemantics{}

    proof_ucan =
      Builder.default()
      |> Builder.issued_by(alice_keypair)
      |> Builder.for_audience(Keymaterial.get_did(mallory_keypair))
      |> Builder.with_lifetime(60)
      |> Builder.claiming_capabilities(proof_capabilities)
      |> Builder.build!()
      |> Ucan.sign(alice_keypair)

    ucan =
      Builder.default()
      |> Builder.issued_by(mallory_keypair)
      |> Builder.for_audience(Keymaterial.get_did(alice_keypair))
      |> Builder.with_lifetime(50)
      |> Builder.witnessed_by(proof_ucan)
      |> Builder.claiming_capabilities(delegated_capabilities)
      |> Builder.build!()
      |> Ucan.sign(mallory_keypair)

    {:ok, _cid, store} = UcanStore.write(%MemoryStoreJwt{}, Ucan.encode(proof_ucan))
    {:ok, _cid, store} = UcanStore.write(store, Ucan.encode(ucan))

    # |> IO.inspect()
    assert {:ok, prf_chain} =
             ProofChains.from_ucan(ucan, store)

    enable_capabilities(
      prf_chain,
      email_semantics,
      Keymaterial.get_did(alice_keypair),
      delegated_capabilities
    )
  end

  # Checks proof chain returning true if all desired capabilities are enabled
  @spec enable_capabilities(ProofChains.t(), Semantics.t(), String.t(), list(Capability)) ::
          boolean()
  defp enable_capabilities(proof_chain, email_semantics, originator, desired_capabilities) do
    capability_infos = ProofChains.reduce_capabilities(proof_chain, email_semantics)
    # for each desired_capability
    #   for each capability_info
    #     check if capability_info's originator same as given originator and also
    #       capability_info.capability enables desired_capability (parse to get capability view)
    #         if yes, then exit with has_capability true.
    #         else, check for other capability infos with the desired capability
    Enum.reduce_while(desired_capabilities, false, fn desired_capability, _has_capability ->
      has_capability =
        Enum.reduce_while(capability_infos, false, fn %CapabilityInfo{} = capability_info,
                                                      _has_capability ->
          if originator in capability_info.originators and
               Capability.View.enables?(
                 capability_info.capability,
                 Semantics.parse_capability(email_semantics, desired_capability)
               ) do
            {:halt, true}
          else
            {:cont, false}
          end
        end)

      if has_capability do
        {:cont, true}
      else
        {:halt, false}
      end
    end)
  end

  @spec render_caveats(list(Capability)) :: list(String.t())
  defp render_caveats(capabilities) do
    Enum.map(capabilities, fn %Capability{caveat: caveat} ->
      inspect(caveat)
    end)
  end
end
