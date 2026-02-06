"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import {
  getChains,
  getTokens,
  getTokenBalancesByChain,
  getQuote,
  convertQuoteToRoute,
  executeRoute,
  ChainType,
  type ExtendedChain,
  type Token,
  type TokenAmount,
  type Route,
  type RouteExtended,
  type LiFiStep,
} from "@lifi/sdk";

// ─── Chain & Token Loading ──────────────────────────────────────────────────

export interface ChainWithTokens {
  chain: ExtendedChain;
  tokens: TokenAmount[];
}

export function useLifiTokens(walletAddress: string | undefined) {
  const [chains, setChains] = useState<ExtendedChain[]>([]);
  const [tokensByChain, setTokensByChain] = useState<
    Record<number, TokenAmount[]>
  >({});
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      const evmChains = await getChains({ chainTypes: [ChainType.EVM] });
      setChains(evmChains);

      // Fetch tokens for all chains
      const { tokens: allTokens } = await getTokens({
        chainTypes: [ChainType.EVM],
      });

      if (walletAddress) {
        // Fetch balances across all chains
        const balances = await getTokenBalancesByChain(
          walletAddress,
          allTokens
        );
        setTokensByChain(balances);
      } else {
        // No wallet — show tokens without balances
        const mapped: Record<number, TokenAmount[]> = {};
        for (const [chainId, tokens] of Object.entries(allTokens)) {
          mapped[Number(chainId)] = tokens.map((t) => ({
            ...t,
            amount: BigInt(0),
          }));
        }
        setTokensByChain(mapped);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load tokens");
    } finally {
      setIsLoading(false);
    }
  }, [walletAddress]);

  return { chains, tokensByChain, isLoading, error, load };
}

// ─── Quoting ────────────────────────────────────────────────────────────────

export interface QuoteResult {
  route: Route;
  toAmount: string;
  toAmountMin: string;
  toAmountUSD: string;
  gasCostUSD: string | undefined;
  executionDuration: number; // seconds
}

export function useLifiQuote() {
  const [quote, setQuote] = useState<QuoteResult | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const abortRef = useRef<AbortController | null>(null);

  const fetchQuote = useCallback(
    async (params: {
      fromChain: number;
      toChain: number;
      fromToken: string;
      toToken: string;
      fromAmount: string;
      fromAddress: string;
    }) => {
      // Abort any in-flight request
      abortRef.current?.abort();
      const controller = new AbortController();
      abortRef.current = controller;

      setIsLoading(true);
      setError(null);
      setQuote(null);

      try {
        const step: LiFiStep = await getQuote(
          {
            fromChain: params.fromChain,
            toChain: params.toChain,
            fromToken: params.fromToken,
            toToken: params.toToken,
            fromAmount: params.fromAmount,
            fromAddress: params.fromAddress,
          },
          { signal: controller.signal }
        );

        if (controller.signal.aborted) return;

        const route = convertQuoteToRoute(step);
        setQuote({
          route,
          toAmount: step.estimate?.toAmount ?? "0",
          toAmountMin: step.estimate?.toAmountMin ?? "0",
          toAmountUSD: step.estimate?.toAmountUSD ?? "0",
          gasCostUSD: step.estimate?.gasCosts
            ?.reduce((sum, g) => sum + Number(g.amountUSD ?? 0), 0)
            .toFixed(2),
          executionDuration: step.estimate?.executionDuration ?? 0,
        });
      } catch (err) {
        if (controller.signal.aborted) return;
        setError(err instanceof Error ? err.message : "No route available");
      } finally {
        if (!controller.signal.aborted) {
          setIsLoading(false);
        }
      }
    },
    []
  );

  const clearQuote = useCallback(() => {
    abortRef.current?.abort();
    setQuote(null);
    setError(null);
    setIsLoading(false);
  }, []);

  return { quote, isLoading, error, fetchQuote, clearQuote };
}

// ─── Execution ──────────────────────────────────────────────────────────────

export type SwapStatus = "idle" | "swapping" | "approving" | "depositing" | "done" | "error";

export function useLifiExecution() {
  const [status, setStatus] = useState<SwapStatus>("idle");
  const [error, setError] = useState<string | null>(null);

  const execute = useCallback(async (route: Route): Promise<RouteExtended> => {
    setStatus("swapping");
    setError(null);
    try {
      const result = await executeRoute(route, {
        updateRouteHook(updatedRoute) {
          // Could extend to expose step-level progress
        },
      });
      return result;
    } catch (err) {
      setStatus("error");
      setError(err instanceof Error ? err.message : "Swap failed");
      throw err;
    }
  }, []);

  const resetStatus = useCallback(() => {
    setStatus("idle");
    setError(null);
  }, []);

  return { status, setStatus, error, setError, execute, resetStatus };
}
