import { type Address } from "viem";

// Update these after deployment
export const CONTRACT_ADDRESSES: Record<number, { hardPeg: Address }> = {
  // Localhost / Anvil
  31337: {
    hardPeg: "0x0165878A594ca255338adfa4d48449f69242Eb8F",
  },
};

export function getContractAddress(chainId: number) {
  return CONTRACT_ADDRESSES[chainId] ?? null;
}
