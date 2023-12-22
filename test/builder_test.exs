defmodule BuilderTest do
  alias Ucan
  alias Ucan.Builder
  alias Ucan.Capability
  alias Ucan.Capabilities
  alias Ucan.Keymaterial
  alias Ucan.Token
  alias Ucan.UcanPayload
  use ExUnit.Case

  setup do
    keypair = Ucan.create_default_keymaterial()
    bob_keypair = Ucan.create_default_keymaterial()
    mallory_keypair = Ucan.create_default_keymaterial()

    %{keypair: keypair, bob_keypair: bob_keypair, mallory_keypair: mallory_keypair}
  end

  @tag :build
  test "builder functions, default" do
    assert %Builder{issuer: nil} = Builder.default()
  end

  @tag :build
  test "non-working builder flow", _meta do
    assert {:error, "must call issued_by/2"} = Builder.default() |> Builder.build()
  end

  @tag :build
  test "non-working builder flow, need for_audience", meta do
    assert {:error, "must call for_audience/2"} =
             Builder.default()
             |> Builder.issued_by(meta.keypair)
             |> Builder.build()
  end

  @tag :build
  test "non-working builder flow, need with_lifetime", meta do
    assert {:error, "must call with_lifetime/2 or with_expiration/2"} =
             Builder.default()
             |> Builder.issued_by(meta.keypair)
             |> Builder.for_audience("did:key:z6MkwDK3M4PxU1FqcSt4quXghquH1MoWXGzTrNkNWTSy2NLD")
             |> Builder.build()
  end

  @tag :build
  test "working builder flow", meta do
    assert {:ok, %UcanPayload{}} =
             Builder.default()
             |> Builder.issued_by(meta.keypair)
             |> Builder.for_audience("did:key:z6MkwDK3M4PxU1FqcSt4quXghquH1MoWXGzTrNkNWTSy2NLD")
             |> Builder.with_lifetime(86_400)
             |> Builder.build()
  end

  @tag :build
  test "working builder flow, with expiration", meta do
    assert {:ok, %UcanPayload{}} =
             Builder.default()
             |> Builder.issued_by(meta.keypair)
             |> Builder.for_audience("did:key:z6MkwDK3M4PxU1FqcSt4quXghquH1MoWXGzTrNkNWTSy2NLD")
             |> Builder.with_expiration((DateTime.utc_now() |> DateTime.to_unix()) + 86_400)
             |> Builder.build()
  end

  @tag :build
  test "more workflows", meta do
    assert {:ok, %UcanPayload{fct: %{"door" => "bronze"}, nnc: nnc}} =
             Builder.default()
             |> Builder.issued_by(meta.keypair)
             |> Builder.for_audience("did:key:z6MkwDK3M4PxU1FqcSt4quXghquH1MoWXGzTrNkNWTSy2NLD")
             |> Builder.with_expiration((DateTime.utc_now() |> DateTime.to_unix()) + 86_400)
             |> Builder.with_fact("door", "bronze")
             |> Builder.with_nonce()
             |> Builder.not_before((DateTime.utc_now() |> DateTime.to_unix()) - 86_400)
             |> Builder.build()

    assert is_binary(nnc)
  end

  @tag :build
  test "with capabilities", meta do
    cap = Capability.new("example://bar", "ability/bar", %{"beep" => 1})

    assert {:ok, %UcanPayload{cap: caps}} =
             Builder.default()
             |> Builder.issued_by(meta.keypair)
             |> Builder.for_audience("did:key:z6MkwDK3M4PxU1FqcSt4quXghquH1MoWXGzTrNkNWTSy2NLD")
             |> Builder.with_expiration((DateTime.utc_now() |> DateTime.to_unix()) + 86_400)
             |> Builder.claiming_capability(cap)
             |> Builder.build()

    assert %{"example://bar" => %{"ability/bar" => [%{"beep" => 1}]}} = caps
  end

  @tag :build
  test "with bang variant success", meta do
    cap = Capability.new("example://bar", "ability/bar", %{"beep" => 1})

    assert %UcanPayload{cap: caps} =
             Builder.default()
             |> Builder.issued_by(meta.keypair)
             |> Builder.for_audience("did:key:z6MkwDK3M4PxU1FqcSt4quXghquH1MoWXGzTrNkNWTSy2NLD")
             |> Builder.with_expiration((DateTime.utc_now() |> DateTime.to_unix()) + 86_400)
             |> Builder.claiming_capability(cap)
             |> Builder.build!()

    assert %{"example://bar" => %{"ability/bar" => [%{"beep" => 1}]}} = caps
  end

  @tag :build
  test "with bang variant fail", meta do
    cap = Capability.new("example://bar", "ability/bar", %{"beep" => 1})

    res =
      try do
        Builder.default()
        |> Builder.issued_by(meta.keypair)
        |> Builder.for_audience("did:key:z6MkwDK3M4PxU1FqcSt4quXghquH1MoWXGzTrNkNWTSy2NLD")
        |> Builder.claiming_capability(cap)
        |> Builder.build!()
      rescue
        e in RuntimeError -> e
      end

    assert %RuntimeError{message: _} = res
  end

  @tag :build_witness_ins
  test "with witnessed_by", meta do
    cap = Capability.new("example://bar", "ability/bar", %{"beep" => 1})

    authority_token =
      Builder.default()
      |> Builder.issued_by(meta.keypair)
      |> Builder.for_audience("did:key:z6MkwDK3M4PxU1FqcSt4quXghquH1MoWXGzTrNkNWTSy2NLD")
      |> Builder.with_expiration((DateTime.utc_now() |> DateTime.to_unix()) + 86_400)
      |> Builder.build!()
      |> Ucan.sign(meta.keypair)

    # Valid witnessed by addition
    {:ok, %UcanPayload{prf: proofs}} =
      Builder.default()
      |> Builder.issued_by(meta.keypair)
      |> Builder.for_audience("did:key:z6MkwDK3M4PxU1FqcSt4quXghquH1MoWXGzTrNkNWTSy2NLD")
      |> Builder.with_expiration((DateTime.utc_now() |> DateTime.to_unix()) + 86_400)
      |> Builder.claiming_capability(cap)
      |> Builder.witnessed_by(authority_token)
      |> Builder.build()

    assert length(proofs) == 1

    # Auhotrity token is not a valid Ucan
    res =
      try do
        Builder.default()
        |> Builder.issued_by(meta.keypair)
        |> Builder.for_audience("did:key:z6MkwDK3M4PxU1FqcSt4quXghquH1MoWXGzTrNkNWTSy2NLD")
        |> Builder.with_expiration((DateTime.utc_now() |> DateTime.to_unix()) + 86_400)
        |> Builder.claiming_capability(cap)
        |> Builder.witnessed_by("")
        |> Builder.build()
      rescue
        e -> e
      end

    assert %FunctionClauseError{} = res

    # Invalid cid conversion, due to unspported hash type
    {:ok, %UcanPayload{prf: proofs}} =
      Builder.default()
      |> Builder.issued_by(meta.keypair)
      |> Builder.for_audience("did:key:z6MkwDK3M4PxU1FqcSt4quXghquH1MoWXGzTrNkNWTSy2NLD")
      |> Builder.with_expiration((DateTime.utc_now() |> DateTime.to_unix()) + 86_400)
      |> Builder.claiming_capability(cap)
      |> Builder.witnessed_by(authority_token, :md5)
      |> Builder.build()

    refute length(proofs) == 1
  end

  # Tests from rs-ucan
  @tag :build_rs
  test "it_builds_with_a_simple_example", meta do
    fact_1 = %{
      "test" => true
    }

    fact_2 = %{
      "preimage" => "abc",
      "hash" => "sth"
    }

    cap_1 = Capability.new("mailto:alice@gmail.com", "email/send", [])

    cap_2 = Capability.new("wnfs://alice.fission.name/public", "wnfs/super_user", [])

    expiration = (DateTime.utc_now() |> DateTime.to_unix()) + 30
    not_before = (DateTime.utc_now() |> DateTime.to_unix()) - 30

    token =
      Builder.default()
      |> Builder.issued_by(meta.keypair)
      |> Builder.for_audience(Keymaterial.get_did(meta.bob_keypair))
      |> Builder.with_expiration(expiration)
      |> Builder.not_before(not_before)
      |> Builder.with_fact("abc/challenge", fact_1)
      |> Builder.with_fact("def/challenge", fact_2)
      |> Builder.claiming_capability(cap_1)
      |> Builder.claiming_capability(cap_2)
      |> Builder.with_nonce()
      |> Builder.build!()

    %Ucan{payload: %UcanPayload{} = payload} = _ucan = Ucan.sign(token, meta.keypair)
    assert payload.iss == Keymaterial.get_did(meta.keypair)
    assert payload.aud == Keymaterial.get_did(meta.bob_keypair)
    assert is_integer(payload.exp)
    assert payload.exp == expiration
    assert is_integer(payload.nbf)
    assert payload.nbf == not_before

    assert payload.fct == %{
             "abc/challenge" => fact_1,
             "def/challenge" => fact_2
           }

    assert is_binary(payload.nnc)

    {:ok, expected_attenuations} = Capabilities.sequence_to_map([cap_1, cap_2])
    assert payload.cap == expected_attenuations
  end

  @tag :build_rs
  test "it_builds_with_lifetime_in_seconds", meta do
    token =
      Builder.default()
      |> Builder.issued_by(meta.keypair)
      |> Builder.for_audience(Keymaterial.get_did(meta.bob_keypair))
      |> Builder.with_lifetime(300)
      |> Builder.build!()

    %Ucan{payload: %UcanPayload{} = payload} = _ucan = Ucan.sign(token, meta.keypair)
    assert payload.exp > (DateTime.utc_now() |> DateTime.to_unix()) + 290
  end

  @tag :build_rs
  test "it_prevents_duplicate_proofs", meta do
    parent_cap = Capability.new("wnfs://alice.fission.name/public", "wnfs/super_user", %{})

    ucan =
      Builder.default()
      |> Builder.issued_by(meta.keypair)
      |> Builder.for_audience(Keymaterial.get_did(meta.bob_keypair))
      |> Builder.with_lifetime(30)
      |> Builder.claiming_capability(parent_cap)
      |> Builder.build!()
      |> Ucan.sign(meta.keypair)

    attenuated_cap_1 = Capability.new("wnfs://alice.fission.name/public/Apps", "wnfs/create", %{})

    attenuated_cap_2 =
      Capability.new("wnfs://alice.fission.name/public/Domains", "wnfs/create", %{})

    next_ucan =
      Builder.default()
      |> Builder.issued_by(meta.bob_keypair)
      |> Builder.for_audience(Keymaterial.get_did(meta.mallory_keypair))
      |> Builder.with_lifetime(30)
      |> Builder.witnessed_by(ucan)
      |> Builder.claiming_capability(attenuated_cap_1)
      |> Builder.claiming_capability(attenuated_cap_2)
      |> Builder.build!()
      |> Ucan.sign(meta.keypair)

    assert next_ucan.payload.prf == [Token.to_cid!(ucan, :blake3)]
  end

  @tag :delegate_2
  test "delegating_from", meta do
    cap = Capability.new("example://bar", "ability/bar", Jason.encode!(%{"beep" => 1}))

    authority_token =
      Builder.default()
      |> Builder.issued_by(meta.keypair)
      |> Builder.for_audience("did:key:z6MkwDK3M4PxU1FqcSt4quXghquH1MoWXGzTrNkNWTSy2NLD")
      |> Builder.with_expiration((DateTime.utc_now() |> DateTime.to_unix()) + 86_400)
      |> Builder.claiming_capability(cap)
      |> Builder.build!()
      |> Ucan.sign(meta.keypair)

    delegated_token =
      Builder.default()
      |> Builder.issued_by(meta.keypair)
      |> Builder.for_audience("did:key:z6MkwDK3M4PxU1FqcSt4quXghquH1MoWXGzTrNkNWTSy2NLD")
      |> Builder.with_expiration((DateTime.utc_now() |> DateTime.to_unix()) + 86_400)
      |> Builder.delegating_from(authority_token)
      |> Builder.build!()
      |> Ucan.sign(meta.keypair)

    assert %{"prf:0" => %{"ucan/DELEGATE" => [%{}]}} = Ucan.capabilities(delegated_token)
  end

  test "delegating_from-2", meta do
    cap = Capability.new("example://bar", "ability/bar", Jason.encode!(%{"beep" => 1}))

    authority_token =
      Builder.default()
      |> Builder.issued_by(meta.keypair)
      |> Builder.for_audience("did:key:z6MkwDK3M4PxU1FqcSt4quXghquH1MoWXGzTrNkNWTSy2NLD")
      |> Builder.with_expiration((DateTime.utc_now() |> DateTime.to_unix()) + 86_400)
      |> Builder.claiming_capability(cap)
      |> Builder.build!()
      |> Ucan.sign(meta.keypair)

    _delegated_token =
      Builder.default()
      |> Builder.issued_by(meta.keypair)
      |> Builder.for_audience("did:key:z6MkwDK3M4PxU1FqcSt4quXghquH1MoWXGzTrNkNWTSy2NLD")
      |> Builder.with_expiration((DateTime.utc_now() |> DateTime.to_unix()) + 86_400)
      |> Builder.delegating_from(authority_token)
      |> Builder.build!()
      |> Ucan.sign(meta.keypair)
  end

  test "parse_encoded_ucan" do
    assert {:error, _} =
             Token.parse_encoded_ucan("did:key:z6MkwDK3M4PxU1FqcSt4quXghquH1MoWXGzTrNkNWTSy2NLD")
  end
end
