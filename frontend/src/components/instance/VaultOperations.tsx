"use client";

import { useState, useEffect } from "react";
import { useAppKitAccount } from "@reown/appkit/react";
import {
  useReadContract,
  useWriteContract,
  useWaitForTransactionReceipt,
} from "wagmi";
import { hardPegAbi } from "@/contracts/abis/hardPeg";
import { mediumPegAbi } from "@/contracts/abis/mediumPeg";
import { getContractAddress } from "@/contracts/addresses";
import {
  erc20Abi,
  formatUnits,
  parseUnits,
  type Address,
  maxUint256,
} from "viem";
import { DepositFlow } from "./DepositFlow";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import {
  Tabs,
  TabsList,
  TabsTrigger,
  TabsContent,
} from "@/components/ui/tabs";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { motion } from "@/components/motion";

type PegType = "hard" | "medium";

export function VaultOperations({
  appId,
  pegType = "hard",
  chainId = 5042002,
}: {
  appId: bigint;
  pegType?: PegType;
  chainId?: number;
}) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>Vault Operations</CardTitle>
      </CardHeader>
      <CardContent className="p-0">
        <Tabs defaultValue="deposit">
          <TabsList className="w-full rounded-none border-b bg-transparent px-5">
            <TabsTrigger value="deposit" className="flex-1">
              Deposit
            </TabsTrigger>
            <TabsTrigger value="mint" className="flex-1">
              Mint
            </TabsTrigger>
            <TabsTrigger value="redeem" className="flex-1">
              Redeem
            </TabsTrigger>
            <TabsTrigger value="withdraw" className="flex-1">
              Withdraw
            </TabsTrigger>
          </TabsList>
          <div className="p-5">
            <TabsContent value="deposit" className="mt-0">
              <DepositFlow appId={appId} pegType={pegType} chainId={chainId} />
            </TabsContent>
            <TabsContent value="mint" className="mt-0">
              <MintTab appId={appId} pegType={pegType} chainId={chainId} />
            </TabsContent>
            <TabsContent value="redeem" className="mt-0">
              <RedeemTab appId={appId} pegType={pegType} chainId={chainId} />
            </TabsContent>
            <TabsContent value="withdraw" className="mt-0">
              <WithdrawTab appId={appId} pegType={pegType} chainId={chainId} />
            </TabsContent>
          </div>
        </Tabs>
      </CardContent>
    </Card>
  );
}

// ─── Mint Tab ────────────────────────────────────────────────────────────────

function MintTab({
  appId,
  pegType,
  chainId,
}: {
  appId: bigint;
  pegType: PegType;
  chainId: number;
}) {
  const { address } = useAppKitAccount();
  const addresses = getContractAddress(chainId);
  const contractAddress =
    pegType === "medium" ? addresses?.mediumPeg : addresses?.hardPeg;
  const abi = pegType === "medium" ? mediumPegAbi : hardPegAbi;

  const [recipient, setRecipient] = useState("");
  const [amount, setAmount] = useState("");

  // HardPeg: vault balance
  const { data: vaultBalance, refetch: refetchVault } = useReadContract({
    address: contractAddress,
    abi: hardPegAbi,
    functionName: "getVaultBalance",
    args: [appId, address as Address],
    chainId,
    query: { enabled: pegType === "hard" && !!contractAddress && !!address, staleTime: 30_000 },
  });

  // MediumPeg: position
  const { data: position, refetch: refetchPosition } = useReadContract({
    address: contractAddress,
    abi: mediumPegAbi,
    functionName: "getPosition",
    args: [appId, address as Address],
    chainId,
    query: { enabled: pegType === "medium" && !!contractAddress && !!address, staleTime: 30_000 },
  });

  const {
    writeContract,
    isPending,
    data: txHash,
    error: writeError,
  } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } =
    useWaitForTransactionReceipt({ hash: txHash });

  useEffect(() => {
    if (isSuccess) {
      if (pegType === "hard") refetchVault();
      else refetchPosition();
    }
  }, [isSuccess, pegType, refetchVault, refetchPosition]);

  const handleMint = () => {
    if (!contractAddress) return;
    const to = (recipient.trim() || address) as Address;

    if (pegType === "hard") {
      const rawAmount = amount === "max" ? maxUint256 : parseUnits(amount, 18);
      writeContract({
        address: contractAddress,
        abi: hardPegAbi,
        functionName: "mint",
        args: [appId, to, rawAmount],
        chainId,
      });
    } else {
      // MediumPeg mint uses raw amount (18 decimals for the stablecoin)
      const rawAmount = parseUnits(amount, 18);
      writeContract({
        address: contractAddress,
        abi: mediumPegAbi,
        functionName: "mint",
        args: [appId, to, rawAmount],
        chainId,
      });
    }
  };

  const isWorking = isPending || isConfirming;

  const balanceDisplay =
    pegType === "hard"
      ? vaultBalance !== undefined
        ? `Vault balance: ${vaultBalance.toString()} value units`
        : undefined
      : position
        ? `Available principal: ${formatUnits((position as [bigint, bigint])[0], 6)} USDC`
        : undefined;

  return (
    <div className="flex flex-col gap-4">
      <div>
        <Label htmlFor="mint-recipient" className="mb-1">
          Recipient
        </Label>
        <Input
          id="mint-recipient"
          type="text"
          value={recipient}
          onChange={(e) => setRecipient(e.target.value)}
          placeholder={address ?? "0x..."}
        />
        <p className="mt-1 text-xs text-muted-foreground">
          Leave blank to mint to your own wallet.
        </p>
      </div>

      <div>
        <div className="mb-1 flex items-center justify-between">
          <Label htmlFor="mint-amount">Amount</Label>
          {pegType === "hard" && (
            <Button
              variant="link"
              size="sm"
              className="h-auto p-0 text-xs"
              onClick={() => setAmount("max")}
            >
              Max
            </Button>
          )}
        </div>
        <Input
          id="mint-amount"
          type="text"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          placeholder="0.0"
        />
        {balanceDisplay && (
          <p className="mt-1 text-xs text-muted-foreground">
            {balanceDisplay}
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
          Mint successful!
        </p>
      )}

      <motion.div whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.98 }}>
        <Button onClick={handleMint} disabled={!amount || isWorking} className="w-full">
          {isPending
            ? "Confirm in wallet..."
            : isConfirming
              ? "Minting..."
              : "Mint"}
        </Button>
      </motion.div>
    </div>
  );
}

