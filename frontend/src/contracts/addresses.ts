import { type Address } from "viem";

// Update these after deployment
export const CONTRACT_ADDRESSES: Record<number, { hardPeg: Address }> = {
  // Localhost / Anvil
  31337: {
    hardPeg: "0x851356ae760d987E095750cCeb3bC6014560891C",
  },
};

export function getContractAddress(chainId: number) {
  return CONTRACT_ADDRESSES[chainId] ?? null;
}
