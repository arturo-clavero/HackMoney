## Contracts
> * /Core/shared/AccessManager     |--> DONE
> * /Core/shared/CollateralManager |--> DONE
> * /Core/shared/AppManager        |--> DONE
> * /Core/shared/Security|--> IN PROGRESS
* /Core/shared/Oracle |--> X
> * /Core/shared/Engine |--> [removed]
> * /Core/HardPeg | --> IN PROGRESS
* /Core/MediumPeg | --> X
* /Core/SoftPeg | --> X
* /mocks/MockOracle |--> X
> * /PrivateCoin | --> DONE
 * /Timelock | --> X

## Architecture

### Creating a "stablecoin instance"
Architecure describing how clients deploy or create their own "stablecoin" 

1. Apps choose template, or custom configuration.

2. Depending on collateral allowed in config, the app "instance" will be managed by a Stablecoin contract with the appropriate peg design:

```Mermaid
flowchart LR

T[Template config]
T-->SC[Stable Collateral]
T-->YC[Stable + Yield Collateral]
T-->MC[Mix Collateral]

SC-->HS[Hard Peg Stablecoin]
YC-->MS[Medium Peg Stablecoin]
MC-->SP[Soft Peg Stablecoin]
```
>This helps us group "apps", by "risk", offering the best peg design possible for each App's requirements.




3. For all stablecoin protocols, the initialization logic is the same. 
```Mermaid
flowchart LR

AC[App config]-->S[Stablecoin Protocol]
S-->|Store| ST[App instance]
S-->|Deploy| E[Private ERC20]
E-->A[App-specific access]
E-->P[App-specific action permissions]
```

In reality apps are not deploying an individual stablecoin. Instead apps are using the protocol's stablecoin with added configurations. Apps are only deploying a private ERC20 with specific app-guarded and user-guarded permissions. This design choice is intentional.

> When risk management is secured by our "singleton" stablecoin protocol, apps don't need to worry about risk, security, oracles, peg design, or peg maintance; they just design specific guard-rails.
>
>Deploying a private ERC-20 for each app, allows: 
>* separate app-specific wallet UX (each app "gets" a different token) 
> * storage distribution of app-specific users (large data) among separate contracts. This avoids storage-explosion in the main protocol, while keeping token interactions cheap and ux-friendly. 
>
>Using optimized storage options (such as merkle trees) in the main protocol for "user lists" are not suitable for our use case. Verifying merkle proofs increase gas-cost per token-operation, and introduce slower UX. Our current designs allows us to priortize cheap and UX-friendly transactions, while constricting storage use to separate contracts.

## StableCoin Protocol
Here we describe the smart contract architecture and inheritance for the main Protocol. There are 3 protocol architectures with different peg-desing.

1. Shared Architecture:
>Set of abstract contracts that define shared-logic for every peg design. These contracts manage everything that isn't directly related to the peg-design and risk management.


```Mermaid
flowchart TD

R[Access]
C[Collateral]

O[Oracle]
S[Security]
A[App]

E[Engine]

R-->C
C-->O
C-->A
R-->S

O-->E
A-->E
S-->E

```


2. Peg Specific Architecture:
>Engine risk functions may be overriden in "Peg" contracts. Additionally each peg module stores "positions" differently. The separation here allows us to customize risk design, position architecture and position management.

```Mermaid
flowchart TD

E[Engine]

E-->H[Hard-Peg]
E-->M[Medium-Peg]
E-->S[Soft-Peg]
```



## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
