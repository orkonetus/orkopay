import type { Logger } from "pino";
import type { InvoiceStore, PaymentRecord, RefundRecord } from "./types.js";

/**
 * Reconciles a confirmed PaymentReceived event with its checkout invoice.
 *
 * The invoice is marked `paid` only if the asset matches and the gross amount
 * covers the amount due. Overpayments are accepted and flagged for support.
 */
export async function handlePaymentReceived(
  store: InvoiceStore,
  payment: PaymentRecord,
  log: Logger,
): Promise<void> {
  const ctx = { orderId: payment.orderId, txHash: payment.txHash };
  const invoice = await store.getInvoice(payment.orderId);

  if (!invoice) {
    log.warn(ctx, "payment for unknown invoice; ignoring");
    return;
  }

  if (invoice.status !== "pending") {
    log.warn({ ...ctx, status: invoice.status }, "payment for non-pending invoice; ignoring");
    return;
  }

  if (payment.asset.toLowerCase() !== invoice.asset.toLowerCase()) {
    log.warn({ ...ctx, expected: invoice.asset, got: payment.asset }, "asset mismatch");
    await store.markUnderpaid(payment, "asset_mismatch");
    return;
  }

  if (payment.gross < invoice.amount) {
    log.warn(
      { ...ctx, due: invoice.amount.toString(), paid: payment.gross.toString() },
      "invoice underpaid",
    );
    await store.markUnderpaid(payment, "amount_short");
    return;
  }

  if (payment.gross > invoice.amount) {
    log.info(
      { ...ctx, due: invoice.amount.toString(), paid: payment.gross.toString() },
      "invoice overpaid; flagging for support",
    );
  }

  await store.markPaid(payment);
  log.info(ctx, "invoice paid");
}

/** Marks an invoice refunded once the OrderRefunded event is confirmed. */
export async function handleOrderRefunded(
  store: InvoiceStore,
  refund: RefundRecord,
  log: Logger,
): Promise<void> {
  const invoice = await store.getInvoice(refund.orderId);
  if (!invoice) {
    log.warn({ orderId: refund.orderId }, "refund for unknown invoice; ignoring");
    return;
  }
  await store.markRefunded(refund);
  log.info({ orderId: refund.orderId, txHash: refund.txHash }, "invoice refunded");
}
