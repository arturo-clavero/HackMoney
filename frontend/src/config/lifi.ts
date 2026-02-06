import { createConfig, EVM, ChainType, getChains } from "@lifi/sdk";
import { getWalletClient, switchChain } from "@wagmi/core";
import { config as wagmiConfig } from "@/config/wagmi";

let initialized = false;

export function initLifi() {
  if (initialized) return;
  initialized = true;

  createConfig({
    integrator: "hackmoney",
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
}

export async function getEvmChains() {
  return getChains({ chainTypes: [ChainType.EVM] });
}
