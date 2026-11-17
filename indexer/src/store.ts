import pg from "pg";
import type { Address, Hex } from "viem";
import type {
  Invoice,
  InvoiceStatus,
  InvoiceStore,
  PaymentRecord,
  RefundRecord,
  UnderpaidReason,
} from "./types.js";

interface InvoiceRow {
  order_id: string;
  merchant_address: string;
  asset: string;
  amount: string; // NUMERIC comes back as string
  status: InvoiceStatus;
}

/** Postgres-backed invoice store. Shares tables with the OrkoNet API. */
export class PgStore implements InvoiceStore {
  constructor(private readonly db: pg.PoolClient) {}

  async getInvoice(orderId: Hex): Promise<Invoice | null> {
    const { rows } = await this.db.query<InvoiceRow>(
      `SELECT order_id, merchant_address, asset, amount, status
         FROM invoices
        WHERE order_id = $1`,
      [orderId.toLowerCase()],
    );
    const row = rows[0];
    if (!row) return null;
    return {
      orderId: row.order_id as Hex,
      merchantAddress: row.merchant_address as Address,
      asset: row.asset as Address,
      amount: BigInt(row.amount),
      status: row.status,
    };
  }

  async markPaid(p: PaymentRecord): Promise<void> {
    await this.db.query(
      `UPDATE invoices
          SET status = 'paid',
              paid_amount = $2,
              fee_amount = $3,
              payer_address = $4,
              paid_tx_hash = $5,
              paid_block = $6,
              updated_at = now()
        WHERE order_id = $1 AND status = 'pending'`,
      [
        p.orderId.toLowerCase(),
        p.gross.toString(),
        p.fee.toString(),
        p.customer.toLowerCase(),
        p.txHash,
        p.blockNumber.toString(),
      ],
    );
  }

  async markUnderpaid(p: PaymentRecord, reason: UnderpaidReason): Promise<void> {
    await this.db.query(
      `UPDATE invoices
          SET status = 'underpaid',
              status_reason = $2,
              paid_amount = $3,
              payer_address = $4,
              paid_tx_hash = $5,
              paid_block = $6,
              updated_at = now()
        WHERE order_id = $1 AND status = 'pending'`,
      [
        p.orderId.toLowerCase(),
        reason,
        p.gross.toString(),
        p.customer.toLowerCase(),
        p.txHash,
        p.blockNumber.toString(),
      ],
    );
  }

  async markRefunded(r: RefundRecord): Promise<void> {
    await this.db.query(
      `UPDATE invoices
          SET status = 'refunded',
              refund_tx_hash = $2,
              refund_block = $3,
              updated_at = now()
        WHERE order_id = $1`,
      [r.orderId.toLowerCase(), r.txHash, r.blockNumber.toString()],
    );
  }

  async getCursor(contract: Address): Promise<bigint | null> {
    const { rows } = await this.db.query<{ last_block: string }>(
      `SELECT last_block FROM indexer_cursor WHERE contract = $1`,
      [contract.toLowerCase()],
    );
    const row = rows[0];
    return row ? BigInt(row.last_block) : null;
  }

  async setCursor(contract: Address, block: bigint): Promise<void> {
    await this.db.query(
      `INSERT INTO indexer_cursor (contract, last_block, updated_at)
            VALUES ($1, $2, now())
       ON CONFLICT (contract)
         DO UPDATE SET last_block = EXCLUDED.last_block, updated_at = now()`,
      [contract.toLowerCase(), block.toString()],
    );
  }
}
