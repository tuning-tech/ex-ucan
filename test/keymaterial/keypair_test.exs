defmodule Keymaterial.KeypairTest do
  alias Ucan.DidParser
  alias Ucan.Keymaterial.Ed25519
  alias Ucan.Keymaterial
  use ExUnit.Case

  @tag :edd
  test "creating edDSA keypair" do
    ed_keymaterial = Ucan.create_default_keymaterial()
    assert %Ed25519{jwt_alg: "EdDSA"} = ed_keymaterial
    assert is_binary(ed_keymaterial.public_key)
    assert is_binary(ed_keymaterial.secret_key)
  end

  @tag :edd_2
  test "testing success keymaterial implementation" do
    did_parser = DidParser.new(DidParser.get_default_constructors())
    ed_keymaterial = Ucan.create_default_keymaterial()

    assert %Ed25519{jwt_alg: "EdDSA"} = ed_keymaterial
    assert Keymaterial.get_jwt_algorithm_name(ed_keymaterial) == "EdDSA"
    assert "did:key:z" <> _ = Keymaterial.get_did(ed_keymaterial)
    signature = Keymaterial.sign(ed_keymaterial, "Hello world")
    assert is_binary(signature)

    assert {:ok, pub_key, keymaterial} =
             DidParser.parse(did_parser, Keymaterial.get_did(ed_keymaterial))

    assert Keymaterial.verify(keymaterial, pub_key, "Hello world", signature)
  end

  @tag :edd
  test "testing failed cases, keymaterial implementations" do
    did_parser = DidParser.new(DidParser.get_default_constructors())
    ed_keymaterial = Ucan.create_default_keymaterial()

    assert %Ed25519{jwt_alg: "EdDSA"} = ed_keymaterial
    assert Keymaterial.get_jwt_algorithm_name(ed_keymaterial) == "EdDSA"
    assert "did:key:z" <> _ = Keymaterial.get_did(ed_keymaterial)
    signature = Keymaterial.sign(ed_keymaterial, "Hello world")
    assert is_binary(signature)

    assert {:ok, pub_key, keymaterial} =
             DidParser.parse(did_parser, Keymaterial.get_did(ed_keymaterial))

    refute Keymaterial.verify(keymaterial, pub_key, "Hell world", signature)
  end
end
