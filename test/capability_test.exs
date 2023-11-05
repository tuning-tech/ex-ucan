defmodule CapabilityTest do
  alias Ucan.Core.Capabilities
  alias Ucan.Core.Capability
  use ExUnit.Case

  @tag :caps
  test "can_cast_between_map_and_sequence" do
    cap_foo = Capability.new("example//foo", "ability/foo", %{})
    assert cap_foo.caveat == %{}
    cap_bar = Capability.new("example://bar", "ability/bar", %{"beep" => 1})

    cap_sequence = [cap_foo, cap_bar]

    cap_maps = Capabilities.sequence_to_map(cap_sequence)
    assert Capabilities.map_to_sequence(cap_maps) == cap_sequence
  end
end
