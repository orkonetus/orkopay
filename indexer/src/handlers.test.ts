import { describe, expect, it, beforeEach } from "vitest";
import { pino } from "pino";
import type { Hex } from "viem";
import { handleOrderRefunded, handlePaymentReceived } from "./handlers.js";
import type {
  Invoice,
  InvoiceStore,
  PaymentRecord,
  RefundRecord,
  UnderpaidReason,
} from "./types.js";

const ETH = "0x0000000000000000000000000000000000000000";
const USDC = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";
const NORTHWIND = "0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf";
const ALICE = "0x2B5AD5c4795c026514f8317c7a215E218DcCD6cF";
const ORDER: Hex = "0x9c22ff5f21f0b81b113e63f7db6da94fedef11b2119b4088b89664fb9a3cb658";

class MemoryStore implements InvoiceStore {
  invoices = new Map<Hex, Invoice>();
  underpaidReason: UnderpaidReason | null = null;

  async getInvoice(orderId: Hex) {
    return this.invoices.get(orderId) ?? null;
  }
  async markPaid(p: PaymentRecord) {
    const inv = this.invoices.get(p.orderId);
    if (inv && inv.status === "pending") inv.status = "paid";
  }
  async markUnderpaid(p: PaymentRecord, reason: UnderpaidReason) {
    const inv = this.invoices.get(p.orderId);
    if (inv && inv.status === "pending") inv.status = "underpaid";
    this.underpaidReason = reason;
  }
  async markRefunded(r: RefundRecord) {
    const inv = this.invoices.get(r.orderId);
    if (inv) inv.status = "refunded";
  }
}

const log = pino({ level: "silent" });

function payment(overrides: Partial<PaymentRecord> = {}): PaymentRecord {
  return {
    orderId: ORDER,
    customer: ALICE,
    merchant: NORTHWIND,
    asset: ETH,
    gross: 10n ** 18n,
    fee: 2n * 10n ** 16n,
    txHash: "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    blockNumber: 1_000n,
    ...overrides,
  };
}

describe("handlePaymentReceived", () => {
  let store: MemoryStore;

  beforeEach(() => {
    store = new MemoryStore();
    store.invoices.set(ORDER, {
      orderId: ORDER,
      merchantAddress: NORTHWIND,
      asset: ETH,
      amount: 10n ** 18n,
      status: "pending",
    });
  });

  it("marks an exact payment as paid", async () => {
    await handlePaymentReceived(store, payment(), log);
    expect(store.invoices.get(ORDER)?.status).toBe("paid");
  });

  it("accepts overpayment", async () => {
    await handlePaymentReceived(store, payment({ gross: 2n * 10n ** 18n }), log);
    expect(store.invoices.get(ORDER)?.status).toBe("paid");
  });

  it("flags a short payment", async () => {
    await handlePaymentReceived(store, payment({ gross: 1n }), log);
    expect(store.invoices.get(ORDER)?.status).toBe("underpaid");
    expect(store.underpaidReason).toBe("amount_short");
  });

  it("flags payment in the wrong asset", async () => {
    await handlePaymentReceived(store, payment({ asset: USDC }), log);
    expect(store.invoices.get(ORDER)?.status).toBe("underpaid");
    expect(store.underpaidReason).toBe("asset_mismatch");
  });

  it("ignores unknown invoices", async () => {
    const other: Hex = "0x1111111111111111111111111111111111111111111111111111111111111111";
    await handlePaymentReceived(store, payment({ orderId: other }), log);
    expect(store.invoices.get(ORDER)?.status).toBe("pending");
  });

  it("does not overwrite a settled invoice", async () => {
    await handlePaymentReceived(store, payment(), log);
    await handlePaymentReceived(store, payment({ gross: 1n }), log);
    expect(store.invoices.get(ORDER)?.status).toBe("paid");
  });
});

describe("handleOrderRefunded", () => {
  it("marks the invoice refunded", async () => {
    const store = new MemoryStore();
    store.invoices.set(ORDER, {
      orderId: ORDER,
      merchantAddress: NORTHWIND,
      asset: ETH,
      amount: 10n ** 18n,
      status: "paid",
    });

    await handleOrderRefunded(
      store,
      {
        orderId: ORDER,
        customer: ALICE,
        asset: ETH,
        amount: 10n ** 18n,
        txHash: "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        blockNumber: 1_200n,
      },
      log,
    );

    expect(store.invoices.get(ORDER)?.status).toBe("refunded");
  });
});