// ─── Redeem Tab ──────────────────────────────────────────────────────────────

function RedeemTab({
  appId,
  pegType,
  chainId,
}: {
  appId: bigint;
  pegType: PegType;
  chainId: number;
}) {
  const { address } = useAppKitAccount();
  const addresses = getContractAddress(chainId);
  const contractAddress =
    pegType === "medium" ? addresses?.mediumPeg : addresses?.hardPeg;
  const abi = pegType === "medium" ? mediumPegAbi : hardPegAbi;

  const [amount, setAmount] = useState("");

  const { data: appConfig } = useReadContract({
    address: contractAddress,
    abi,
    functionName: "getAppConfig",
    args: [appId],
    chainId,
    query: { enabled: !!contractAddress, staleTime: 30_000 },
  });

  const coinAddress = appConfig?.coin as Address | undefined;

  const { data: coinBalance, refetch: refetchCoin } = useReadContract({
    address: coinAddress,
    abi: erc20Abi,
    functionName: "balanceOf",
    args: [address as Address],
    chainId,
    query: { enabled: !!coinAddress && !!address, staleTime: 30_000 },
  });

  const {
    writeContract,
    isPending,
    data: txHash,
    error: writeError,
  } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } =
    useWaitForTransactionReceipt({ hash: txHash });

  useEffect(() => {
    if (isSuccess) refetchCoin();
  }, [isSuccess, refetchCoin]);

  const handleRedeem = () => {
    if (!coinAddress || !amount) return;
    const rawAmount = parseUnits(amount, 18);

    if (pegType === "hard") {
      writeContract({
        address: contractAddress!,
        abi: hardPegAbi,
        functionName: "redeam",
        args: [coinAddress, rawAmount],
        chainId,
      });
    } else {
      writeContract({
        address: contractAddress!,
        abi: mediumPegAbi,
        functionName: "redeem",
        args: [coinAddress, rawAmount],
        chainId,
      });
    }
  };

  const isWorking = isPending || isConfirming;

  const helpText =
    pegType === "hard"
      ? "Redeeming burns your stablecoins and returns a pro-rata basket of all collateral in the pool."
      : "Redeeming burns your stablecoins and returns USDC at 1:1 from the vault.";

  return (
    <div className="flex flex-col gap-4">
      <Alert>
        <AlertDescription className="text-xs">
          {helpText}
        </AlertDescription>
      </Alert>

      <div>
        <Label htmlFor="redeem-amount" className="mb-1">
          Amount
        </Label>
        <Input
          id="redeem-amount"
          type="text"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          placeholder="0.0"
        />
        {coinBalance !== undefined && (
          <p className="mt-1 text-xs text-muted-foreground">
            Coin balance: {formatUnits(coinBalance, 18)}
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
          Redeem successful!
        </p>
      )}

      <motion.div whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.98 }}>
        <Button onClick={handleRedeem} disabled={!amount || isWorking} className="w-full">
          {isPending
            ? "Confirm in wallet..."
            : isConfirming
              ? "Redeeming..."
              : "Redeem"}
        </Button>
      </motion.div>
    </div>
  );
}

