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
import { getContractAddress } from "@/contracts/addresses";
import { erc20Abi, type Address } from "viem";
import { useState, useEffect } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Alert, AlertDescription } from "@/components/ui/alert";
import {
  PageTransition,
  StaggerContainer,
  StaggerItem,
  motion,
} from "@/components/motion";

const ARC_CHAIN_ID = 5042002;

function truncateAddress(addr: string) {
  return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
}

interface Instance {
  id: bigint;
  coin: Address;
}

function InstancesList() {
  const { address } = useAppKitAccount();
  const addresses = getContractAddress(ARC_CHAIN_ID);
  const contractAddress = addresses?.hardPeg;

  const publicClient = usePublicClient({ chainId: ARC_CHAIN_ID });
  const [instances, setInstances] = useState<Instance[]>([]);
  const [loaded, setLoaded] = useState(false);

  // One-time fetch of historical events.
  // Some RPCs (e.g. Arc testnet) limit eth_getLogs to 10k blocks, so we
  // paginate in chunks from the deploy block to the current block.
  useEffect(() => {
    if (!contractAddress || !address || !publicClient || !addresses) return;
    let cancelled = false;

    (async () => {
      try {
        const currentBlock = await publicClient.getBlockNumber();
        const deployBlock = addresses.deployBlock;
        const CHUNK = BigInt(9999);
        const allLogs: typeof instances = [];

        for (
          let from = deployBlock;
          from <= currentBlock;
          from += CHUNK + BigInt(1)
        ) {
          if (cancelled) return;
          const to =
            from + CHUNK > currentBlock ? currentBlock : from + CHUNK;
          const logs = await publicClient.getContractEvents({
            address: contractAddress,
            abi: hardPegAbi,
            eventName: "RegisteredApp",
            args: { owner: address as Address },
            fromBlock: from,
            toBlock: to,
          });
          for (const log of logs) {
            allLogs.push({
              id: log.args.id!,
              coin: log.args.coin! as Address,
            });
          }
        }

        if (!cancelled) {
          setInstances(allLogs);
          setLoaded(true);
        }
      } catch {
        if (!cancelled) setLoaded(true);
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [contractAddress, address, publicClient, addresses]);

  // Watch for NEW events while the page is open
  useWatchContractEvent({
    address: contractAddress,
    abi: hardPegAbi,
    eventName: "RegisteredApp",
    args: { owner: address as Address },
    onLogs(logs) {
      const newInstances = logs.map((log) => ({
        id: log.args.id!,
        coin: log.args.coin! as Address,
      }));
      setInstances((prev) => {
        const existingIds = new Set(prev.map((i) => i.id.toString()));
        const unique = newInstances.filter(
          (i) => !existingIds.has(i.id.toString())
        );
        return unique.length > 0 ? [...prev, ...unique] : prev;
      });
    },
    enabled: !!contractAddress && !!address,
  });

  // Read name() and symbol() for each coin
  const coinNames = useReadContracts({
    contracts: instances.map((inst) => ({
      address: inst.coin,
      abi: erc20Abi,
      functionName: "name" as const,
      chainId: ARC_CHAIN_ID,
    })),
    query: { enabled: instances.length > 0 },
  });

  const coinSymbols = useReadContracts({
    contracts: instances.map((inst) => ({
      address: inst.coin,
      abi: erc20Abi,
      functionName: "symbol" as const,
      chainId: ARC_CHAIN_ID,
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

        return (
          <StaggerItem key={inst.id.toString()}>
            <Link href={`/instance/${inst.id.toString()}`}>
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
