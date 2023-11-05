defmodule Keymaterial.CryptoTest do
  alias Ucan.Keymaterial.Ed25519.Crypto
  alias Ucan.Keymaterial.Ed25519.Keypair
  use ExUnit.Case

  describe "did_to_publickey/1" do
    @tag :crypto
    test "generating public key success" do
      did = "did:key:z6MkwDK3M4PxU1FqcSt4quXghquH1MoWXGzTrNkNWTSy2NLD"
      assert {:ok, _} = Crypto.did_to_publickey(did)
    end

    @tag :crypto
    test "wrong did format" do
      wrong_did = "did:key:6MkwDK3M4PxU1FqcSt4quXghquH1MoWXGzTrNkNWTSy2NLD"

      assert {:error, "Please use a base58-encoded DID formatted `did:key:z..."} =
               Crypto.did_to_publickey(wrong_did)
    end

    @tag :crypto
    test "Wrong multicodec prefix" do
      # did:key with RSA, https://w3c-ccg.github.io/did-method-key/#rsa
      wrong_prefix_did =
        "did:key:z4MXj1wBzi9jUstyPMS4jQqB6KdJaiatPkAtVtGc6bQEQEEsKTic4G7Rou3iBf9vPmT5dbkm9qsZsuVNjq8HCuW1w24nhBFGkRE4cd2Uf2tfrB3N7h4mnyPp1BF3ZttHTYv3DLUPi1zMdkULiow3M1GfXkoC6DoxDUm1jmN6GBj22SjVsr6dxezRVQc7aj9TxE7JLbMH1wh5X3kA58H3DFW8rnYMakFGbca5CB2Jf6CnGQZmL7o5uJAdTwXfy2iiiyPxXEGerMhHwhjTA1mKYobyk2CpeEcmvynADfNZ5MBvcCS7m3XkFCMNUYBS9NQ3fze6vMSUPsNa6GVYmKx2x6JrdEjCk3qRMMmyjnjCMfR4pXbRMZa3i"

      assert {:error, "Expected prefix <<237, 1>>"} = Crypto.did_to_publickey(wrong_prefix_did)
    end
  end

  test "publickey_to_did/1" do
    keypair = Keypair.create()
    assert "did:key:z" <> _ = Crypto.publickey_to_did(keypair.public_key)
  end
end
