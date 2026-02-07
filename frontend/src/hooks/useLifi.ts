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
  type TokenExtended,
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
          extended: true,
        }),
      ]);
      setChains(evmChains);
      loadedRef.current = true;

      const mapped: Record<number, TokenAmount[]> = {};
      for (const [cid, tokens] of Object.entries(allTokens)) {
        mapped[Number(cid)] = tokens.map((t) => ({
          ...t,
          amount: BigInt(0),
        }));
      }

      // Show tokens immediately with zero balances
      setTokensByChain(mapped);
      setIsLoading(false);

      // Preload balances for connected chain in the background (non-blocking)
      const wallet = walletRef.current;
      if (wallet && preloadBalanceChain && mapped[preloadBalanceChain]?.length) {
        balancesLoaded.current.add(preloadBalanceChain);
        setLoadingBalancesChainId(preloadBalanceChain);
        getTokenBalances(wallet, mapped[preloadBalanceChain])
          .then((balances) => {
            setTokensByChain((prev) => ({
              ...prev,
              [preloadBalanceChain]: mergeBalances(
                prev[preloadBalanceChain] ?? [],
                balances
              ),
            }));
          })
          .catch(() => {
            balancesLoaded.current.delete(preloadBalanceChain);
          })
          .finally(() => {
            setLoadingBalancesChainId((prev) =>
              prev === preloadBalanceChain ? null : prev
            );
          });
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load tokens");
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

  // Load balances for all chains progressively (non-blocking)
  const loadAllBalances = useCallback(async () => {
    const wallet = walletRef.current;
    if (!wallet) return;
    const allChainTokens = tokensRef.current;
    const chainIds = Object.keys(allChainTokens).map(Number);
    // Fire all chain balance fetches in parallel
    await Promise.allSettled(
      chainIds.map(async (chainId) => {
        if (balancesLoaded.current.has(chainId)) return;
        const tokens = allChainTokens[chainId];
        if (!tokens?.length) return;
        balancesLoaded.current.add(chainId);
        try {
          const balances = await getTokenBalances(wallet, tokens);
          setTokensByChain((prev) => ({
            ...prev,
            [chainId]: mergeBalances(prev[chainId] ?? [], balances),
          }));
        } catch {
          balancesLoaded.current.delete(chainId);
        }
      })
    );
  }, [walletAddress]);

  return { chains, tokensByChain, isLoading, loadingBalancesChainId, error, load, loadBalancesForChain, loadAllBalances };
}

// ─── Quoting ────────────────────────────────────────────────────────────────

export interface QuoteResult {
  route: Route;
  toAmount: string;
  toAmountMin: string;
  toAmountUSD: string;
  gasCostUSD: string | undefined;
  executionDuration: number; // seconds
  destinationChainId: number; // which chain the USDC lands on
  routesChecked: number; // how many destinations were compared
}

export function useLifiQuote() {
  const [quote, setQuote] = useState<QuoteResult | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const abortRef = useRef<AbortController | null>(null);

  const fetchQuote = useCallback(
    async (params: {
      fromChain: number;
      fromToken: string;
      fromAmount: string;
      fromAddress: string;
      destinations: { toChain: number; toToken: string }[];
    }) => {
      abortRef.current?.abort();
      const controller = new AbortController();
      abortRef.current = controller;

      setIsLoading(true);
      setError(null);
      setQuote(null);

      try {
        const results = await Promise.allSettled(
          params.destinations.map((dest) =>
            getQuote(
              {
                fromChain: params.fromChain,
                toChain: dest.toChain,
                fromToken: params.fromToken,
                toToken: dest.toToken,
                fromAmount: params.fromAmount,
                fromAddress: params.fromAddress,
              },
              { signal: controller.signal }
            ).then((step) => ({ step, chainId: dest.toChain }))
          )
        );

        if (controller.signal.aborted) return;

        const fulfilled = results.filter(
          (r): r is PromiseFulfilledResult<{ step: LiFiStep; chainId: number }> =>
            r.status === "fulfilled"
        );

        if (fulfilled.length === 0) {
          const firstErr = results.find(
            (r): r is PromiseRejectedResult => r.status === "rejected"
          );
          throw firstErr?.reason ?? new Error("No routes available");
        }

        fulfilled.sort((a, b) => {
          const aAmt = BigInt(a.value.step.estimate?.toAmount ?? "0");
          const bAmt = BigInt(b.value.step.estimate?.toAmount ?? "0");
          if (bAmt > aAmt) return 1;
          if (bAmt < aAmt) return -1;
          return 0;
        });

        const best = fulfilled[0].value;
        const route = convertQuoteToRoute(best.step);
        setQuote({
          route,
          toAmount: best.step.estimate?.toAmount ?? "0",
          toAmountMin: best.step.estimate?.toAmountMin ?? "0",
          toAmountUSD: best.step.estimate?.toAmountUSD ?? "0",
          gasCostUSD: best.step.estimate?.gasCosts
            ?.reduce((sum, g) => sum + Number(g.amountUSD ?? 0), 0)
            .toFixed(2),
          executionDuration: best.step.estimate?.executionDuration ?? 0,
          destinationChainId: best.chainId,
          routesChecked: params.destinations.length,
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
