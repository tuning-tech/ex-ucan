![ticket](doc_assets/ticket-4.png?raw=true)

# ex-ucan

> Decentralized Auth with [UCANs](https://ucan.xyz/)

**Elixir library to help the next generation of applications make use of UCANs in their authorization flows. To learn more about UCANs and how you might use them in your application, visit [https://ucan.xyz](https://ucan.xyz) or read the [spec](https://github.com/ucan-wg/spec).**

> Ucan version - v0.10.0

**⚠️ WARNING ⚠️: This library is experimental and will likely have many breaking changes in the future!.**

## Table of Contents

1. [About](#about)
2. [Structure](#structure)
3. [Installation](#installation)
4. [Usage](#usage)
    - [Generating UCAN](#generating-ucan)
    - [Validating UCAN](#validating-ucan)
    - [Adding Capabilities](#adding-capabilities)
5. [Roadmap](#roadmap)

## About
UCANs are JWTs that contain special keys pecifically designed to enable ways of authorizing offline-first apps and distributed systems.

At a high level, UCANs (“User Controlled Authorization Network”) are an authorization scheme ("what you can do") where users are fully in control. UCANs use [DID](https://www.w3.org/TR/did-core/#:~:text=Decentralized%20identifiers%20(DIDs)%20are%20a,the%20controller%20of%20the%20DID.)s ("Decentralized Identifiers") to identify users and services ("who you are").

No all-powerful authorization server or server of any kind is required for UCANs. Instead, everything a user can do is captured directly in a key or token, which can be sent to anyone who knows how to interpret the UCAN format. Because UCANs are self-contained, they are easy to consume permissionlessly, and they work well offline and in distributed systems.

UCANs work,

Server → Server

Client → Server

Peer-to-peer

**OAuth is designed for a centralized world, UCAN is the distributed user-controlled version.**

## Structure

### Header

 `alg`, Algorithm, the type of signature.

 `typ`, Type, the type of this data structure, JWT.

### Payload

 `ucv`, UCAN version.

 `cap`, A list of resources and capabilities that the ucan grants.

 `aud`, Audience, the DID of who it's intended for.

 `exp`, Expiry, unix timestamp of when the jwt is no longer valid.

 `fct`, Facts, an array of extra facts or information to attach to the jwt.

 `nnc`, Nonce value to increase the uniqueness of UCAN token.

 `iss`, Issuer, the DID of who sent this.

 `nbf`, Not Before, unix timestamp of when the jwt becomes valid.

 `prf`, Proof, an optional nested token with equal or greater privileges.

 ### Signature

 A signature (using `alg`) of the base64 encoded header and payload concatenated together and delimited by `.`

## Installation

```elixir
def deps do
  [
    {:ucan, git: "https://github.com/spawnfest/youcan.git"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm).

## Usage

### Generating UCAN

- Create a Keypair

- Use Ucan builder to build the payload

- Sign the payload with the keypair

- encode it to JWT format

```elixir
iex> alias Ucan.Builder

# receiver DID
iex> audience_did = "did:key:z6MkwDK3M4PxU1FqcSt4quXghquH1MoWXGzTrNkNWTSy2NLD"

# Step 1: Create keypair
# default keypair generation uses EdDSA algorithm
iex> keypair = Ucan.create_default_keypair()

%Ucan.Keymaterial.Ed25519.Keypair{
  jwt_alg: "EdDSA",
  secret_key: <<119, 230, 103, 205, 6, 104, 32, 67, 206, 178, 128, 75, 16,
    177, 64, 44, 45, 238, 145, 226, 192, 163, 70, 36, 198, 1, 73, 61, 193,
    159, 100, 139>>,
  public_key: <<253, 108, 63, 29, 71, 28, 139, 34, 170, 97, 117, 25, 179,
    124, 224, 206, 131, 150, 60, 212, 216, 168, 24, 85, 139, 119, 232, 14,
    64, 143, 2, 191>>
}
####################################################################

# Step 2: Use Ucan builder to build the payload
iex> ucan_payload =
         Builder.default()
         |> Builder.issued_by(keypair)
         |> Builder.for_audience(audience_did)
         |> Builder.with_lifetime(86_400)
         |> Builder.build!()

%Ucan.UcanPayload{
  ucv: "0.10.0",
  iss: "did:key:z6MkmuTr3fgtBeTVmDtZZGmuHNrLwEA6b9KX4Shw1nyLioEy",
  aud: "did:key:z6MkwDK3M4PxU1FqcSt4quXghquH1MoWXGzTrNkNWTSy2NLD",
  nbf: nil,
  exp: 1698705462,
  nnc: nil,
  fct: %{},
  cap: [],
  prf: []
}
#######################################################################

# Step 3: Sign the payload with the keypair (generated in step 1)
iex> ucan = Ucan.sign(ucan_payload, keypair)

%Ucan{
  header: %Ucan.UcanHeader{
    alg: "EdDSA",
    typ: "JWT"
  },
  payload: %Ucan.UcanPayload{
    ucv: "0.10.0",
    iss: "did:key:z6MkmuTr3fgtBeTVmDtZZGmuHNrLwEA6b9KX4Shw1nyLioEy",
    aud: "did:key:z6MkwDK3M4PxU1FqcSt4quXghquH1MoWXGzTrNkNWTSy2NLD",
    nbf: nil,
    exp: 1698705462,
    nnc: nil,
    fct: %{},
    cap: [],
    prf: []
  },
  signed_data: "eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCJ9.eyJleHAiOjE2OTg3MDU0NjIsInVjdiI6IjAuMTAuMCIsImlzcyI6ImRpZDprZXk6ejZNa211VHIzZmd0QmVUVm1EdFpaR211SE5yTHdFQTZiOUtYNFNodzFueUxpb0V5IiwiYXVkIjoiZGlkOmtleTp6Nk1rd0RLM000UHhVMUZxY1N0NHF1WGdocXVIMU1vV1hHelRyTmtOV1RTeTJOTEQiLCJuYmYiOm51bGwsIm5uYyI6bnVsbCwiZmN0Ijp7fSwiY2FwIjpbXSwicHJmIjpbXX0",
  signature: "aUwyis34wQBiPhDqaFjuRwUfSHhl1ZRJLwBlyqP2dKCY1syweuSPp1CY4zgMOE-iUFr8mug7CKqxuUKk8yzkBA"
}
#############################################################################

# Step 4: encode it to JWT format
iex> Ucan.encode(ucan)
"eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCJ9.eyJleHAiOjE2OTg3MDU0NjIsInVjdiI6IjAuMTAuMCIsImlzcyI6ImRpZDprZXk6ejZNa211VHIzZmd0QmVUVm1EdFpaR211SE5yTHdFQTZiOUtYNFNodzFueUxpb0V5IiwiYXVkIjoiZGlkOmtleTp6Nk1rd0RLM000UHhVMUZxY1N0NHF1WGdocXVIMU1vV1hHelRyTmtOV1RTeTJOTEQiLCJuYmYiOm51bGwsIm5uYyI6bnVsbCwiZmN0Ijp7fSwiY2FwIjpbXSwicHJmIjpbXX0.aUwyis34wQBiPhDqaFjuRwUfSHhl1ZRJLwBlyqP2dKCY1syweuSPp1CY4zgMOE-iUFr8mug7CKqxuUKk8yzkBA"  
```

### Validating UCAN

UCANs can be validated using

```
Ucan.validate_token(token)
```

### Adding Capabilities

`capabilities` are a list of `resources`, and the `abilities` that we can make on the `resource` with some optional `caveats`.


```elixir
cap = Ucan.Core.Capability.new("example://bar", "ability/bar", %{"beep" => 1})

# where resource - example://bar", ability - "ability/bar" and caveat - %{"beep" => 1}
# This should be the only capability the receiver or `aud` of UCAN can do. We can add this capability in the ucan builder flow as

iex> ucan_payload =
         Builder.default()
         |> Builder.issued_by(keypair)
         |> Builder.for_audience(audience_did)
         |> Builder.with_lifetime(86_400)
         |> Builder.claiming_capability(cap)
         |> Builder.build!()

%Ucan.UcanPayload{
  ucv: "0.10.0",
  iss: "did:key:z6MkmuTr3fgtBeTVmDtZZGmuHNrLwEA6b9KX4Shw1nyLioEy",
  aud: "did:key:z6MkwDK3M4PxU1FqcSt4quXghquH1MoWXGzTrNkNWTSy2NLD",
  nbf: nil,
  exp: 1698706505,
  nnc: nil,
  fct: %{},
  cap: [
    %Ucan.Core.Capability{
      resource: "example://bar",
      ability: "ability/bar",
      caveat: %{"beep" => 1}
    }
  ],
  prf: []
}
```

## Roadmap

The library is no-where feature parity with ucan [rust](https://github.com/ucan-wg/rs-ucan/tree/main) library or with the spec. The spec itself is nearing a 1.0.0, and is under-review.
But good thing is we have now laid the basic foundations. The next immediate additions would be,

- [X] Proof encodings as CID (Content Addressable Data)
- [ ] Capability Semantics
- [ ] `delegating_from` in builder 
- [ ] Verifying UCAN invocations


## Acknowledgement

- This library has taken reference from both [ts-ucan](https://github.com/ucan-wg/ts-ucan) and rs-ucan.

- Ucan logo - <a href="https://www.flaticon.com/free-icons/validating-ticket" title="validating ticket icons">Validating ticket icons created by Good Ware - Flaticon</a>

