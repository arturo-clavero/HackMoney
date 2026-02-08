"use client";

import Link from "next/link";
import { useAppKit, useAppKitAccount } from "@reown/appkit/react";
import {
  useAccount,
  useWatchContractEvent,
  useReadContracts,
  usePublicClient,
} from "wagmi";
import { hardPegAbi } from "@/contracts/abis/hardPeg";
import { mediumPegAbi } from "@/contracts/abis/mediumPeg";
import {
  getContractAddress,
  ARC_CHAIN_ID,
  ARBITRUM_CHAIN_ID,
} from "@/contracts/addresses";
import { createPublicClient, http, erc20Abi, type Address } from "viem";
import { arbitrum } from "viem/chains";
import { useState, useEffect } from "react";
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

function InstancesList() {
  const { address } = useAppKitAccount();

  const arcClient = usePublicClient({ chainId: ARC_CHAIN_ID });
  const arbClient = createPublicClient({
    chain: arbitrum,
    transport: http("https://arb1.arbitrum.io/rpc"),
  });
  const clientByChain: Record<number, ReturnType<typeof usePublicClient> | typeof arbClient> = {
    [ARC_CHAIN_ID]: arcClient,
    [ARBITRUM_CHAIN_ID]: arbClient,
  };

  const [instances, setInstances] = useState<Instance[]>([]);
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    if (!address) return;
    let cancelled = false;

    (async () => {
      const allInstances: Instance[] = [];

      for (const source of PEG_SOURCES) {
        const client = clientByChain[source.chainId];
        if (!client) continue;
        const addrs = getContractAddress(source.chainId);
        if (!addrs) continue;

        try {
          const currentBlock = await client.getBlockNumber();
          const deployBlock = addrs.deployBlock;
          const CHUNK = BigInt(9999);

          for (
            let from = deployBlock;
            from <= currentBlock;
            from += CHUNK + BigInt(1)
          ) {
            if (cancelled) return;
            const to =
              from + CHUNK > currentBlock ? currentBlock : from + CHUNK;
            const logs = await client.getContractEvents({
              address: source.contractAddress,
              abi: source.abi,
              eventName: "RegisteredApp",
              args: { owner: address as Address },
              fromBlock: from,
              toBlock: to,
            });
            for (const log of logs) {
              allInstances.push({
                id: log.args.id!,
                coin: log.args.coin! as Address,
                pegType: source.pegType,
                chainId: source.chainId,
              });
            }
          }
        } catch {
          // continue with other sources
        }
      }

      if (!cancelled) {
        setInstances(allInstances);
        setLoaded(true);
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [address, arcClient]);

  // Watch for NEW events on HardPeg (Arc)
  const arcAddresses = getContractAddress(ARC_CHAIN_ID);
  useWatchContractEvent({
    address: arcAddresses?.hardPeg,
    abi: hardPegAbi,
    eventName: "RegisteredApp",
    args: { owner: address as Address },
    onLogs(logs) {
      const newInstances = logs.map((log) => ({
        id: log.args.id!,
        coin: log.args.coin! as Address,
        pegType: "hard" as PegType,
        chainId: ARC_CHAIN_ID,
      }));
      setInstances((prev) => {
        const existingIds = new Set(
          prev.map((i) => `${i.pegType}-${i.chainId}-${i.id.toString()}`)
        );
        const unique = newInstances.filter(
          (i) =>
            !existingIds.has(`${i.pegType}-${i.chainId}-${i.id.toString()}`)
        );
        return unique.length > 0 ? [...prev, ...unique] : prev;
      });
    },
    enabled: !!arcAddresses?.hardPeg && !!address,
  });

  // Watch for NEW events on MediumPeg (Arbitrum)
  const arbAddresses = getContractAddress(ARBITRUM_CHAIN_ID);
  useWatchContractEvent({
    address: arbAddresses?.mediumPeg,
    abi: mediumPegAbi,
    eventName: "RegisteredApp",
    args: { owner: address as Address },
    onLogs(logs) {
      const newInstances = logs.map((log) => ({
        id: log.args.id!,
        coin: log.args.coin! as Address,
        pegType: "medium" as PegType,
        chainId: ARBITRUM_CHAIN_ID,
      }));
      setInstances((prev) => {
        const existingIds = new Set(
          prev.map((i) => `${i.pegType}-${i.chainId}-${i.id.toString()}`)
        );
        const unique = newInstances.filter(
          (i) =>
            !existingIds.has(`${i.pegType}-${i.chainId}-${i.id.toString()}`)
        );
        return unique.length > 0 ? [...prev, ...unique] : prev;
      });
    },
    enabled: !!arbAddresses?.mediumPeg && !!address,
  });

  // Read name() and symbol() for each coin — on the correct chain
  const coinNames = useReadContracts({
    contracts: instances.map((inst) => ({
      address: inst.coin,
      abi: erc20Abi,
      functionName: "name" as const,
      chainId: inst.chainId,
    })),
    query: { enabled: instances.length > 0 },
  });

  const coinSymbols = useReadContracts({
    contracts: instances.map((inst) => ({
      address: inst.coin,
      abi: erc20Abi,
      functionName: "symbol" as const,
      chainId: inst.chainId,
    })),
    query: { enabled: instances.length > 0 },
  });

  if (!loaded) {
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
