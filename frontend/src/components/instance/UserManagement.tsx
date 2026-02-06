"use client";

import { useState, useEffect, useCallback } from "react";
import { useAppKitAccount } from "@reown/appkit/react";
import {
  useReadContract,
  useWriteContract,
  useWaitForTransactionReceipt,
  useWatchContractEvent,
} from "wagmi";
import { useQueryClient } from "@tanstack/react-query";
import { hardPegAbi } from "@/contracts/abis/hardPeg";
import { getContractAddress } from "@/contracts/addresses";
import { isAddress, type Address, type Log } from "viem";
import { usePublicClient } from "wagmi";

function truncateAddress(addr: string) {
  return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
}

export function UserManagement({ appId }: { appId: bigint }) {
  const { caipAddress, address } = useAppKitAccount();
  const chainId = caipAddress ? parseInt(caipAddress.split(":")[1]) : undefined;
  const addresses = chainId ? getContractAddress(chainId) : null;
  const contractAddress = addresses?.hardPeg;
  const publicClient = usePublicClient();
  const queryClient = useQueryClient();

  const [addInput, setAddInput] = useState("");
  const [users, setUsers] = useState<Address[]>([]);
  const [loadingUsers, setLoadingUsers] = useState(true);

  const { data: appConfig } = useReadContract({
    address: contractAddress,
    abi: hardPegAbi,
    functionName: "getAppConfig",
    args: [appId],
    query: { enabled: !!contractAddress },
  });

  const owner = appConfig?.owner as Address | undefined;
  const isOwner =
    !!address && !!owner && address.toLowerCase() === owner.toLowerCase();

  // Fetch past UserListUpdated events to build the user list
  const fetchUsers = useCallback(async () => {
    if (!publicClient || !contractAddress) return;
    setLoadingUsers(true);
    try {
      const logs = await publicClient.getContractEvents({
        address: contractAddress,
        abi: hardPegAbi,
        eventName: "UserListUpdated",
        args: { id: appId },
        fromBlock: BigInt(0),
      });

      const userSet = new Set<string>();
      for (const log of logs) {
        const added = (log as any).args.added as Address[] | undefined;
        const removed = (log as any).args.removed as Address[] | undefined;
        if (added) {
          for (const a of added) userSet.add(a.toLowerCase());
        }
        if (removed) {
          for (const r of removed) userSet.delete(r.toLowerCase());
        }
      }
      setUsers(Array.from(userSet) as Address[]);
    } catch {
      // Silently fail — events may not be available
    } finally {
      setLoadingUsers(false);
    }
  }, [publicClient, contractAddress, appId]);

  useEffect(() => {
    fetchUsers();
  }, [fetchUsers]);

  // Watch for new events and refresh the list
  useWatchContractEvent({
    address: contractAddress,
    abi: hardPegAbi,
    eventName: "UserListUpdated",
    onLogs: () => {
      fetchUsers();
    },
  });

  const { writeContract, isPending, data: txHash, error: writeError, reset } =
    useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash: txHash,
  });

  const parseAddresses = useCallback((input: string): Address[] => {
    return input
      .split(/[\n,]+/)
      .map((s) => s.trim())
      .filter((s) => s.length > 0 && isAddress(s)) as Address[];
  }, []);

  const addAddresses = parseAddresses(addInput);

  const invalidAdd = addInput
    .split(/[\n,]+/)
    .map((s) => s.trim())
    .filter((s) => s.length > 0 && !isAddress(s));

  // Clear input after success (event watcher handles list refresh)
  useEffect(() => {
    if (isSuccess) {
      setAddInput("");
    }
  }, [isSuccess]);

  const handleSubmit = () => {
    if (!contractAddress || addAddresses.length === 0) return;
    writeContract({
      address: contractAddress,
      abi: hardPegAbi,
      functionName: "updateUserList",
      args: [appId, addAddresses, []],
    });
  };

  if (!isOwner) {
    return (
      <div className="rounded-xl border border-zinc-200 dark:border-zinc-800">
        <div className="border-b border-zinc-200 px-5 py-3 dark:border-zinc-800">
          <h2 className="font-semibold text-black dark:text-white">Users</h2>
        </div>
        <div className="p-5">
          <p className="text-sm text-zinc-500">
            Only the instance owner can manage users.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="rounded-xl border border-zinc-200 dark:border-zinc-800">
      <div className="border-b border-zinc-200 px-5 py-3 dark:border-zinc-800">
        <h2 className="font-semibold text-black dark:text-white">Users</h2>
      </div>
      <div className="flex flex-col gap-5 p-5">
        <div className="rounded-lg bg-blue-50 p-3 text-xs text-blue-800 dark:bg-blue-950 dark:text-blue-200">
          Add wallet addresses to grant them permission to hold and interact
          with your stablecoin.
        </div>

        {/* Whitelisted users list */}
        <div>
          <label className="mb-2 block text-sm font-medium text-black dark:text-white">
            Whitelisted Users
          </label>
          {loadingUsers ? (
            <p className="text-xs text-zinc-400">Loading...</p>
          ) : users.length === 0 ? (
            <p className="text-xs text-zinc-400">No users whitelisted yet.</p>
          ) : (
            <div className="flex flex-col gap-1">
              {users.map((user) => (
                <div
                  key={user}
                  className="flex items-center justify-between rounded-lg bg-zinc-50 px-3 py-2 dark:bg-zinc-800/50"
                >
                  <span className="font-mono text-xs text-zinc-600 dark:text-zinc-300">
                    {user}
                  </span>
                </div>
              ))}
            </div>
          )}
        </div>

        <div>
          <label className="mb-1 block text-sm font-medium text-black dark:text-white">
            Add Users
          </label>
          <textarea
            value={addInput}
            onChange={(e) => setAddInput(e.target.value)}
            placeholder="0x1234..., 0xabcd...&#10;One per line or comma-separated"
            rows={3}
            className="w-full rounded-lg border border-zinc-200 bg-white px-3 py-2 text-sm text-black placeholder-zinc-400 focus:border-blue-500 focus:outline-none dark:border-zinc-700 dark:bg-zinc-900 dark:text-white"
          />
          {invalidAdd.length > 0 && (
            <p className="mt-1 text-xs text-red-500">
              Invalid: {invalidAdd.join(", ")}
            </p>
          )}
          {addAddresses.length > 0 && (
            <p className="mt-1 text-xs text-zinc-400">
              {addAddresses.length} valid address
              {addAddresses.length > 1 ? "es" : ""}
            </p>
          )}
        </div>

        {writeError && (
          <p className="text-xs text-red-500">
            {writeError.message.length > 200
              ? writeError.message.slice(0, 200) + "..."
              : writeError.message}
        </p>
        )}

        {isSuccess && (
          <p className="text-xs text-green-600 dark:text-green-400">
            Users updated successfully.
          </p>
        )}

        <button
          onClick={handleSubmit}
          disabled={addAddresses.length === 0 || isPending || isConfirming}
          className="rounded-lg bg-blue-600 px-5 py-2.5 text-sm font-medium text-white transition-colors hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {isPending
            ? "Confirm in wallet..."
            : isConfirming
              ? "Adding..."
              : "Add Users"}
        </button>
      </div>
    </div>
  );
}
