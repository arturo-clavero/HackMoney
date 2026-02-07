import { type Address } from "viem";

// Update these after deployment
export const CONTRACT_ADDRESSES: Record<
  number,
  { hardPeg: Address; deployBlock: bigint }
> = {
  // Localhost / Anvil
  31337: {
    hardPeg: "0x0165878A594ca255338adfa4d48449f69242Eb8F",
    deployBlock: BigInt(0),
  },
  // Arc Testnet
  5042002: {
    hardPeg: "0xa642feDfd1B9e5C1d93aA85C9766761F642eA462",
    deployBlock: BigInt(25685700),
  },
};

export const USDC_ADDRESSES: Record<number, Address> = {
  42161: "0xaf88d065e77c8cC2239327C5EDb3A432268e5831", // Arbitrum mainnet
  8453: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913", // Base mainnet
  421614: "0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d", // Arbitrum Sepolia
  5042002: "0x3600000000000000000000000000000000000000", // Arc testnet
};

export const ARC_CHAIN_ID = 5042002;
export const ARC_USDC = USDC_ADDRESSES[ARC_CHAIN_ID];

export const CIRCLE_BRIDGE_CHAINS: Record<
  number,
  { usdc: Address; bridgeChainName: string; label: string }
> = {
  42161: {
    usdc: "0xaf88d065e77c8cC2239327C5EDb3A432268e5831",
    bridgeChainName: "Arbitrum",
    label: "Arbitrum",
  },
  8453: {
    usdc: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
    bridgeChainName: "Base",
    label: "Base",
  },
  421614: {
    usdc: "0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d",
    bridgeChainName: "Arbitrum_Sepolia",
    label: "Arbitrum Sepolia",
  },
};

export const QUOTE_DESTINATIONS: { chainId: number; usdc: Address }[] = [
  { chainId: 42161, usdc: "0xaf88d065e77c8cC2239327C5EDb3A432268e5831" }, // Arbitrum
  { chainId: 8453,  usdc: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913" }, // Base
];

export function getContractAddress(chainId: number) {
  return CONTRACT_ADDRESSES[chainId] ?? null;
}

export function isCircleBridgeChain(chainId: number): boolean {
  return chainId in CIRCLE_BRIDGE_CHAINS;
}

export function getCircleBridgeConfig(chainId: number) {
  return CIRCLE_BRIDGE_CHAINS[chainId] ?? null;
}
