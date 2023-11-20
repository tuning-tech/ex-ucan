defmodule SemanticsTest do
  @moduledoc """
  Tests for semantics.ex
  """
  alias Ucan.Capability.Scope
  alias Ucan.ProofSelection
  alias Ucan.ProofAction
  alias Ucan.Capability
  alias Ucan.ProofDelegationSemantics
  use ExUnit.Case

  @tag :semantics
  test "proof_delegation_semantics" do
    cap_foo = Capability.new("example://foo", "ability/foo", [%{}])
    semantics = ProofDelegationSemantics.new()
    Capability.Semantics.parse_scope(semantics, URI.parse("prf:3"))
  end
end
