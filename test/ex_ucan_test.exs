defmodule UcanTest do
  alias Ucan.Builder
  alias Ucan.DidParser
  alias Ucan.Keymaterial
  alias Ucan.Keymaterial.Ed25519
  use ExUnit.Case
  doctest Ucan
  doctest Ucan.Utils

  setup do
    keymaterial = Ucan.create_default_keymaterial()
    did_parser = DidParser.new([{Keymaterial.get_magic_bytes(keymaterial), keymaterial}])
    %{keymaterial: keymaterial, did_parser: did_parser}
  end

  test "create_default_keymaterial" do
    assert %Ed25519{jwt_alg: "EdDSA"} = keymaterial = Ucan.create_default_keymaterial()
    assert is_binary(keymaterial.public_key)
    assert is_binary(keymaterial.secret_key)
  end

  @tag :Ucan
  test "validate, success", meta do
    token =
      Builder.default()
      |> Builder.issued_by(meta.keymaterial)
      |> Builder.for_audience("did:key:z6MkwDK3M4PxU1FqcSt4quXghquH1MoWXGzTrNkNWTSy2NLD")
      |> Builder.with_expiration((DateTime.utc_now() |> DateTime.to_unix()) + 86_400)
      |> Builder.build!()
      |> Ucan.sign(meta.keymaterial)
      |> Ucan.encode()

    assert :ok = Ucan.validate(token, meta.did_parser)
  end

  @tag :Ucan
  test "invalid token, due to expiry", meta do
    token =
      Builder.default()
      |> Builder.issued_by(meta.keymaterial)
      |> Builder.for_audience("did:key:z6MkwDK3M4PxU1FqcSt4quXghquH1MoWXGzTrNkNWTSy2NLD")
      |> Builder.with_expiration((DateTime.utc_now() |> DateTime.to_unix()) - 5)
      |> Builder.build!()
      |> Ucan.sign(meta.keymaterial)
      |> Ucan.encode()

    assert {:error, "Ucan token is already expired"} = Ucan.validate(token, meta.did_parser)
  end

  @tag :Ucan
  test "invalid token, too early", meta do
    token =
      Builder.default()
      |> Builder.issued_by(meta.keymaterial)
      |> Builder.for_audience("did:key:z6MkwDK3M4PxU1FqcSt4quXghquH1MoWXGzTrNkNWTSy2NLD")
      |> Builder.with_expiration((DateTime.utc_now() |> DateTime.to_unix()) + 86_400)
      |> Builder.not_before((DateTime.utc_now() |> DateTime.to_unix()) + div(86_400, 2))
      |> Builder.build!()
      |> Ucan.sign(meta.keymaterial)
      |> Ucan.encode()

    assert {:error, "Ucan token is not yet active"} = Ucan.validate(token, meta.did_parser)
  end

  test "default did parser" do
    assert %DidParser{} = Ucan.create_default_did_parser()
  end

  @tag :Ucan
  test "from_jwt_token", meta do
    token =
      Builder.default()
      |> Builder.issued_by(meta.keymaterial)
      |> Builder.for_audience("did:key:z6MkwDK3M4PxU1FqcSt4quXghquH1MoWXGzTrNkNWTSy2NLD")
      |> Builder.with_expiration((DateTime.utc_now() |> DateTime.to_unix()) + 86_400)
      |> Builder.build!()
      |> Ucan.sign(meta.keymaterial)
      |> Ucan.encode()

    assert {:ok, _} = Ucan.from_jwt_token(token)
  end
end
