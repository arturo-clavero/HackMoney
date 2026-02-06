"use client";

import { useState, useMemo, useEffect } from "react";
import { formatUnits } from "viem";
import type { ExtendedChain, TokenAmount } from "@lifi/sdk";

interface Props {
  isOpen: boolean;
  onClose: () => void;
  onSelect: (token: TokenAmount, chainId: number) => void;
  chains: ExtendedChain[];
  tokensByChain: Record<number, TokenAmount[]>;
  isLoading: boolean;
  connectedChainId?: number;
}

export function TokenSelectorModal({
  isOpen,
  onClose,
  onSelect,
  chains,
  tokensByChain,
  isLoading,
  connectedChainId,
}: Props) {
  const [selectedChainId, setSelectedChainId] = useState<number | null>(null);
  const [search, setSearch] = useState("");

  // Default to connected chain when modal opens
  useEffect(() => {
    if (isOpen) {
      setSelectedChainId(connectedChainId ?? chains[0]?.id ?? null);
      setSearch("");
    }
  }, [isOpen, connectedChainId, chains]);

  // Sort and filter tokens for the selected chain
  const filteredTokens = useMemo(() => {
    if (!selectedChainId) return [];
    const tokens = tokensByChain[selectedChainId] ?? [];

    const filtered = search
      ? tokens.filter(
          (t) =>
            t.symbol.toLowerCase().includes(search.toLowerCase()) ||
            t.name.toLowerCase().includes(search.toLowerCase())
        )
      : tokens;

    // Sort: tokens with balance first (descending), then zero-balance alphabetically
    return [...filtered].sort((a, b) => {
      const aBalance = a.amount ?? BigInt(0);
      const bBalance = b.amount ?? BigInt(0);
      const aHasBalance = aBalance > BigInt(0);
      const bHasBalance = bBalance > BigInt(0);

      if (aHasBalance && !bHasBalance) return -1;
      if (!aHasBalance && bHasBalance) return 1;
      if (aHasBalance && bHasBalance) {
        // Compare by USD value if available, otherwise by raw amount
        const aUsd = Number(a.priceUSD ?? "0") * Number(formatUnits(aBalance, a.decimals));
        const bUsd = Number(b.priceUSD ?? "0") * Number(formatUnits(bBalance, b.decimals));
        return bUsd - aUsd;
      }
      return a.symbol.localeCompare(b.symbol);
    });
  }, [selectedChainId, tokensByChain, search]);

  if (!isOpen) return null;

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
        <div className="flex w-[140px] flex-shrink-0 flex-col gap-0.5 overflow-y-auto border-r border-zinc-200 bg-zinc-50 p-2 dark:border-zinc-700 dark:bg-zinc-800/50">
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
            <h3 className="text-sm font-semibold text-black dark:text-white">
              Select Token
            </h3>
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

          {/* Token list */}
          <div className="flex-1 overflow-y-auto">
            {isLoading ? (
              <div className="flex h-full items-center justify-center">
                <p className="text-sm text-zinc-400">Loading tokens...</p>
              </div>
            ) : filteredTokens.length === 0 ? (
              <div className="flex h-full items-center justify-center">
                <p className="text-sm text-zinc-400">No tokens found</p>
              </div>
            ) : (
              filteredTokens.map((token) => {
                const balance = token.amount ?? BigInt(0);
                const hasBalance = balance > BigInt(0);
                return (
                  <button
                    key={token.address}
                    onClick={() => {
                      onSelect(token, selectedChainId!);
                      onClose();
                    }}
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
              })
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
