export const Actions = {
  MINT: BigInt(1) << BigInt(0),
  HOLD: BigInt(1) << BigInt(1),
  TRANSFER_DEST: BigInt(1) << BigInt(2),
} as const;
