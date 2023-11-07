defmodule CapabilityTest do
  alias Ucan.Core.Capabilities
  alias Ucan.Core.Capability
  use ExUnit.Case

  @tag :caps
  test "can_cast_between_map_and_sequence" do
    cap_foo = Capability.new("example//foo", "ability/foo", [%{}])
    assert cap_foo.caveats == [%{}]
    cap_bar = Capability.new("example://bar", "ability/bar", [%{"beep" => 1}])

    cap_sequence = [cap_foo, cap_bar]

    cap_maps = Capabilities.sequence_to_map(cap_sequence)
    assert Capabilities.map_to_sequence(cap_maps) == cap_sequence

    # {:ok, caps} = Capabilities.from(%{
    #   "example://bar" => %{
    #     "ability/bar" => [%{}],
    #     "ability/foo" => [%{}]
    #   }
    # })

    # Capabilities.map_to_sequence(caps)
  end

  @tag :caps
  test "it_rejects_non_compliant_json" do
    failure_cases = [
      {Jason.encode!([]), "Capabilities must be a map"},
      {Jason.encode!(%{
         "resource:foo" => []
       }), "Abilities must be map"},
      {Jason.encode!(%{
         "resource:foo" => %{}
       }), "resource must have at least one ability"},
      {Jason.encode!(%{
         "resource:foo" => %{"ability/read" => %{}}
       }), "caveats must be array"},
      {Jason.encode!(%{
         "resource:foo" => %{
           "ability/read" => [1]
         }
       }), "caveat must be object"}
    ]

    for {json_val, _msg} <- failure_cases do
      assert {:error, _} = Capabilities.from(json_val)
    end

    assert {:ok, _} =
             Capabilities.from(
               Jason.encode!(%{
                 "resource:foo" => %{"ability/read" => [%{}]}
               })
             )
  end

  @tag :caps
  test "it_rejects_non_compliant_maps" do
    failure_cases = [
      {[], "Capabilities must be a map"},
      {%{
         "resource:foo" => []
       }, "Abilities must be map"},
      {%{
         "resource:foo" => %{}
       }, "resource must have at least one ability"},
      {%{
         "resource:foo" => %{"ability/read" => %{}}
       }, "caveats must be array"},
      {%{
         "resource:foo" => %{
           "ability/read" => [1]
         }
       }, "caveat must be object"}
    ]

    for {json_val, _msg} <- failure_cases do
      assert {:error, _} = Capabilities.from(json_val)
    end

    assert {:ok, _} =
             Capabilities.from(%{
               "resource:foo" => %{"ability/read" => [%{}]}
             })
  end

  @tag :caps
  test "it_filters_out_empty_caveats_while_creating_map_to_sequence" do
    assert {:ok, capabilities} = Capabilities.from(%{
      "example://bar" => %{"ability/bar" => [%{}]},
      "example://foo" => %{"ability/foo" => []}
    })

    cap_seq = Capabilities.map_to_sequence(capabilities)
    assert length(cap_seq) == 1
  end
end
