"use client";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { createAppKit } from "@reown/appkit/react";
import { type ReactNode, useState } from "react";
import { WagmiProvider, type State } from "wagmi";
import { wagmiAdapter, projectId, networks } from "@/config/wagmi";
import { mainnet } from "@reown/appkit/networks"; // eslint-disable-line @typescript-eslint/no-unused-vars
import { initLifi } from "@/config/lifi";

// Set up metadata
const metadata = {
  name: "HackMoney",
  description: "HackMoney Web3 App",
  url: "https://hackmoney.xyz", // Update with your domain
  icons: ["https://avatars.githubusercontent.com/u/179229932"], // Update with your icon
};

// Create the modal
createAppKit({
  adapters: [wagmiAdapter],
  projectId: projectId!,
  networks,
  defaultNetwork: networks[0],
  metadata,
  features: {
    analytics: true,
  },
});

initLifi();

export function Providers({
  children,
  initialState,
}: {
  children: ReactNode;
  initialState?: State;
}) {
  const [queryClient] = useState(() => new QueryClient());

  return (
    <WagmiProvider config={wagmiAdapter.wagmiConfig} initialState={initialState}>
      <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
    </WagmiProvider>
  );
}
