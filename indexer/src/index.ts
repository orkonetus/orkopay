import { setTimeout as sleep } from "node:timers/promises";
import pg from "pg";
import { pino } from "pino";
import { createPublicClient, http } from "viem";
import { orkoPayAbi } from "./abi.js";
import { loadConfig } from "./config.js";
import { handleOrderRefunded, handlePaymentReceived } from "./handlers.js";
import { PgStore } from "./store.js";

const config = loadConfig();
const log = pino({ level: config.LOG_LEVEL, base: { service: "orkopay-indexer" } });

const client = createPublicClient({ transport: http(config.RPC_URL) });
const pool = new pg.Pool({ connectionString: config.DATABASE_URL, max: 4 });

let stopping = false;
for (const signal of ["SIGINT", "SIGTERM"] as const) {
  process.on(signal, () => {
    log.info({ signal }, "shutting down after current batch");
    stopping = true;
  });
}

/**
 * Processes one confirmed block range inside a single DB transaction so the
 * cursor only advances if every event in the range was applied.
 */
async function processRange(fromBlock: bigint, toBlock: bigint): Promise<void> {
  const logs = await client.getContractEvents({
    address: config.ORKOPAY_ADDRESS,
    abi: orkoPayAbi,
    fromBlock,
    toBlock,
    strict: true,
  });

  const conn = await pool.connect();
  try {
    await conn.query("BEGIN");
    const store = new PgStore(conn);

    for (const ev of logs) {
      switch (ev.eventName) {
        case "PaymentReceived":
          await handlePaymentReceived(
            store,
            {
              orderId: ev.args.orderId,
              customer: ev.args.customer,
              merchant: ev.args.merchant,
              asset: ev.args.asset,
              gross: ev.args.gross,
              fee: ev.args.fee,
              txHash: ev.transactionHash,
              blockNumber: ev.blockNumber,
            },
            log,
          );
          break;
        case "OrderRefunded":
          await handleOrderRefunded(
            store,
            {
              orderId: ev.args.orderId,
              customer: ev.args.customer,
              asset: ev.args.asset,
              amount: ev.args.amount,
              txHash: ev.transactionHash,
              blockNumber: ev.blockNumber,
            },
            log,
          );
          break;
      }
    }

    await store.setCursor(config.ORKOPAY_ADDRESS, toBlock);
    await conn.query("COMMIT");
  } catch (err) {
    await conn.query("ROLLBACK");
    throw err;
  } finally {
    conn.release();
  }

  log.debug(
    { fromBlock: fromBlock.toString(), toBlock: toBlock.toString(), events: logs.length },
    "range processed",
  );
}

async function main(): Promise<void> {
  const conn = await pool.connect();
  let stored: bigint | null;
  try {
    stored = await new PgStore(conn).getCursor(config.ORKOPAY_ADDRESS);
  } finally {
    conn.release();
  }
  let next = stored === null ? config.START_BLOCK : stored + 1n;

  log.info(
    { contract: config.ORKOPAY_ADDRESS, from: next.toString(), confirmations: config.CONFIRMATIONS },
    "indexer started",
  );

  while (!stopping) {
    try {
      const head = await client.getBlockNumber();
      const safeHead = head - BigInt(config.CONFIRMATIONS);

      if (next > safeHead) {
        await sleep(config.POLL_INTERVAL_MS);
        continue;
      }

      const to = next + config.BATCH_SIZE - 1n < safeHead ? next + config.BATCH_SIZE - 1n : safeHead;
      await processRange(next, to);
      next = to + 1n;
    } catch (err) {
      log.error({ err }, "indexing iteration failed; retrying");
      await sleep(config.POLL_INTERVAL_MS);
    }
  }

  await pool.end();
  log.info("stopped");
}

main().catch((err) => {
  log.fatal({ err }, "indexer crashed");
  process.exit(1);
});
