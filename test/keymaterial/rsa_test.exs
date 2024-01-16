defmodule Keymaterial.RsaTest do
  @moduledoc """
  Tests for RSA keymaterial implementation
  """

  use ExUnit.Case
  alias Ucan.Keymaterial
  alias Ucan.Keymaterial.Rsa

  setup do
    %Rsa{} = rsa = Rsa.create()
    {:ok, rsa_mod: rsa}
  end

  @tag :rsa
  test "get_jwt_algorithm_name/1", data do
    assert "RS256" = Keymaterial.get_jwt_algorithm_name(data.rsa_mod)
  end

  @tag :skip
  test "get_did/1", data do
    assert "" = Keymaterial.get_did(data.rsa_mod)
  end
end
