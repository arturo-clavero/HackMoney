"use client";

import { useState, useEffect, useCallback } from "react";
import { useAppKitAccount } from "@reown/appkit/react";
import {
  useReadContract,
  useWriteContract,
  useWaitForTransactionReceipt,
  useWatchContractEvent,
  useEnsAddress,
} from "wagmi";
import { hardPegAbi } from "@/contracts/abis/hardPeg";
import { mediumPegAbi } from "@/contracts/abis/mediumPeg";
import { getContractAddress } from "@/contracts/addresses";
import { isAddress, type Address } from "viem";
import { normalize } from "viem/ens";
import { usePublicClient } from "wagmi";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { StaggerContainer, StaggerItem, motion } from "@/components/motion";

function truncateAddress(addr: string) {
  return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
}

type PegType = "hard" | "medium";

export function UserManagement({
  appId,
  pegType = "hard",
  chainId = 5042002,
}: {
  appId: bigint;
  pegType?: PegType;
  chainId?: number;
}) {
  const { address } = useAppKitAccount();
  const addresses = getContractAddress(chainId);
  const contractAddress =
    pegType === "medium" ? addresses?.mediumPeg : addresses?.hardPeg;
  const abi = pegType === "medium" ? mediumPegAbi : hardPegAbi;
  const publicClient = usePublicClient({ chainId });
  const [addInput, setAddInput] = useState("");
  const [users, setUsers] = useState<Address[]>([]);
  const [loadingUsers, setLoadingUsers] = useState(true);

  // ENS resolution: treat input as ENS if it contains a dot and isn't a raw address
  const trimmedInput = addInput.trim();
  const isEns = trimmedInput.includes(".") && !isAddress(trimmedInput);
  const isRawAddress = isAddress(trimmedInput);

  let ensName: string | undefined;
  try {
    ensName = isEns ? normalize(trimmedInput) : undefined;
  } catch {
    ensName = undefined;
  }

  const { data: ensResolvedAddress, isLoading: ensLoading } = useEnsAddress({
    name: ensName,
    chainId: 1,
    query: { enabled: !!ensName },
  });

  const resolvedAddress: Address | undefined = isRawAddress
    ? (trimmedInput as Address)
    : ensResolvedAddress ?? undefined;

  const { data: appConfig } = useReadContract({
    address: contractAddress,
    abi,
    functionName: "getAppConfig",
    args: [appId],
    chainId,
    query: { enabled: !!contractAddress },
  });

  const owner = appConfig?.owner as Address | undefined;
  const isOwner =
    !!address && !!owner && address.toLowerCase() === owner.toLowerCase();

  // Fetch past UserListUpdated events to build the user list
  const fetchUsers = useCallback(async () => {
    if (!publicClient || !contractAddress || !addresses) return;
    setLoadingUsers(true);
    try {
      const currentBlock = await publicClient.getBlockNumber();
      const deployBlock = addresses.deployBlock;
      const CHUNK = BigInt(9999);
      const allLogs: any[] = [];

      for (
        let from = deployBlock;
        from <= currentBlock;
        from += CHUNK + BigInt(1)
      ) {
        const to = from + CHUNK > currentBlock ? currentBlock : from + CHUNK;
        const logs = await publicClient.getContractEvents({
          address: contractAddress,
          abi,
          eventName: "UserListUpdated",
          args: { id: appId },
          fromBlock: from,
          toBlock: to,
        });
        allLogs.push(...logs);
      }
      const logs = allLogs;

      const userSet = new Set<string>();
      for (const log of logs) {
        const added = (log as any).args.added as Address[] | undefined;
        if (added) {
          for (const a of added) userSet.add(a.toLowerCase());
        }
      }
      setUsers(Array.from(userSet) as Address[]);
    } catch {
      // Silently fail — events may not be available
    } finally {
      setLoadingUsers(false);
    }
  }, [publicClient, contractAddress, appId, addresses, abi]);

  useEffect(() => {
    fetchUsers();
  }, [fetchUsers]);

  // Watch for new events and refresh the list
  useWatchContractEvent({
    address: contractAddress,
    abi,
    eventName: "UserListUpdated",
    chainId,
    onLogs: () => {
      fetchUsers();
    },
  });

  const {
    writeContract,
    isPending,
    data: txHash,
    error: writeError,
    reset,
  } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } =
    useWaitForTransactionReceipt({ hash: txHash });

  const inputInvalid =
    trimmedInput.length > 0 && !isRawAddress && !isEns;
  const ensNotFound =
    isEns && !ensLoading && !ensResolvedAddress && !!ensName;

  // Clear input and refresh user list after successful transaction
  useEffect(() => {
    if (isSuccess) {
      setAddInput("");
      fetchUsers();
    }
  }, [isSuccess, fetchUsers]);

  const handleSubmit = () => {
    if (!contractAddress || !resolvedAddress) return;
    writeContract({
      address: contractAddress,
      abi,
      functionName: "addUsers",
      args: [appId, [resolvedAddress]],
      chainId,
    });
  };

  if (!isOwner) {
    return (
      <Card>
        <CardHeader>
          <CardTitle>Users</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-muted-foreground">
            Only the instance owner can manage users.
          </p>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Users</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-5">
        <Alert>
          <AlertDescription className="text-xs">
            Add a wallet address or ENS name to grant permission to hold and
            interact with your stablecoin.
          </AlertDescription>
        </Alert>

        {/* Whitelisted users list */}
        <div>
          <Label className="mb-2">Whitelisted Users</Label>
          {loadingUsers ? (
            <p className="text-xs text-muted-foreground">Loading...</p>
          ) : users.length === 0 ? (
            <p className="text-xs text-muted-foreground">
              No users whitelisted yet.
            </p>
          ) : (
            <StaggerContainer className="flex flex-col gap-1">
              {users.map((user) => (
                <StaggerItem key={user}>
                  <div className="flex items-center justify-between rounded-lg bg-muted/50 px-3 py-2">
                    <span className="font-mono text-xs text-muted-foreground">
                      {user}
                    </span>
                  </div>
                </StaggerItem>
              ))}
            </StaggerContainer>
          )}
        </div>

        <div>
          <Label htmlFor="add-user" className="mb-1">
            Add User
          </Label>
          <Input
            id="add-user"
            type="text"
            value={addInput}
            onChange={(e) => {
              setAddInput(e.target.value);
              reset();
            }}
            placeholder="0x1234... or vitalik.eth"
          />
          {inputInvalid && (
            <p className="mt-1 text-xs text-destructive">
              Invalid address or ENS name
            </p>
          )}
          {ensLoading && (
            <p className="mt-1 text-xs text-muted-foreground">
              Resolving ENS name...
            </p>
          )}
          {ensNotFound && (
            <p className="mt-1 text-xs text-destructive">
              ENS name not found
            </p>
          )}
          {isEns && ensResolvedAddress && (
            <p className="mt-1 text-xs text-green-600 dark:text-green-400">
              Resolved: {ensResolvedAddress}
            </p>
          )}
        </div>

        {writeError && (
          <p className="text-xs text-destructive">
            {writeError.message.length > 200
              ? writeError.message.slice(0, 200) + "..."
              : writeError.message}
          </p>
        )}

        {isSuccess && (
          <p className="text-xs text-green-600 dark:text-green-400">
            User added successfully.
          </p>
        )}

        <motion.div whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.98 }}>
          <Button
            onClick={handleSubmit}
            disabled={
              !resolvedAddress || isPending || isConfirming || ensLoading
            }
            className="w-full"
          >
            {isPending
              ? "Confirm in wallet..."
              : isConfirming
                ? "Adding..."
                : "Add User"}
          </Button>
        </motion.div>
      </CardContent>
    </Card>
  );
}
