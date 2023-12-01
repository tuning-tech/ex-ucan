defmodule AttenuationTest do
  use ExUnit.Case

  setup do
    keypair = Ucan.create_default_keypair()
    bob_keypair = Ucan.create_default_keypair()
    mallory_keypair = Ucan.create_default_keypair()

    %{keypair: keypair, bob_keypair: bob_keypair, mallory_keypair: mallory_keypair}
  end
end
