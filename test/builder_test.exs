defmodule BuilderTest do
  alias Ucan.Builder
  alias Ucan.Core.Capability
  alias Ucan.Core.Structs.UcanPayload
  use ExUnit.Case

  setup do
    keypair = Ucan.create_default_keypair()
    %{keypair: keypair}
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

    assert [%{resource: "example://bar", ability: "ability/bar"} | _] = caps
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

    assert [%{resource: "example://bar", ability: "ability/bar"} | _] = caps
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
end
