"use client";

import { useState, useMemo, useEffect, useCallback, useRef, memo } from "react";
import { formatUnits } from "viem";
import { useVirtualizer } from "@tanstack/react-virtual";
import type { ExtendedChain, TokenAmount } from "@lifi/sdk";

const ALL_CHAINS_ID = 0;
const TOKEN_ITEM_HEIGHT = 52;
const DEBOUNCE_MS = 300;

const scrollbarClasses =
  "[&::-webkit-scrollbar]:w-1.5 [&::-webkit-scrollbar-track]:bg-transparent [&::-webkit-scrollbar-thumb]:rounded-full [&::-webkit-scrollbar-thumb]:bg-zinc-300 dark:[&::-webkit-scrollbar-thumb]:bg-zinc-600";

// ─── Skeleton Row ───────────────────────────────────────────────────────────

function TokenListItemSkeleton() {
  return (
    <div className="flex w-full items-center gap-3 px-4 py-2.5">
      <div className="h-7 w-7 animate-pulse rounded-full bg-zinc-200 dark:bg-zinc-700" />
      <div className="flex-1 min-w-0 space-y-1.5">
        <div className="h-3.5 w-16 animate-pulse rounded bg-zinc-200 dark:bg-zinc-700" />
        <div className="h-3 w-24 animate-pulse rounded bg-zinc-200 dark:bg-zinc-700" />
      </div>
      <div className="space-y-1.5 text-right">
        <div className="ml-auto h-3.5 w-12 animate-pulse rounded bg-zinc-200 dark:bg-zinc-700" />
      </div>
    </div>
  );
}

// ─── Memoized Token Row ─────────────────────────────────────────────────────

interface TokenListItemProps {
  token: TokenAmount;
  chainName: string | undefined;
  showChain: boolean;
  onClick: (token: TokenAmount, chainId: number) => void;
}

const TokenListItem = memo(function TokenListItem({
  token,
  chainName,
  showChain,
  onClick,
}: TokenListItemProps) {
  const balance = token.amount ?? BigInt(0);
  const hasBalance = balance > BigInt(0);

  return (
    <button
      onClick={() => onClick(token, token.chainId)}
      className="flex w-full items-center gap-3 px-4 py-2.5 text-left transition-colors hover:bg-zinc-50 dark:hover:bg-zinc-800"
    >
      {token.logoURI ? (
        <img
          src={token.logoURI}
          alt={token.symbol}
          className="h-7 w-7 rounded-full"
        />
      ) : (
        <div className="flex h-7 w-7 items-center justify-center rounded-full bg-zinc-200 text-xs font-bold text-zinc-500 dark:bg-zinc-700">
          {token.symbol.slice(0, 2)}
        </div>
      )}
      <div className="flex-1 min-w-0">
        <p className="text-sm font-medium text-black dark:text-white">
          {token.symbol}
        </p>
        <p className="truncate text-xs text-zinc-400">
          {token.name}
          {showChain && chainName && (
            <span className="text-zinc-300 dark:text-zinc-600">
              {" · "}{chainName}
            </span>
          )}
        </p>
      </div>
      <div className="text-right">
        <p
          className={`text-sm ${
            hasBalance
              ? "font-medium text-black dark:text-white"
              : "text-zinc-300 dark:text-zinc-600"
          }`}
        >
          {hasBalance
            ? Number(formatUnits(balance, token.decimals)).toLocaleString(undefined, {
                maximumFractionDigits: 4,
              })
            : "0"}
        </p>
        {hasBalance && token.priceUSD && (
          <p className="text-xs text-zinc-400">
            $
            {(
              Number(token.priceUSD) *
              Number(formatUnits(balance, token.decimals))
            ).toLocaleString(undefined, {
              maximumFractionDigits: 2,
            })}
          </p>
        )}
      </div>
    </button>
  );
});

// ─── Modal ──────────────────────────────────────────────────────────────────

interface Props {
  isOpen: boolean;
  onClose: () => void;
  onSelect: (token: TokenAmount, chainId: number) => void;
  chains: ExtendedChain[];
  tokensByChain: Record<number, TokenAmount[]>;
  isLoading: boolean;
  loadBalancesForChain: (chainId: number) => void;
  loadAllBalances: () => void;
  loadingBalancesChainId: number | null;
}

