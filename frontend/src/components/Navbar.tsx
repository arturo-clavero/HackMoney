"use client";

import Link from "next/link";
import { useAppKit, useAppKitAccount } from "@reown/appkit/react";
import { Button } from "@/components/ui/button";
import { motion } from "@/components/motion";

export function Navbar() {
  const { open } = useAppKit();
  const { address, isConnected } = useAppKitAccount();

  return (
    <motion.nav
      initial={{ opacity: 0, y: -10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3 }}
      className="sticky top-0 z-50 flex items-center justify-between border-b border-border bg-background/80 px-6 py-3 backdrop-blur"
    >
      <Link href="/" className="text-lg font-bold">
        HackMoney
      </Link>
      {isConnected ? (
        <Button
          variant="secondary"
          size="sm"
          onClick={() => open({ view: "Account" })}
          className="font-mono"
        >
          {address?.slice(0, 6)}...{address?.slice(-4)}
        </Button>
      ) : (
        <Button size="sm" onClick={() => open()}>
          Connect
        </Button>
      )}
    </motion.nav>
  );
}
