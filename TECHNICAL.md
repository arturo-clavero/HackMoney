# StabiFi — Technical Documentation

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Architecture Overview](#2-architecture-overview)
3. [Smart Contract Architecture](#3-smart-contract-architecture)
4. [Cross-Chain Deposit Flows](#4-cross-chain-deposit-flows)
5. [Circle Arc Integration](#5-circle-arc-integration)
6. [LI.FI Integration](#6-lifi-integration)
7. [ENS Integration](#7-ens-integration)
8. [Frontend Architecture](#8-frontend-architecture)

---

## 1. Project Overview

StabiFi is a **multi-chain stablecoin factory** that lets anyone deploy their own permissioned, collateral-backed stablecoin instance. Each instance is an isolated ERC-20 token with configurable collateral backing, access controls, and peg mechanics.

### The Problem

Creating a stablecoin today requires building an entire protocol from scratch — collateral management, minting logic, access control, cross-chain liquidity, and a frontend. Existing stablecoins (USDT, USDC, DAI) serve broad markets but cannot be tailored to specific communities, organizations, or use cases like internal payroll tokens, community currencies, or application-scoped credits.

### The Solution

StabiFi provides a **factory pattern** where any user can deploy a stablecoin instance in minutes through a guided wizard. Each instance gets:

- A **dedicated ERC-20 token** (PrivateCoin) with permissioned minting, holding, and transfers
- A **collateral vault** backed by stablecoins, yield-bearing assets, or mixed baskets
- **Cross-chain deposit flows** — users can fund vaults from any token on any EVM chain
- **Configurable governance** — the instance owner controls who can mint, hold, and transfer

### Peg Designs

| Peg Type | Collateral | Minting | Chain | Use Case |
|----------|-----------|---------|-------|----------|
| **HardPeg** | Mixed stablecoin basket (USDC, USDT, etc.) | 1:1 against free collateral | Arc | Payment tokens, internal credits |
| **MediumPeg (Yield)** | Aave waArbUSDCn (ERC-4626 vault) | 1:1 against deposited principal; yield accrues separately | Arbitrum | Treasury tokens, yield-bearing credits |
| **SoftPeg** | Volatile assets (ETH, BTC) with oracle feeds | LTV-based mint credit with liquidation | Planned | Synthetic stablecoins |

---

## 2. Architecture Overview

### System Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────────┐
│                              USER                                        │
│                   (Any wallet, any EVM chain)                            │
└───────────────────────────┬──────────────────────────────────────────────┘
                            │
              ┌─────────────▼──────────────┐
              │      Next.js Frontend       │
              │  (wagmi + viem + AppKit)    │
              │                            │
              │  ┌────────┐  ┌──────────┐  │
              │  │ Create │  │ Instance │  │
              │  │ Wizard │  │  Detail  │  │
              │  └────────┘  └──────────┘  │
              └──┬────────────┬────────┬───┘
                 │            │        │
       ┌─────────▼──┐  ┌─────▼────┐  ┌▼──────────────┐
       │  LI.FI SDK  │  │  Circle  │  │ Direct RPC    │
       │  (swap +    │  │  Bridge  │  │ (deposit,     │
       │   bridge)   │  │  Kit     │  │  mint, redeem)│
       └──────┬──────┘  └────┬─────┘  └───────┬───────┘
              │              │                 │
    ┌─────────▼──────────────▼─────────────────▼────────────────────┐
    │                    BLOCKCHAIN LAYER                            │
    │                                                               │
    │  ┌─────────────┐    Circle CCTP     ┌──────────────────────┐ │
    │  │ Arbitrum     │◄─────────────────►│    Arc (Circle L1)    │ │
    │  │ Chain 42161  │    (burn-mint)    │    Chain 5042002      │ │
    │  │              │                   │                       │ │
    │  │ ┌──────────┐ │                   │  ┌────────────────┐   │ │
    │  │ │MediumPeg │ │                   │  │   HardPeg      │   │ │
    │  │ │  + Aave  │ │                   │  │ (stablecoin    │   │ │
    │  │ │waArbUSDCn│ │                   │  │  basket vault) │   │ │
    │  │ └──────────┘ │                   │  └────────────────┘   │ │
    │  └─────────────┘                    └──────────────────────┘ │
    │                                                               │
    │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐    │
    │  │Ethereum│ │  Base  │ │Polygon │ │  OP    │ │ 60+    │    │
    │  │        │ │        │ │        │ │Mainnet │ │ chains │    │
    │  └───┬────┘ └───┬────┘ └───┬────┘ └───┬────┘ └───┬────┘    │
    │      └──────────┴──────────┴──────────┴──────────┘          │
    │              LI.FI routes (27 bridges, 31 DEXs)              │
    └──────────────────────────────────────────────────────────────┘
```

### Cross-Chain Deposit Flow (HardPeg on Arc)

```
  User has ETH on Polygon                      Arc Testnet
  ─────────────────────                    ────────────────────
         │                                        │
         │  1. Select token + amount              │
         ▼                                        │
  ┌──────────────┐                                │
  │  LI.FI SDK   │  Quotes swap to USDC          │
  │  GET /quote  │  across Arbitrum + Base        │
  └──────┬───────┘  (picks best output)           │
         │                                        │
         │  2. Execute winning route              │
         ▼                                        │
  ┌──────────────┐                                │
  │  LI.FI Route │  ETH(Polygon) → USDC(Arb)     │
  │  Execution   │  via bridge + DEX              │
  └──────┬───────┘                                │
         │                                        │
         │  3. Bridge USDC to Arc                 │
         ▼                                        │
  ┌──────────────┐                                │
  │ Circle CCTP  │  burn on Arbitrum              │
  │ Bridge Kit   │─────────────────────────►  mint on Arc
  └──────────────┘                                │
                                                  │
                              4. Approve + deposit│
                                                  ▼
                                           ┌──────────────┐
                                           │   HardPeg    │
                                           │  .deposit()  │
                                           │              │
                                           │ vault[user]  │
                                           │  += amount   │
                                           └──────────────┘
```

### Cross-Chain Deposit Flow (MediumPeg on Arbitrum)

```
  User has DAI on Optimism                  Arbitrum
  ────────────────────────                 ──────────────
         │                                       │
         │  1. Select token + amount             │
         ▼                                       │
  ┌──────────────┐                               │
  │  LI.FI SDK   │  Quote: DAI(OP)              │
  │  GET /quote  │  → waArbUSDCn(Arb)           │
  └──────┬───────┘                               │
         │                                       │
         │  2. LI.FI executes:                   │
         │     bridge to Arb + swap to USDC      │
         │     + deposit into Aave vault         │
         ▼                                       │
  ┌──────────────┐                               │
  │  LI.FI +     │  Single route delivers        │
  │  Composer    │  waArbUSDCn vault tokens ────►│
  └──────────────┘                               │
                                                 │
                             3. Approve + deposit│
                                                 ▼
                                          ┌──────────────┐
                                          │  MediumPeg   │
                                          │.depositShares│
                                          │              │
                                          │  principal   │
                                          │  + shares    │
                                          │  tracked     │
                                          └──────────────┘
```

---

## 3. Smart Contract Architecture

### Contract Inheritance

```
AccessManager          ← Ownership, timelock, setup gating
    │
CollateralManager      ← Global collateral registry, oracle feeds, LTV, debt caps
    │
AppManager             ← Instance factory, PrivateCoin deployment, event registry
    │
Security               ← Global/per-tx mint caps, debt tracking
    │
    ├── HardPeg        ← 1:1 stablecoin basket, pro-rata withdrawals     [Arc]
    ├── MediumPeg      ← ERC-4626 yield vault, principal-based minting   [Arbitrum]
    └── SoftPeg        ← LTV-based volatile collateral (planned)
```

### PrivateCoin (App-Scoped ERC-20)

Each stablecoin instance deploys its own `PrivateCoin` contract — an ERC-20 + ERC-2612 (Permit) token with:

- **Bitmask-based permissions**: `MINT`, `HOLD`, `TRANSFER_DEST` — each user and the app owner gets a bitmask controlling what actions they can perform
- **Engine-restricted minting/burning**: Only the protocol peg contract (HardPeg, MediumPeg) can mint or burn tokens
- **Destination-restricted transfers**: Tokens can only be transferred to addresses with the `HOLD` permission
- **Meta-transaction support**: ERC-2612 Permit enables gasless approvals

This design enables compliant, gated circulation where the instance owner controls who participates.

### Key Operations

| Operation | HardPeg (Arc) | MediumPeg (Arbitrum) |
|-----------|--------------|---------------------|
| **Deposit** | `deposit(appId, token, amount)` — adds collateral to user's vault position at 1:1 value | `deposit(appId, assets)` — deposits USDC into Aave vault, tracks principal + shares |
| **Mint** | `mint(appId, to, amount)` — mints PrivateCoin 1:1 against free collateral | `mint(appId, to, amount)` — mints against principal; debt tracked separately |
| **Redeem** | `redeam(token, amount)` — burns PrivateCoin, returns pro-rata collateral basket | `redeam(stablecoin, amount)` — burns token, reduces debt, withdraws from Aave |
| **Withdraw** | `withdrawCollateral(appId, value)` — withdraws pro-rata basket of unused collateral | `withdrawCollateral(appId)` — requires zero debt; returns all shares as USDC |

### Collateral Configuration

```solidity
struct CollateralConfig {
    uint256 id;                 // Unique bitmask position (1-indexed)
    address tokenAddress;       // ERC-20 address
    uint256 decimals;           // Token decimals (6 for USDC, 18 for ETH)
    uint256 scale;              // 10^decimals for value normalization
    uint256 mode;               // STABLE | VOLATILE | YIELD bitmask
    address[] oracleFeeds;      // Chainlink price feeds
    uint256 LTV;                // Loan-to-value ratio (0–100)
    uint256 liquidityThreshold; // Minimum liquidity requirement
    uint256 debtCap;            // Maximum debt against this collateral
}
```

---

## 4. Cross-Chain Deposit Flows

The frontend detects the optimal deposit route based on the user's source token and chain:

| Route | Condition | Steps | Used By |
|-------|-----------|-------|---------|
| **Direct** | Token is already the target collateral on the contract's chain | Approve → Deposit | Both |
| **Bridge** | USDC on a Circle CCTP-supported chain, targeting Arc | CCTP Bridge → Approve → Deposit | HardPeg |
| **Full** | Any other token/chain, targeting Arc | LI.FI Swap → CCTP Bridge → Approve → Deposit | HardPeg |
| **LI.FI Composer** | Any token/chain, targeting Arbitrum | LI.FI Swap+Bridge (→ waArbUSDCn) → Approve → Deposit | MediumPeg |

### Multi-Destination Quote Optimization

For the **Full** route (HardPeg), the system doesn't just quote one path — it quotes in parallel to multiple intermediary chains and picks the best output:

```
User: 1000 MATIC on Polygon → HardPeg on Arc

Quote 1: MATIC(Polygon) → USDC(Arbitrum)  = 998.50 USDC  ← winner
Quote 2: MATIC(Polygon) → USDC(Base)      = 997.20 USDC

Execute: MATIC → USDC(Arbitrum) via LI.FI
Bridge:  USDC(Arbitrum) → USDC(Arc) via Circle CCTP
Deposit: USDC into HardPeg vault
```

This parallel quoting via `Promise.allSettled()` ensures users always get the best exchange rate across all available routes.

---

## 5. Circle Arc Integration

### Why Arc as the Settlement Layer

Arc is Circle's purpose-built L1 blockchain, and it provides specific advantages for a stablecoin factory protocol:

**1. USDC as Native Gas Token**
On Arc, USDC is the gas token — not ETH or any volatile asset. This means:
- Users funding a stablecoin vault never need to acquire a separate gas token
- Transaction cost accounting is directly in USD terms, which is natural for a stablecoin protocol
- There is no gas price volatility risk — operational costs are predictable

**2. Sub-Second Deterministic Finality**
Arc's Malachite consensus (BFT with rotating proposers) achieves ~780ms average finality at scale. For a deposit-and-mint protocol, this means:
- Deposits confirm in under a second — no waiting 12+ seconds for block confirmations
- No reorg risk — once a deposit is finalized, it cannot be reversed at the chain level
- Mint operations that depend on confirmed collateral can execute immediately

**3. Cross-Chain USDC Liquidity Hub**
Arc is a first-class CCTP V2 endpoint, meaning USDC can flow to and from Arc across 30+ connected chains. This makes Arc a natural **consolidation point** for USDC liquidity:

```
  Ethereum USDC ──┐
  Arbitrum USDC ──┤     Circle CCTP
  Base USDC ──────┤────(burn on source,────► Arc USDC ──► HardPeg Vault
  Polygon USDC ───┤     mint on Arc)                      (pooled liquidity)
  Optimism USDC ──┘
```

By deploying the HardPeg on Arc, all USDC deposits from any chain consolidate into a single liquidity pool on Arc. This avoids the fragmentation problem where vault liquidity is split across chains.

**4. Withdrawal to Any Chain**
When users redeem their stablecoins and withdraw collateral, the USDC they receive on Arc can be bridged to whichever chain they need via the same CCTP infrastructure. A user who deposited from Ethereum can withdraw to Base if that's where they need funds — the vault's liquidity is chain-agnostic.

**5. Compliance-Ready Architecture**
Arc's opt-in confidential transfers (amounts shielded, addresses public) with selective disclosure via view keys align with the permissioned nature of StabiFi's PrivateCoin tokens. Institutional users who need privacy for treasury operations can use Arc's confidential transfers while still providing auditors with view key access.

### Circle Tools Used

| Tool | How We Use It | Purpose |
|------|--------------|---------|
| **Arc** | HardPeg contract deployed on Arc Testnet (chain 5042002) | Settlement layer for stablecoin-backed instances |
| **USDC** | Primary collateral asset; gas token on Arc | Vault backing + transaction fees |
| **Bridge Kit** (CCTP) | `@circle-fin/bridge-kit` wrapping CCTP V2 | Bridge USDC from any supported chain to Arc |

### Bridge Kit Integration

```typescript
// frontend/src/hooks/useBridgeToArc.ts
import { createBridgeKit } from "@circle-fin/bridge-kit";
import { viemAdapter } from "@circle-fin/bridge-kit/viem";

const kit = createBridgeKit();

await kit.bridge({
  from: { adapter: viemAdapter(walletClient), chain: BridgeChain.Arbitrum },
  to:   { adapter: viemAdapter(walletClient), chain: BridgeChain.Arc_Testnet },
  amount: usdcAmount,
});
```

The Bridge Kit handles the full CCTP lifecycle: ERC-20 approval, burn on the source chain, attestation retrieval from Circle, and mint on Arc.

### Supported Bridge Routes

| Source Chain | Chain ID | USDC Address | Status |
|-------------|----------|--------------|--------|
| Arbitrum | 42161 | `0xaf88d065e77c8cC2239327C5EDb3A432268e5831` | Live |
| Arbitrum Sepolia | 421614 | `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d` | Live |
| Base Sepolia | 84532 | `0x036CbD53842c5426634e7929541eC2318f3dCF7e` | Live |

### Arc Deployment

| Contract | Address | Chain |
|----------|---------|-------|
| HardPeg | `0xa642feDfd1B9e5C1d93aA85C9766761F642eA462` | Arc Testnet (5042002) |

---

## 6. LI.FI Integration

### Why LI.FI

The core challenge for any DeFi vault is **deposit friction**. If a vault accepts USDC on Arbitrum, a user holding ETH on Polygon must: (1) find a bridge, (2) bridge to Arbitrum, (3) find a DEX, (4) swap to USDC, (5) approve, (6) deposit. That's 6 separate interactions across multiple interfaces.

LI.FI collapses this into a **single flow within our application**. The user selects any token on any chain, gets a quote, and executes — LI.FI handles bridge selection, DEX routing, and execution under the hood.

### What LI.FI Unlocks

**1. Universal Deposits — "Deposit From Anywhere"**
Users can deposit into StabiFi vaults from any of 60+ EVM chains using any token. LI.FI's routing layer queries 27 bridges and 31 DEX aggregators to find the optimal path. This means:
- No need to leave our application to prepare assets
- No need to know which bridge is cheapest or most reliable
- No manual multi-step swapping

**2. Composer for Atomic Multi-Step Execution (MediumPeg)**
For the MediumPeg on Arbitrum, the deposit target is `waArbUSDCn` — Aave's wrapped USDC vault token. LI.FI Composer handles the entire sequence atomically:
- Bridge source tokens to Arbitrum (if cross-chain)
- Swap to USDC on Arbitrum
- Deposit USDC into the Aave waArbUSDCn vault
- Deliver vault shares to the user

All of this happens in one user-facing transaction via Composer's on-chain VM, which compiles the multi-step recipe into bytecode and executes it atomically with dynamic output injection between steps.

**3. Multi-Destination Best Route Selection**
Our integration goes beyond single-path quoting. For HardPeg deposits (which route through CCTP to Arc), we quote to multiple intermediary chains in parallel:

```typescript
// frontend/src/hooks/useLifi.ts
const QUOTE_DESTINATIONS = [
  { chainId: 42161, usdc: "0xaf88..." }, // Arbitrum
  { chainId: 8453,  usdc: "0x8335..." }, // Base
];

// Quote to all destinations simultaneously
const results = await Promise.allSettled(
  destinations.map(dest => getQuote({
    fromChain, fromToken, fromAmount,
    toChain: dest.chainId,
    toToken: dest.usdc,
  }))
);

// Pick the route with the highest output
const bestRoute = results
  .filter(r => r.status === "fulfilled")
  .sort((a, b) => b.toAmount - a.toAmount)[0];
```

This ensures users always get the maximum USDC output, regardless of which intermediary chain offers the best rate at that moment.

**4. Liquidity Aggregation Across All Supported Chains**
By integrating LI.FI, StabiFi effectively treats all liquidity across all 60+ EVM chains as a single pool. A vault on Arc doesn't just draw from Arc-native liquidity — it can attract deposits from Ethereum whales, Polygon users, Base degens, and anyone else with tokens on any supported chain. This dramatically increases the addressable market for each stablecoin instance.

### LI.FI SDK Integration

```typescript
// frontend/src/config/lifi.ts
import { createConfig, EVM } from "@lifi/sdk";

createConfig({
  integrator: "stabifi",
  providers: [
    EVM({
      getWalletClient: () => getWalletClient(wagmiConfig),
      switchChain: async (chainId) => {
        const chain = await switchChain(wagmiConfig, { chainId });
        return getWalletClient(wagmiConfig, { chainId: chain.id });
      },
    }),
  ],
});
```

### Custom Hooks

| Hook | Purpose |
|------|---------|
| `useLifiTokens(wallet)` | Loads all EVM chains + tokens; lazy-loads per-chain balances |
| `useLifiQuote()` | Multi-destination parallel quoting with best-route selection |
| `useLifiExecution()` | Route execution with status tracking (idle → swapping → approving → depositing → done) |

### Token Selector UX

The frontend includes a full token selector modal powered by LI.FI data:
- Left panel: all supported EVM chains
- Right panel: tokens on the selected chain, sorted by balance
- Search: filter by token name or symbol
- Lazy balance loading: balances load per-chain on demand to avoid excessive RPC calls

---

## 7. ENS Integration

### Why ENS

In a stablecoin protocol with permissioned access, addresses are everywhere — app owners, authorized users, mint recipients, transfer destinations. Raw 0x addresses are error-prone and impossible to remember. ENS replaces these with human-readable names.

### Integration Points

**1. User Management — Adding/Removing Authorized Users**
Instance owners manage who can mint, hold, and transfer their stablecoin. Instead of copy-pasting `0x65Abb39A4c63A459c4ADD5af08E7877e546bE577`, the owner enters `treasury.company.eth`. The frontend resolves this via ENS before submitting the transaction.

This is particularly valuable for **payroll or payout use cases** (relevant to Arc's "Build Global Payouts" track). A company deploying a stablecoin instance for payroll can maintain a roster of `alice.company.eth`, `bob.company.eth`, etc. — far more auditable and less error-prone than a spreadsheet of hex addresses.

**2. Mint Recipient Resolution**
When minting stablecoins to a recipient (`mint(appId, to, amount)`), the `to` address can be entered as an ENS name. This reduces the risk of sending tokens to a wrong address — a critical concern for a protocol handling real collateral.

**3. Instance Owner Display**
On the home page and instance detail pages, instance owners are displayed with their ENS names (when available) instead of truncated hex addresses. This makes it easier to identify who operates each stablecoin instance.

**4. ENS Text Records for Instance Metadata**
ENS names can store arbitrary key-value text records. Stablecoin instances could store metadata in their owner's ENS records:
- `com.stabifi.instance.1.description` → "ACME Corp Employee Credits"
- `com.stabifi.instance.1.terms` → IPFS hash of terms of service
- `com.stabifi.instance.1.website` → instance-specific landing page

This enables **decentralized, verifiable metadata** without requiring a centralized backend.

### Technical Implementation

ENS resolution in the frontend uses wagmi's built-in ENS hooks:

```typescript
import { useEnsAddress, useEnsName, useEnsAvatar } from "wagmi";

// Resolve name → address (for user input)
const { data: address } = useEnsAddress({ name: "alice.eth" });

// Resolve address → name (for display)
const { data: ensName } = useEnsName({ address: "0x..." });

// Resolve avatar (for profile display)
const { data: avatar } = useEnsAvatar({ name: "alice.eth" });
```

No additional dependencies are needed — wagmi already includes ENS resolution via viem's ENS-aware transport.

---

## 8. Frontend Architecture

### Stack

| Technology | Version | Purpose |
|-----------|---------|---------|
| Next.js | 16 | React framework with Server Components |
| React | 19 | UI rendering |
| wagmi | Latest | Ethereum hooks (contract reads/writes, ENS, wallet) |
| viem | Latest | Low-level EVM interactions |
| @reown/appkit | Latest | Wallet connection (WalletConnect, injected, Coinbase) |
| @lifi/sdk | 3.15.5 | Cross-chain swaps and bridge routing |
| @circle-fin/bridge-kit | 1.5.0 | Circle CCTP bridge for USDC |
| Tailwind CSS + shadcn/ui | Latest | Styling and UI components |
| Framer Motion | Latest | Animations |

### Pages

| Route | Component | Description |
|-------|-----------|-------------|
| `/` | `app/page.tsx` | Home — discovers all instances via on-chain events, displays user's instances |
| `/create` | `app/create/page.tsx` | 5-step wizard: Name → Peg Type → Collateral → Permissions → Deploy |
| `/instance/[id]` | `app/instance/[id]/page.tsx` | Instance management: Overview, Collateral, Users, Vault Operations |

### Key Components

| Component | File | Description |
|-----------|------|-------------|
| `DepositFlow` | `components/instance/DepositFlow.tsx` | Orchestrates the full deposit flow: route detection, LI.FI quoting, bridge execution, contract deposit |
| `VaultOperations` | `components/instance/VaultOperations.tsx` | Tabbed interface for Deposit, Mint, Redeem, Withdraw |
| `TokenSelectorModal` | `components/instance/TokenSelectorModal.tsx` | Multi-chain token picker with lazy balance loading |
| `StepTracker` | `components/instance/StepTracker.tsx` | Animated progress indicator during multi-step deposit flows |
| `CreateWizard` | `components/create/` | 5-step instance creation flow |

### Wallet Integration

The frontend uses Reown AppKit (successor to WalletConnect) for wallet connection, supporting:
- MetaMask and other injected wallets
- WalletConnect protocol (mobile wallets)
- Coinbase Wallet
- Social login via Reown

Chain switching is handled automatically — when a user selects a token on a different chain, the frontend prompts for a chain switch before executing the LI.FI route.

---

## Appendix: Contract Addresses

### Production Deployments

| Contract | Chain | Chain ID | Address |
|----------|-------|----------|---------|
| HardPeg | Arc Testnet | 5042002 | `0xa642feDfd1B9e5C1d93aA85C9766761F642eA462` |
| MediumPeg | Arbitrum One | 42161 | `0xa642feDfd1B9e5C1d93aA85C9766761F642eA462` |

### Token Addresses

| Token | Chain | Address |
|-------|-------|---------|
| USDC | Arc Testnet | `0x3600000000000000000000000000000000000001` |
| USDC | Arbitrum | `0xaf88d065e77c8cC2239327C5EDb3A432268e5831` |
| waArbUSDCn | Arbitrum | `0x7CFaDFD5645B50bE87d546f42787c3b20CdBDe32` |
| USDC | Arbitrum Sepolia | `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d` |
| USDC | Base Sepolia | `0x036CbD53842c5426634e7929541eC2318f3dCF7e` |

### External Contracts

| Contract | Chain | Address |
|----------|-------|---------|
| LI.FI Diamond | All EVM chains | `0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE` |
| Aave waArbUSDCn Vault | Arbitrum | `0x7CFaDFD5645B50bE87d546f42787c3b20CdBDe32` |