export function TokenSelectorModal({
  isOpen,
  onClose,
  onSelect,
  chains,
  tokensByChain,
  isLoading,
  loadBalancesForChain,
  loadAllBalances,
  loadingBalancesChainId,
}: Props) {
  const [selectedChainId, setSelectedChainId] = useState<number>(ALL_CHAINS_ID);
  const [search, setSearch] = useState("");
  const [debouncedSearch, setDebouncedSearch] = useState("");
  const scrollRef = useRef<HTMLDivElement>(null);

  const chainMap = useMemo(() => {
    const map = new Map<number, ExtendedChain>();
    for (const chain of chains) map.set(chain.id, chain);
    return map;
  }, [chains]);

  // Debounce search — clear immediately when emptied
  useEffect(() => {
    if (search === "") {
      setDebouncedSearch("");
      return;
    }
    const timer = setTimeout(() => setDebouncedSearch(search), DEBOUNCE_MS);
    return () => clearTimeout(timer);
  }, [search]);

  // Reset selection when modal opens
  useEffect(() => {
    if (isOpen) {
      setSelectedChainId(ALL_CHAINS_ID);
      setSearch("");
      setDebouncedSearch("");
    }
  }, [isOpen]);

  // Auto-load balances when a specific chain is selected
  useEffect(() => {
    if (selectedChainId && selectedChainId !== ALL_CHAINS_ID) {
      loadBalancesForChain(selectedChainId);
    }
  }, [selectedChainId, loadBalancesForChain]);

  // Load all chain balances when modal opens
  useEffect(() => {
    if (isOpen) {
      loadAllBalances();
    }
  }, [isOpen, loadAllBalances]);

  // Sort and filter tokens using debounced search
  const filteredTokens = useMemo(() => {
    let tokens: TokenAmount[];
    if (selectedChainId === ALL_CHAINS_ID) {
      tokens = Object.values(tokensByChain).flat();
    } else {
      tokens = tokensByChain[selectedChainId] ?? [];
    }

    const filtered = debouncedSearch
      ? tokens.filter(
          (t) =>
            t.symbol.toLowerCase().includes(debouncedSearch.toLowerCase()) ||
            t.name.toLowerCase().includes(debouncedSearch.toLowerCase())
        )
      : tokens;

    const sorted = [...filtered].sort((a, b) => {
      const aBalance = a.amount ?? BigInt(0);
      const bBalance = b.amount ?? BigInt(0);
      const aHasBalance = aBalance > BigInt(0);
      const bHasBalance = bBalance > BigInt(0);

      if (aHasBalance && !bHasBalance) return -1;
      if (!aHasBalance && bHasBalance) return 1;
      if (aHasBalance && bHasBalance) {
        const aUsd = Number(a.priceUSD ?? "0") * Number(formatUnits(aBalance, a.decimals));
        const bUsd = Number(b.priceUSD ?? "0") * Number(formatUnits(bBalance, b.decimals));
        return bUsd - aUsd;
      }
      // Zero-balance: sort by 24h volume descending (from extended API)
      const aVol = (a as unknown as Record<string, unknown>).volumeUSD24H as number | null | undefined ?? 0;
      const bVol = (b as unknown as Record<string, unknown>).volumeUSD24H as number | null | undefined ?? 0;
      return bVol - aVol;
    });

    return sorted;
  }, [selectedChainId, tokensByChain, debouncedSearch]);

  // Virtualizer
  const virtualizer = useVirtualizer({
    count: filteredTokens.length,
    getScrollElement: () => scrollRef.current,
    estimateSize: () => TOKEN_ITEM_HEIGHT,
    overscan: 5,
    getItemKey: (index) => `${filteredTokens[index].chainId}-${filteredTokens[index].address}-${index}`,
  });

  // Scroll to top when chain or search changes
  useEffect(() => {
    virtualizer.scrollToIndex(0);
  }, [selectedChainId, debouncedSearch, virtualizer]);

  const handleTokenClick = useCallback(
    (token: TokenAmount, chainId: number) => {
      onSelect(token, chainId);
      onClose();
    },
    [onSelect, onClose]
  );

  if (!isOpen) return null;

  const showAllChains = selectedChainId === ALL_CHAINS_ID;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      {/* Backdrop */}
      <div
        className="absolute inset-0 bg-black/50"
        onClick={onClose}
      />

      {/* Modal */}
      <div className="relative z-10 flex h-[500px] w-full max-w-xl overflow-hidden rounded-xl border border-zinc-200 bg-white shadow-xl dark:border-zinc-700 dark:bg-zinc-900">
        {/* Left: Chain list */}
        <div className={`flex w-[140px] flex-shrink-0 flex-col gap-0.5 overflow-y-auto border-r border-zinc-200 bg-zinc-50 p-2 dark:border-zinc-700 dark:bg-zinc-800/50 ${scrollbarClasses}`}>
          {/* All Chains option */}
          <button
            onClick={() => setSelectedChainId(ALL_CHAINS_ID)}
            className={`flex items-center gap-2 rounded-lg px-2 py-2 text-left text-xs font-medium transition-colors ${
              showAllChains
                ? "bg-blue-100 text-blue-700 dark:bg-blue-900/40 dark:text-blue-300"
                : "text-zinc-600 hover:bg-zinc-100 dark:text-zinc-400 dark:hover:bg-zinc-700"
            }`}
          >
            <span className="truncate">All Chains</span>
          </button>
          <div className="my-0.5 border-t border-zinc-200 dark:border-zinc-700" />
          {chains.map((chain) => (
            <button
              key={chain.id}
              onClick={() => setSelectedChainId(chain.id)}
              className={`flex items-center gap-2 rounded-lg px-2 py-2 text-left text-xs font-medium transition-colors ${
                selectedChainId === chain.id
                  ? "bg-blue-100 text-blue-700 dark:bg-blue-900/40 dark:text-blue-300"
                  : "text-zinc-600 hover:bg-zinc-100 dark:text-zinc-400 dark:hover:bg-zinc-700"
              }`}
            >
              {chain.logoURI && (
                <img
                  src={chain.logoURI}
                  alt={chain.name}
                  className="h-5 w-5 rounded-full"
                />
              )}
              <span className="truncate">{chain.name}</span>
            </button>
          ))}
        </div>

        {/* Right: Token list */}
        <div className="flex flex-1 flex-col">
          {/* Header */}
          <div className="flex items-center justify-between border-b border-zinc-200 px-4 py-3 dark:border-zinc-700">
            <div className="flex items-center gap-2">
              <h3 className="text-sm font-semibold text-black dark:text-white">
                Select Token
              </h3>
              {loadingBalancesChainId !== null && (
                <span className="text-xs text-zinc-400">Loading balances...</span>
              )}
            </div>
            <button
              onClick={onClose}
              className="text-zinc-400 hover:text-zinc-600 dark:hover:text-zinc-200"
            >
              &times;
            </button>
          </div>

          {/* Search */}
          <div className="border-b border-zinc-200 px-4 py-2 dark:border-zinc-700">
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search by name or symbol..."
              className="w-full rounded-lg border border-zinc-200 bg-zinc-50 px-3 py-2 text-sm text-black placeholder-zinc-400 focus:border-blue-500 focus:outline-none dark:border-zinc-700 dark:bg-zinc-800 dark:text-white"
            />
          </div>

          {/* Token list (virtualized) */}
          <div
            ref={scrollRef}
            className={`flex-1 overflow-y-auto ${scrollbarClasses}`}
          >
            {isLoading ? (
              <div className="flex flex-col">
                {Array.from({ length: 6 }).map((_, i) => (
                  <TokenListItemSkeleton key={i} />
                ))}
              </div>
            ) : filteredTokens.length === 0 ? (
              <div className="flex h-full items-center justify-center">
                <p className="text-sm text-zinc-400">No tokens found</p>
              </div>
            ) : (
              <div
                style={{
                  height: virtualizer.getTotalSize(),
                  width: "100%",
                  position: "relative",
                }}
              >
                {virtualizer.getVirtualItems().map((virtualItem) => {
                  const token = filteredTokens[virtualItem.index];
                  return (
                    <div
                      key={virtualItem.key}
                      style={{
                        position: "absolute",
                        top: 0,
                        left: 0,
                        width: "100%",
                        height: `${virtualItem.size}px`,
                        transform: `translateY(${virtualItem.start}px)`,
                      }}
                    >
                      <TokenListItem
                        token={token}
                        chainName={chainMap.get(token.chainId)?.name}
                        showChain={showAllChains}
                        onClick={handleTokenClick}
                      />
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
