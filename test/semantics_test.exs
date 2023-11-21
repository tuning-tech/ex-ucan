defmodule SemanticsTest do
  @moduledoc """
  Tests for semantics.ex
  """
  alias Ucan.Capability.ResourceUri.Scoped
  alias Ucan.Capability.ResourceUri
  alias Ucan.ProofSelection.Index
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

    assert %ProofSelection{type: %Index{value: 3}} =
             Capability.Semantics.parse_scope(semantics, URI.parse("prf:3"))

    assert nil ==
             Capability.Semantics.parse_action(semantics, "ability/foo")

    assert %ProofAction{type: :delegate} =
             Capability.Semantics.parse_action(semantics, "ucan/DELEGATE")

    assert {"did:key", _} =
             Capability.Semantics.extract_did(
               semantics,
               "did:key:z6MkwDK3M4PxU1FqcSt4quXghquH1MoWXGzTrNkNWTSy2NLD"
             )

    assert nil ==
             Capability.Semantics.extract_did(
               semantics,
               "did:jumbo:z6MkwDK3M4PxU1FqcSt4quXghquH1MoWXGzTrNkNWTSy2NLD"
             )

    assert nil ==
             Capability.Semantics.parse_resource(semantics, URI.parse("example://foo"))

    assert %ResourceUri{type: :unscoped} =
             Capability.Semantics.parse_resource(semantics, URI.parse("prf:*"))

    assert %ResourceUri{type: %Scoped{scope: %ProofSelection{type: %Index{value: 4}}}} =
             Capability.Semantics.parse_resource(semantics, URI.parse("prf:4"))
  end
end
