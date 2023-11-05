defmodule Keymaterial.KeypairTest do
  alias Ucan.Keymaterial
  alias Ucan.Keymaterial.Ed25519.Keypair
  use ExUnit.Case

  test "creating edDSA keypair" do
    assert %Keypair{jwt_alg: "EdDSA"} = keypair = Keypair.create()
    assert is_binary(keypair.public_key)
    assert is_binary(keypair.secret_key)
  end

  test "testing success keymaterial implementation" do
    assert %Keypair{jwt_alg: "EdDSA"} = keypair = Keypair.create()
    assert Keymaterial.get_jwt_algorithm_name(keypair) == "EdDSA"
    assert "did:key:z" <> _ = Keymaterial.get_did(keypair)
    signature = Keymaterial.sign(keypair, "Hello world")
    assert is_binary(signature)
    assert Keymaterial.verify(keypair, "Hello world", signature)
  end

  test "testing failed cases, keymaterial implementations" do
    assert %Keypair{jwt_alg: "EdDSA"} = keypair = Keypair.create()
    assert Keymaterial.get_jwt_algorithm_name(keypair) == "EdDSA"
    assert "did:key:z" <> _ = Keymaterial.get_did(keypair)
    signature = Keymaterial.sign(keypair, "Hello world")
    assert is_binary(signature)
    refute Keymaterial.verify(keypair, "Hell world", signature)
  end
end
