"use client";

import Link from "next/link";
import { useAppKit, useAppKitAccount } from "@reown/appkit/react";
import {
  useAccount,
  useReadContracts,
} from "wagmi";
import { hardPegAbi } from "@/contracts/abis/hardPeg";
import { mediumPegAbi } from "@/contracts/abis/mediumPeg";
import {
  getContractAddress,
  ARC_CHAIN_ID,
  ARBITRUM_CHAIN_ID,
} from "@/contracts/addresses";
import { erc20Abi, type Address } from "viem";
import { useMemo } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import {
  PageTransition,
  StaggerContainer,
  StaggerItem,
  motion,
} from "@/components/motion";

function truncateAddress(addr: string) {
  return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
}

type PegType = "hard" | "medium";

interface Instance {
  id: bigint;
  coin: Address;
  pegType: PegType;
  chainId: number;
}

interface PegSource {
  chainId: number;
  pegType: PegType;
  contractAddress: Address;
  abi: typeof hardPegAbi | typeof mediumPegAbi;
}

const MAX_APP_ID = 10;

const PEG_SOURCES = ([
  {
    chainId: ARC_CHAIN_ID,
    pegType: "hard" as PegType,
    contractAddress: getContractAddress(ARC_CHAIN_ID)?.hardPeg as Address,
    abi: hardPegAbi,
  },
  {
    chainId: ARBITRUM_CHAIN_ID,
    pegType: "medium" as PegType,
    contractAddress: getContractAddress(ARBITRUM_CHAIN_ID)?.mediumPeg as Address,
    abi: mediumPegAbi,
  },
] as PegSource[]).filter((s) => !!s.contractAddress);

// Build multicall batch: getAppConfig(1..MAX_APP_ID) for each peg source
const appConfigCalls = PEG_SOURCES.flatMap((source) =>
  Array.from({ length: MAX_APP_ID }, (_, i) => ({
    address: source.contractAddress,
    abi: source.abi,
    functionName: "getAppConfig" as const,
    args: [BigInt(i + 1)] as const,
    chainId: source.chainId,
    // metadata for filtering later
    _pegType: source.pegType,
    _chainId: source.chainId,
    _id: BigInt(i + 1),
  }))
);

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

