"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import {
  getChains,
  getTokens,
  getTokenBalances,
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
  const [loadingBalancesChainId, setLoadingBalancesChainId] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);

  const balancesLoaded = useRef(new Set<number>());
  const loadedRef = useRef(false);
  const walletRef = useRef(walletAddress);
  walletRef.current = walletAddress;

  // Merge balance data into a token list, preserving all tokens
  const mergeBalances = (
    tokens: TokenAmount[],
    balances: TokenAmount[]
  ): TokenAmount[] => {
    const balanceMap = new Map(
      balances.map((b) => [b.address.toLowerCase(), b])
    );
    return tokens.map((t) => balanceMap.get(t.address.toLowerCase()) ?? t);
  };

  // Fetch chains + tokens, optionally preload balances for one chain
  const load = useCallback(async (preloadBalanceChain?: number) => {
    if (loadedRef.current) {
      // Tokens already loaded — only preload balances if requested
      if (preloadBalanceChain && !balancesLoaded.current.has(preloadBalanceChain)) {
        const wallet = walletRef.current;
        const tokens = tokensRef.current[preloadBalanceChain];
        if (wallet && tokens?.length) {
          balancesLoaded.current.add(preloadBalanceChain);
          setLoadingBalancesChainId(preloadBalanceChain);
          try {
            const balances = await getTokenBalances(wallet, tokens);
            setTokensByChain((prev) => ({
              ...prev,
              [preloadBalanceChain]: mergeBalances(prev[preloadBalanceChain] ?? [], balances),
            }));
          } catch {
            balancesLoaded.current.delete(preloadBalanceChain);
          } finally {
            setLoadingBalancesChainId((prev) =>
              prev === preloadBalanceChain ? null : prev
            );
          }
        }
      }
      return;
    }

    setIsLoading(true);
    setError(null);
    try {
      const [evmChains, { tokens: allTokens }] = await Promise.all([
        getChains({ chainTypes: [ChainType.EVM] }),
        getTokens({
          chainTypes: [ChainType.EVM],
          orderBy: "volumeUSD24H",
          limit: 50,
          minPriceUSD: 0.01,
        }),
      ]);
      setChains(evmChains);
      loadedRef.current = true;

      const mapped: Record<number, TokenAmount[]> = {};
      for (const [cid, tokens] of Object.entries(allTokens)) {
        mapped[Number(cid)] = tokens.map((t) => ({ ...t, amount: BigInt(0) }));
      }

      // Preload balances for connected chain inline — no race condition
      const wallet = walletRef.current;
      if (wallet && preloadBalanceChain && mapped[preloadBalanceChain]?.length) {
        try {
          const balances = await getTokenBalances(wallet, mapped[preloadBalanceChain]);
          mapped[preloadBalanceChain] = mergeBalances(mapped[preloadBalanceChain], balances);
          balancesLoaded.current.add(preloadBalanceChain);
        } catch {
          // Balance preload failed — tokens still show with 0 balance
        }
      }

      setTokensByChain(mapped);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load tokens");
    } finally {
      setIsLoading(false);
    }
  }, []);

  // Ref for accessing tokensByChain without stale closure
  const tokensRef = useRef(tokensByChain);
  tokensRef.current = tokensByChain;

  // Fetch balances for a specific chain's tokens (on-demand from modal)
  const loadBalancesForChain = useCallback(
    async (chainId: number) => {
      if (!walletAddress) return;
      if (balancesLoaded.current.has(chainId)) return;
      const tokens = tokensRef.current[chainId];
      if (!tokens?.length) return;

      balancesLoaded.current.add(chainId);
      setLoadingBalancesChainId(chainId);
      try {
        const balances = await getTokenBalances(walletAddress, tokens);
        setTokensByChain((prev) => ({
          ...prev,
          [chainId]: mergeBalances(prev[chainId] ?? [], balances),
        }));
      } catch {
        balancesLoaded.current.delete(chainId);
      } finally {
        setLoadingBalancesChainId((prev) => (prev === chainId ? null : prev));
      }
    },
    [walletAddress]
  );

  return { chains, tokensByChain, isLoading, loadingBalancesChainId, error, load, loadBalancesForChain };
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
