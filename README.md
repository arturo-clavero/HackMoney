# Usage of External Functions
Explaining how to  :
- Add a global collateral token (~dev)
- Deploy a new stablecoin token (~apps)
- Interact with stablecoin token (~apps)
- Modify stablecoin token configs (~apps)
- Modify protocol configs (~dev)

---

## Add a Global Collateral Token

We need to register tokens with specific configurations. Apps can then choose collateral from this set of tokens during initial deployment. This is done by us, and is not necessiraly part of the user flow.

### Solidity Function

```solidity
function updateGlobalCollateral(CollateralInput calldata updatedCol) external;
```

### Input Struct

```solidity
struct CollateralInput {
    address   tokenAddress;
    uint256   mode;
    address[] oracleFeeds;
    uint256   LTV;
    uint256   liquidityThreshold;  
    uint256   debtCap;     
}
```

### Parameters

* **tokenAddress**: on-chain address of the token (deploy mock or real).
* **mode**: defines the type of collateral. Use bitmask constants. (See implementation below)

* **oracleFeeds**: array of price feed addresses.
* **LTV**: Loan-to-value ratio (0–100).
* **liquidityThreshold**: number (0–100) controlling collateral liquidity requirement.
* **debtCap**: maximum debt allowed for this collateral (big number).

### Implementing modes
Constant bit flags per mode

```javascript
const MODE_STABLE   = 1 << 0;  
const MODE_VOLATILE = 1 << 1;  
const MODE_YIELD    = 1 << 2;  
```
How to set a mode for each collateral type : 
1. stable collateral (~USDC) :
```javascript
const stableMode = 0 | MODE_STABLE; 
```
2. stable yield collateral (~USYC) :
```javascript
const stableYieldMode =  0 | MODE_STABLE | MODE_YIELD;
```
3. volatile yield collateral (~sETH) :
```javascript
const volatileYieldMode = 0 | MODE_VOLATILE | MODE_YIELD;
```
1. volatile collateral (~ETH) :
```javascript
const volatileMode = 0 | MODE_VOLATILE;
```


## Deploy a "new" stablecoin

Apps can register a new stablecoin token with specific configurations. After they input their "rules", our contract will register them and deploy an ERC-20 token just for them. This ERC-20 allows meta-tx actions because its erc-20permit. 

### Solidity Function

```solidity
    function newInstance(AppInput calldata config) external returns (uint256 id)  {}
```

### Input Struct

```solidity
struct AppInput {
    string name;
    string symbol;
    uint256 appActions;
    uint256 userActions;
    address[] users;
    address[] tokens;
}
```

### Parameters
* **name**: ERC-20 Name
* **symbol**: ERC-20 Symbol
* **app actions**: defines the type of actions the app can perform. Use bitmask constants. (See implementation below)
* **user actions**: defines the type of actions the users can perform. Use bitmask constants. (See implementation below)
* **users**: Add a list of user addreses that will interact with the app's token
* **tokens**: Add a list of token addreses that will be used as collateral. Maximum 5. They must be chosen from the previous "global collateral" set. 

### Implementing actions
Description of each action :
Mint : Who is allowed to mint the stablecoin ?
Hold : Who is allowed to hold the stablecoin ?
Transfer Dest : Who is allowed to receive transfers ?

Constant bit flags per action

```javascript
const MINT   = 1 << 0;  
const HOLD = 1 << 1;  
const TRANSFER_DEST    = 1 << 2;  
```

How to set an action type: 
```javascript
const canOnlyMint = 0 | MINT;
const canOnlyHold = 0 | HOLD;
const canReceiveTransfers = 0 | HOLD | TRANSFER_DEST;
const canMintAndHold = 0 | MINT | HOLD;
const canMintandReceiveTransfers = 0 | MINT | HOLD | TRANSFER_DEST;
```

With these constants we can define the behavior for the app and users. It is necessary that at least one group can mint, and at least one can hold tokens. Otherwise the token is unusable.

### Return Value & Events

* The function returns the **App ID** (`uint256`).
* This **App ID** is required for all future interactions with the app-specific stablecoin instance.

After a successful registration, the contract emits the following event:

```solidity
event RegisteredApp(
    address indexed owner,
    uint256 indexed id,
    address coin
);
```


#### Important values to record from this event

* **id**
  The unique identifier of the app.
  This value must be used when interacting with the stablecoin logic (minting, redeeming, etc.).

* **coin**
  The address of the app-specific ERC-20 token.
  This address should be added to MetaMask (or any wallet) in order to:

  * Display balances
  * Track transfers
  * Visualize user interactions with the stablecoin



# How To Deploy
Example HardPeg contract already deployed on sepolia at address 0x3fe8A3760C2794A05e7e8EFBF41Ec831A0eb74F9.
>Etherscan link to contract : https://sepolia.etherscan.io/address/0x3fe8a3760c2794a05e7e8efbf41ec831a0eb74f9#code

1. Set env 
```
PRIVATE_KEY=
OWNER=
```
* PRIVATE KEY = use your own (do not push it!) or run anvil and use one of their private keys
* OWNER = any public address that you want to set as the owner. It is better to set a known account as there are some actions that can only be performed by the owner.

2. Deploy
There are diffrent options for deployment:
 * Deploy on avil :
```
forge script DeployHardPeg
```

 * Simulate deployment on a chain :
```
forge script DeployHardPeg --rpc $RPC_SPEPOLIA
```
> This doesn't execute a real tx or spend money, you can use it to check reverts, or estimating deployment gas costs on chain.
You can get the RPC providers from Alchemy

* Deploy on chain : 

```
forge script DeployHardPeg --rpc $RPC_SPEPOLIA --broadcast --verify
```

3. Get the ABI
```
./out/testAll.sol/HardPeg.json
```
Every time you forge depoly the abi will be updated here. Use the abi from this specific json.



## Contracts
> * /Core/shared/AccessManager     |--> DONE
> * /Core/shared/CollateralManager |--> DONE
> * /Core/shared/AppManager        |--> DONE
> * /Core/shared/Security|--> DONE
> * /Core/shared/Oracle |--> DONE
> * /Core/shared/Engine |--> [removed]
> * /Core/HardPeg | --> DONE
* /Core/MediumPeg | --> IN PROGRESS
* /Core/SoftPeg | --> IN PROGRESS
> * /mocks/MockOracle |--> DONE
> * /mocks/MockRandomOracle |--> DONE
> * /PrivateCoin | --> DONE
 * /Timelock | --> IN PROGRESS
  * /Script/DeployHardPeg | --> IN PROGRESS
 * /Script/ScenarioAttacks ... | --> X

 # Possible added features
 * Scenario attack scripts :
-oracle manipulation → mint → redeem → dump
-sandwich deposit/withdraw ordering
-griefing transfer locks
-precision drain over many rounds

 * Oracle Fallback -> If chainlink is invalid check a second oracle... 
 * Cross chain ((Li.fi for UX) Smart Contracts for the actual PrivateCoin... )

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
