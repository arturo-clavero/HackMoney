"use client";

import { useState, useEffect } from "react";
import { useAppKitAccount } from "@reown/appkit/react";
import {
  useReadContract,
  useWriteContract,
  useWaitForTransactionReceipt,
} from "wagmi";
import { hardPegAbi } from "@/contracts/abis/hardPeg";
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

export function VaultOperations({ appId }: { appId: bigint }) {
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
              <DepositFlow appId={appId} />
            </TabsContent>
            <TabsContent value="mint" className="mt-0">
              <MintTab appId={appId} />
            </TabsContent>
            <TabsContent value="redeem" className="mt-0">
              <RedeemTab appId={appId} />
            </TabsContent>
            <TabsContent value="withdraw" className="mt-0">
              <WithdrawTab appId={appId} />
            </TabsContent>
          </div>
        </Tabs>
      </CardContent>
    </Card>
  );
}

// ─── Mint Tab ────────────────────────────────────────────────────────────────

const ARC_CHAIN_ID = 5042002;

function MintTab({ appId }: { appId: bigint }) {
  const { address } = useAppKitAccount();
  const addresses = getContractAddress(ARC_CHAIN_ID);
  const contractAddress = addresses?.hardPeg;

  const [recipient, setRecipient] = useState("");
  const [amount, setAmount] = useState("");

  const { data: vaultBalance, refetch: refetchVault } = useReadContract({
    address: contractAddress,
    abi: hardPegAbi,
    functionName: "getVaultBalance",
    args: [appId, address as Address],
    chainId: ARC_CHAIN_ID,
    query: { enabled: !!contractAddress && !!address },
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
    if (isSuccess) refetchVault();
  }, [isSuccess, refetchVault]);

  const handleMint = () => {
    if (!contractAddress) return;
    const to = (recipient.trim() || address) as Address;
    const rawAmount = amount === "max" ? maxUint256 : parseUnits(amount, 18);
    writeContract({
      address: contractAddress,
      abi: hardPegAbi,
      functionName: "mint",
      args: [appId, to, rawAmount],
      chainId: ARC_CHAIN_ID,
    });
  };

  const isWorking = isPending || isConfirming;

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
          id="mint-amount"
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

function RedeemTab({ appId }: { appId: bigint }) {
  const { address } = useAppKitAccount();
  const addresses = getContractAddress(ARC_CHAIN_ID);
  const contractAddress = addresses?.hardPeg;

  const [amount, setAmount] = useState("");

  // Get coin address from app config
  const { data: appConfig } = useReadContract({
    address: contractAddress,
    abi: hardPegAbi,
    functionName: "getAppConfig",
    args: [appId],
    chainId: ARC_CHAIN_ID,
    query: { enabled: !!contractAddress },
  });

  const coinAddress = appConfig?.coin as Address | undefined;

  // Get user's coin balance
  const { data: coinBalance, refetch: refetchCoin } = useReadContract({
    address: coinAddress,
    abi: erc20Abi,
    functionName: "balanceOf",
    args: [address as Address],
    chainId: ARC_CHAIN_ID,
    query: { enabled: !!coinAddress && !!address },
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
    writeContract({
      address: contractAddress!,
      abi: hardPegAbi,
      functionName: "redeam",
      args: [coinAddress, rawAmount],
      chainId: ARC_CHAIN_ID,
    });
  };

  const isWorking = isPending || isConfirming;

  return (
    <div className="flex flex-col gap-4">
      <Alert>
        <AlertDescription className="text-xs">
          Redeeming burns your stablecoins and returns a pro-rata basket of all
          collateral in the pool.
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

function WithdrawTab({ appId }: { appId: bigint }) {
  const { address } = useAppKitAccount();
  const addresses = getContractAddress(ARC_CHAIN_ID);
  const contractAddress = addresses?.hardPeg;

  const [amount, setAmount] = useState("");

  const { data: vaultBalance, refetch: refetchVault } = useReadContract({
    address: contractAddress,
    abi: hardPegAbi,
    functionName: "getVaultBalance",
    args: [appId, address as Address],
    chainId: ARC_CHAIN_ID,
    query: { enabled: !!contractAddress && !!address },
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
    if (isSuccess) refetchVault();
  }, [isSuccess, refetchVault]);

  const handleWithdraw = () => {
    if (!contractAddress || !amount) return;
    const valueAmount =
      amount === "max" ? maxUint256 : BigInt(amount);
    writeContract({
      address: contractAddress,
      abi: hardPegAbi,
      functionName: "withdrawCollateral",
      args: [appId, valueAmount],
      chainId: ARC_CHAIN_ID,
    });
  };

  const isWorking = isPending || isConfirming;

  return (
    <div className="flex flex-col gap-4">
      <Alert>
        <AlertDescription className="text-xs">
          Withdraw returns a pro-rata basket of collateral from the pool,
          proportional to the value units withdrawn.
        </AlertDescription>
      </Alert>

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
        <Button onClick={handleWithdraw} disabled={!amount || isWorking} className="w-full">
          {isPending
            ? "Confirm in wallet..."
            : isConfirming
              ? "Withdrawing..."
              : "Withdraw"}
        </Button>
      </motion.div>
    </div>
  );
}
