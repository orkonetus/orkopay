import type { Address, Hash, Hex } from "viem";

export type InvoiceStatus = "pending" | "paid" | "underpaid" | "refunded" | "expired";

/** Checkout invoice created by the OrkoNet API before the customer pays. */
export interface Invoice {
  /** keccak256 of the invoice UUID; passed to OrkoPay.deposit as `orderId`. */
  orderId: Hex;
  merchantAddress: Address;
  /** 0x000…000 for ETH, otherwise the ERC-20 address. */
  asset: Address;
  /** Amount due in the asset's base units. */
  amount: bigint;
  status: InvoiceStatus;
}

/** Normalised on-chain facts about a payment. */
export interface PaymentRecord {
  orderId: Hex;
  customer: Address;
  merchant: Address;
  asset: Address;
  gross: bigint;
  fee: bigint;
  txHash: Hash;
  blockNumber: bigint;
}

export interface RefundRecord {
  orderId: Hex;
  customer: Address;
  asset: Address;
  amount: bigint;
  txHash: Hash;
  blockNumber: bigint;
}

export type UnderpaidReason = "amount_short" | "asset_mismatch";

/** Persistence used by the event handlers. Implemented by PgStore. */
export interface InvoiceStore {
  getInvoice(orderId: Hex): Promise<Invoice | null>;
  markPaid(payment: PaymentRecord): Promise<void>;
  markUnderpaid(payment: PaymentRecord, reason: UnderpaidReason): Promise<void>;
  markRefunded(refund: RefundRecord): Promise<void>;
}