function InstancesList() {
  const { address } = useAppKitAccount();

  // Single multicall: reads getAppConfig(1..50) from both contracts
  const { data: appConfigs, isLoading } = useReadContracts({
    contracts: appConfigCalls.map(({ _pegType, _chainId, _id, ...call }) => call),
    query: { enabled: !!address, staleTime: 60_000 },
  });

  // Filter to instances owned by connected wallet
  const instances = useMemo(() => {
    if (!appConfigs || !address) return [];
    const result: Instance[] = [];
    for (let i = 0; i < appConfigCalls.length; i++) {
      const config = appConfigs[i];
      if (config.status !== "success" || !config.result) continue;
      const { owner, coin } = config.result as { owner: Address; coin: Address; tokensAllowed: bigint };
      if (owner === ZERO_ADDRESS) continue;
      if (owner.toLowerCase() !== address.toLowerCase()) continue;
      result.push({
        id: appConfigCalls[i]._id,
        coin: coin as Address,
        pegType: appConfigCalls[i]._pegType,
        chainId: appConfigCalls[i]._chainId,
      });
    }
    return result;
  }, [appConfigs, address]);

  // Read name() and symbol() for each discovered coin
  const coinNames = useReadContracts({
    contracts: instances.map((inst) => ({
      address: inst.coin,
      abi: erc20Abi,
      functionName: "name" as const,
      chainId: inst.chainId,
    })),
    query: { enabled: instances.length > 0, staleTime: 60_000 },
  });

  const coinSymbols = useReadContracts({
    contracts: instances.map((inst) => ({
      address: inst.coin,
      abi: erc20Abi,
      functionName: "symbol" as const,
      chainId: inst.chainId,
    })),
    query: { enabled: instances.length > 0, staleTime: 60_000 },
  });

  if (isLoading) {
    return (
      <div className="flex items-center justify-center gap-3 py-12">
        <div className="h-5 w-5 animate-spin rounded-full border-2 border-muted border-t-primary" />
        <p className="text-sm text-muted-foreground">
          Loading your stablecoins...
        </p>
      </div>
    );
  }

  if (instances.length === 0) {
    return (
      <Alert variant="default" className="border-dashed">
        <AlertDescription className="text-center">
          <p className="text-muted-foreground">No stablecoin instances yet.</p>
          <p className="text-sm text-muted-foreground/60">
            Use the button above to create one.
          </p>
        </AlertDescription>
      </Alert>
    );
  }

  return (
    <StaggerContainer className="flex flex-col gap-3">
      {instances.map((inst, i) => {
        const name = coinNames.data?.[i]?.result ?? "Loading...";
        const symbol = coinSymbols.data?.[i]?.result ?? "...";
        const pegLabel = inst.pegType === "hard" ? "Hard Peg" : "Yield Peg";
        const chainLabel =
          inst.chainId === ARC_CHAIN_ID ? "Arc Testnet" : "Arbitrum";

        return (
          <StaggerItem key={`${inst.pegType}-${inst.chainId}-${inst.id.toString()}`}>
            <Link
              href={`/instance/${inst.id.toString()}?peg=${inst.pegType}&chain=${inst.chainId}`}
            >
              <motion.div
                whileHover={{ scale: 1.01 }}
                whileTap={{ scale: 0.99 }}
              >
                <Card className="transition-colors hover:border-primary/50">
                  <CardContent className="flex items-center gap-4 p-4">
                    <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-primary/10 text-sm font-bold text-primary">
                      {symbol.slice(0, 3)}
                    </div>
                    <div className="min-w-0 flex-1">
                      <div className="flex items-baseline gap-2">
                        <p className="font-semibold">{symbol}</p>
                        <p className="truncate text-sm text-muted-foreground">
                          {name}
                        </p>
                      </div>
                      <div className="mt-1 flex gap-3 text-xs text-muted-foreground/60">
                        <span>App #{inst.id.toString()}</span>
                        <span className="font-mono">
                          {truncateAddress(inst.coin)}
                        </span>
                      </div>
                    </div>
                    <div className="flex flex-col items-end gap-1">
                      <Badge
                        variant={
                          inst.pegType === "hard" ? "default" : "secondary"
                        }
                      >
                        {pegLabel}
                      </Badge>
                      <span className="text-xs text-muted-foreground">
                        {chainLabel}
                      </span>
                    </div>
                  </CardContent>
                </Card>
              </motion.div>
            </Link>
          </StaggerItem>
        );
      })}
    </StaggerContainer>
  );
}

export default function Home() {
  const { open } = useAppKit();
  const { isConnected } = useAppKitAccount();
  const { status } = useAccount();

  // Wallet is restoring a previous session — render nothing to avoid layout flash
  if (status === "reconnecting" || status === "connecting") {
    return null;
  }

  if (!isConnected) {
    return (
      <div className="flex min-h-[calc(100vh-57px)] items-center justify-center">
        <PageTransition>
          <div className="flex flex-col items-center gap-6">
            <h1 className="text-4xl font-bold">HackMoney</h1>
            <p className="max-w-md text-center text-muted-foreground">
              Create and manage your own stablecoin instances backed by
              protocol-approved collateral.
            </p>
            <motion.div whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.98 }}>
              <Button size="lg" onClick={() => open()}>
                Connect Wallet
              </Button>
            </motion.div>
          </div>
        </PageTransition>
      </div>
    );
  }

  return (
    <PageTransition>
      <div className="mx-auto max-w-2xl px-6 py-12">
        <div className="mb-8 flex items-center justify-between">
          <h1 className="text-2xl font-bold">My Stablecoins</h1>
          <Button asChild>
            <Link href="/create">+ Create New</Link>
          </Button>
        </div>
        <InstancesList />
      </div>
    </PageTransition>
  );
}