// ─── Withdraw Tab ────────────────────────────────────────────────────────────

function WithdrawTab({
  appId,
  pegType,
  chainId,
}: {
  appId: bigint;
  pegType: PegType;
  chainId: number;
}) {
  const { address } = useAppKitAccount();
  const addresses = getContractAddress(chainId);
  const contractAddress =
    pegType === "medium" ? addresses?.mediumPeg : addresses?.hardPeg;

  const [amount, setAmount] = useState("");

  // HardPeg: vault balance
  const { data: vaultBalance, refetch: refetchVault } = useReadContract({
    address: contractAddress,
    abi: hardPegAbi,
    functionName: "getVaultBalance",
    args: [appId, address as Address],
    chainId,
    query: { enabled: pegType === "hard" && !!contractAddress && !!address, staleTime: 30_000 },
  });

  // MediumPeg: position (for display)
  const { data: position, refetch: refetchPosition } = useReadContract({
    address: contractAddress,
    abi: mediumPegAbi,
    functionName: "getPosition",
    args: [appId, address as Address],
    chainId,
    query: { enabled: pegType === "medium" && !!contractAddress && !!address, staleTime: 30_000 },
  });

  const {
    writeContract,
    isPending,
    data: txHash,
    error: writeError,
  } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } =
    useWaitForTransactionReceipt({ hash: txHash });

  useEffect(() => {
    if (isSuccess) {
      if (pegType === "hard") refetchVault();
      else refetchPosition();
    }
  }, [isSuccess, pegType, refetchVault, refetchPosition]);

  const handleWithdraw = () => {
    if (!contractAddress) return;

    if (pegType === "hard") {
      if (!amount) return;
      const valueAmount =
        amount === "max" ? maxUint256 : BigInt(amount);
      writeContract({
        address: contractAddress,
        abi: hardPegAbi,
        functionName: "withdrawCollateral",
        args: [appId, valueAmount],
        chainId,
      });
    } else {
      // MediumPeg: withdrawCollateral(appId) — no amount, withdraws all
      writeContract({
        address: contractAddress,
        abi: mediumPegAbi,
        functionName: "withdrawCollateral",
        args: [appId],
        chainId,
      });
    }
  };

  const isWorking = isPending || isConfirming;

  const helpText =
    pegType === "hard"
      ? "Withdraw returns a pro-rata basket of collateral from the pool, proportional to the value units withdrawn."
      : "Withdraw redeems all your vault shares and returns the underlying USDC plus accumulated yield. You must have no outstanding debt.";

  return (
    <div className="flex flex-col gap-4">
      <Alert>
        <AlertDescription className="text-xs">
          {helpText}
        </AlertDescription>
      </Alert>

      {pegType === "hard" ? (
        <div>
          <div className="mb-1 flex items-center justify-between">
            <Label htmlFor="withdraw-amount">Amount (value units)</Label>
            <Button
              variant="link"
              size="sm"
              className="h-auto p-0 text-xs"
              onClick={() => setAmount("max")}
            >
              Max
            </Button>
          </div>
          <Input
            id="withdraw-amount"
            type="text"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="0.0"
          />
          {vaultBalance !== undefined && (
            <p className="mt-1 text-xs text-muted-foreground">
              Vault balance: {vaultBalance.toString()} value units
            </p>
          )}
        </div>
      ) : (
        position && (
          <div className="text-sm text-muted-foreground">
            <p>
              Shares: {formatUnits((position as [bigint, bigint])[1], 6)}
            </p>
            <p>
              Principal: {formatUnits((position as [bigint, bigint])[0], 6)}{" "}
              USDC
            </p>
          </div>
        )
      )}

      {writeError && (
        <p className="text-xs text-destructive">
          {writeError.message.length > 200
            ? writeError.message.slice(0, 200) + "..."
            : writeError.message}
        </p>
      )}

      {isSuccess && (
        <p className="text-xs text-green-600 dark:text-green-400">
          Withdrawal successful!
        </p>
      )}

      <motion.div whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.98 }}>
        <Button
          onClick={handleWithdraw}
          disabled={pegType === "hard" ? !amount || isWorking : isWorking}
          className="w-full"
        >
          {isPending
            ? "Confirm in wallet..."
            : isConfirming
              ? "Withdrawing..."
              : pegType === "medium"
                ? "Withdraw All"
                : "Withdraw"}
        </Button>
      </motion.div>
    </div>
  );
}
