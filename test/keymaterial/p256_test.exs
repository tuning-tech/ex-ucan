defmodule Keymaterial.P256Test do
  @moduledoc """
  Tests for P256 keymaterial implementation
  """
alias Ucan.Keymaterial
alias Ucan.Keymaterial.P256

  use ExUnit.Case

  @tag :p
  test "creating P256 keymaterial" do
    p = %P256{}  = P256.create()
    assert "ES256" = Keymaterial.get_jwt_algorithm_name(p)
    assert "did:key:zDn" <> _ = Keymaterial.get_did(p)
  end
end
