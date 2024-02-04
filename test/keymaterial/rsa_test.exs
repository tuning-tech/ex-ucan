defmodule Keymaterial.RsaTest do
  @moduledoc """
  Tests for RSA keymaterial implementation
  """

  use ExUnit.Case
  alias Ucan.Keymaterial
  alias Ucan.Keymaterial.Rsa

  @tag :rsa
  test "creating RSA keymaterial, 2048 bit size" do
    rsa = %Rsa{} = Rsa.create()
    assert "RS256" = Keymaterial.get_jwt_algorithm_name(rsa)
    assert "did:key:z4MX" <> _ = Keymaterial.get_did(rsa)
    payload_signature = Keymaterial.sign(rsa, "hello world")
    assert Keymaterial.verify(rsa, rsa.public_key, "hello world", payload_signature)
  end

  @tag :rsa
  test "creating RSA keymaterial, 4096 bit size" do
    rsa = %Rsa{} = Rsa.create(4096)
    assert "RS256" = Keymaterial.get_jwt_algorithm_name(rsa)
    assert "did:key:zgg" <> _ = Keymaterial.get_did(rsa)
    payload_signature = Keymaterial.sign(rsa, "hello world")
    assert Keymaterial.verify(rsa, rsa.public_key, "hello world", payload_signature)
  end
end
