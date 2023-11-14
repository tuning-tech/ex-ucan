defmodule CapabilityTest do
  alias Ucan.Capabilities
  alias Ucan.Capability
  alias Ucan.Capability.Caveats
  use ExUnit.Case

  @tag :caps_2
  test "can_cast_between_map_and_sequence" do
    cap_foo = Capability.new("example//foo", "ability/foo", [%{}])
    assert cap_foo.caveats == [%{}]
    cap_bar = Capability.new("example://bar", "ability/bar", [%{"beep" => 1}])

    cap_sequence = [cap_foo, cap_bar]

    {:ok, cap_maps} = Capabilities.sequence_to_map(cap_sequence)
    assert Capabilities.map_to_sequence(cap_maps) == cap_sequence
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
    assert {:ok, capabilities} =
             Capabilities.from(%{
               "example://bar" => %{"ability/bar" => [%{}]},
               "example://foo" => %{"ability/foo" => []}
             })

    cap_seq = Capabilities.map_to_sequence(capabilities)
    assert length(cap_seq) == 1
  end

  @tag :caps
  test "map_to_sequence with multiple abilities for a resource" do
    assert {:ok, capabilities} =
             Capabilities.from(%{
               "example://bar" => %{"ability/bar" => [%{}], "ability/foo" => [%{}]}
             })

    assert [_ | _] = Capabilities.map_to_sequence(capabilities)
  end

  @tag :caps_3
  test "sequence_to_map with multiple abilities for a resource" do
    cap_1 = Capability.new("example://bar", "ability/bar", %{})
    cap_2 = Capability.new("example://bar", "ability/foo", %{})

    assert {:ok, %{"example://bar" => %{"ability/bar" => [%{}], "ability/foo" => [%{}]}}} =
             Capabilities.sequence_to_map([cap_1, cap_2])
  end

  @tag :caps
  test "sequence_to_map with multiple abilities, preventing duplicate abilities" do
    cap_1 = Capability.new("example://bar", "ability/bar", %{})
    cap_2 = Capability.new("example://bar", "ability/bar", %{})

    assert {:ok, %{"example://bar" => %{"ability/bar" => [%{}]}}} =
             Capabilities.sequence_to_map([cap_1, cap_2])
  end

  @tag :caveat
  test "caveats enables?" do
    cases = [
      {{1, 2}, "Caveats must be map", :fail},
      {{%{}, 2}, "Caveats must be map", :fail},
      {{%{a: "b"}, %{}}, "Second caveat can't be empty", :fail},
      {{%{a: :b}, %{c: :d}}, "Second Caveat doesnt have a key `:a`", :fail},
      {{%{a: :b}, %{a: :d}}, "Second Caveat doesnt have same value for key `:a`", :fail},
      {{%{}, %{a: :b}}, "First caveat can be empty", :success},
      {{%{a: :b}, %{a: :b}}, "Both caveats are same", :success},
      {{%{a: :b}, %{a: :b, c: :d}}, "First caveat is a subset of second", :success}
    ]

    for {{caveat_a, caveat_b}, _err_msg, pass} <- cases do
      if pass == :fail do
        refute Caveats.enables?(caveat_a, caveat_b)
      else
        assert Caveats.enables?(caveat_a, caveat_b)
      end
    end
  end

  @tag :caveat
  test "caveats from/1" do
    cases = [
      {1, "Caveat is not JSON string", :fail},
      {"{-", "Not a valid JSON", :fail},
      {"1", "Caveat must be a map", :fail},
      {Jason.encode!(%{a: :b}), "Caveat is a map", :success}
    ]

    for {caveat, err_msg, pass} <- cases do
      if pass == :fail do
        assert {:error, err_msg} == Caveats.from(caveat)
      else
        assert {:ok, _} = Caveats.from(caveat)
      end
    end
  end
end
