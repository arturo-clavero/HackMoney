"use client";

import { useState, useCallback } from "react";
import { useAccount } from "wagmi";

// ─── Types ───────────────────────────────────────────────────────────────────

export type BridgeStatus = "idle" | "bridging" | "done" | "error";

export interface UseBridgeToArcReturn {
  status: BridgeStatus;
  error: string | null;
  txHash: string | null;
  bridge: (amount: string, sourceChainName?: string) => Promise<void>;
  reset: () => void;
}

// ─── Hook ────────────────────────────────────────────────────────────────────

export function useBridgeToArc(): UseBridgeToArcReturn {
  const { connector } = useAccount();

  const [status, setStatus] = useState<BridgeStatus>("idle");
  const [error, setError] = useState<string | null>(null);
  const [txHash, setTxHash] = useState<string | null>(null);

  const bridge = useCallback(
    async (amount: string, sourceChainName: string = "Arbitrum_Sepolia") => {
      if (!connector) {
        setStatus("error");
        setError("Wallet not connected");
        return;
      }

      setStatus("bridging");
      setError(null);
      setTxHash(null);

      try {
        // Dynamic imports to avoid SSR issues with Next.js
        const [{ BridgeKit, BridgeChain }, { createViemAdapterFromProvider }] =
          await Promise.all([
            import("@circle-fin/bridge-kit"),
            import("@circle-fin/adapter-viem-v2"),
          ]);

        // Get EIP-1193 provider from the wagmi connector
        const provider = await connector.getProvider();

        if (!provider) {
          throw new Error("Could not get provider from wallet connector");
        }

        const adapter = await createViemAdapterFromProvider({ provider: provider as any });

        const kit = new BridgeKit();

        // Listen for the first tx hash from the approve or burn step
        kit.on("*", (payload: any) => {
          if (payload?.values?.txHash && !txHash) {
            setTxHash(payload.values.txHash);
          }
        });

        const sourceChain =
          BridgeChain[sourceChainName as keyof typeof BridgeChain];
        if (!sourceChain) {
          throw new Error(`Unknown bridge chain: ${sourceChainName}`);
        }

        const result = await kit.bridge({
          from: { adapter, chain: sourceChain },
          to: { adapter, chain: BridgeChain.Arc_Testnet },
          amount,
        });

        if (result.state === "success") {
          // Extract the last tx hash from the steps
          const lastStep = [...result.steps].reverse().find((s) => s.txHash);
          if (lastStep?.txHash) {
            setTxHash(lastStep.txHash);
          }
          setStatus("done");
        } else {
          const failedStep = result.steps.find((s) => s.state === "error");
          throw new Error(
            failedStep?.errorMessage ?? "Bridge transfer failed"
          );
        }
      } catch (err) {
        setStatus("error");
        setError(err instanceof Error ? err.message : "Bridge failed");
      }
    },
    [connector]
  );

  const reset = useCallback(() => {
    setStatus("idle");
    setError(null);
    setTxHash(null);
  }, []);

  return { status, error, txHash, bridge, reset };
}
