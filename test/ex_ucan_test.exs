defmodule UcanTest do
  alias Ucan.Builder
  alias Ucan.Core.Utils
  alias Ucan.Keymaterial.Ed25519.Keypair
  use ExUnit.Case
  doctest Ucan
  doctest Utils

  setup do
    keypair = Ucan.create_default_keypair()
    %{keypair: keypair}
  end

  test "create_default_keypair" do
    assert %Keypair{jwt_alg: "EdDSA"} = keypair = Keypair.create()
    assert is_binary(keypair.public_key)
    assert is_binary(keypair.secret_key)
  end

  @tag :Ucan
  test "validate_token, success", meta do
    token =
      Builder.default()
      |> Builder.issued_by(meta.keypair)
      |> Builder.for_audience("did:key:z6MkwDK3M4PxU1FqcSt4quXghquH1MoWXGzTrNkNWTSy2NLD")
      |> Builder.with_expiration((DateTime.utc_now() |> DateTime.to_unix()) + 86_400)
      |> Builder.build!()
      |> Ucan.sign(meta.keypair)
      |> Ucan.encode()

    assert :ok = Ucan.validate_token(token)
  end

  @tag :Ucan
  test "invalid token, due to expiry", meta do
    token =
      Builder.default()
      |> Builder.issued_by(meta.keypair)
      |> Builder.for_audience("did:key:z6MkwDK3M4PxU1FqcSt4quXghquH1MoWXGzTrNkNWTSy2NLD")
      |> Builder.with_expiration((DateTime.utc_now() |> DateTime.to_unix()) - 5)
      |> Builder.build!()
      |> Ucan.sign(meta.keypair)
      |> Ucan.encode()

    assert {:error, "Ucan token is already expired"} = Ucan.validate_token(token)
  end

  @tag :Ucan
  test "invalid token, too early", meta do
    token =
      Builder.default()
      |> Builder.issued_by(meta.keypair)
      |> Builder.for_audience("did:key:z6MkwDK3M4PxU1FqcSt4quXghquH1MoWXGzTrNkNWTSy2NLD")
      |> Builder.with_expiration((DateTime.utc_now() |> DateTime.to_unix()) + 86_400)
      |> Builder.not_before((DateTime.utc_now() |> DateTime.to_unix()) + div(86_400, 2))
      |> Builder.build!()
      |> Ucan.sign(meta.keypair)
      |> Ucan.encode()

    assert {:error, "Ucan token is not yet active"} = Ucan.validate_token(token)
  end
end
