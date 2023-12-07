defmodule AttenuationTest do
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
  end
end
