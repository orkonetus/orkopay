import { z } from "zod";
import type { Address } from "viem";

const address = z
  .string()
  .regex(/^0x[0-9a-fA-F]{40}$/, "expected a 0x-prefixed 20-byte address")
  .transform((v) => v as Address);

const schema = z.object({
  RPC_URL: z.string().url(),
  ORKOPAY_ADDRESS: address,
  DATABASE_URL: z.string().min(1),

  /** First block to scan when no cursor is stored (the deployment block). */
  START_BLOCK: z.coerce.bigint().default(0n),

  /** Blocks to wait before treating a log as final. */
  CONFIRMATIONS: z.coerce.number().int().min(0).default(3),

  /** Max block range per eth_getLogs request (provider limits vary). */
  BATCH_SIZE: z.coerce.bigint().positive().default(2_000n),

  POLL_INTERVAL_MS: z.coerce.number().int().positive().default(4_000),
  LOG_LEVEL: z.enum(["fatal", "error", "warn", "info", "debug", "trace"]).default("info"),
});

export type Config = z.infer<typeof schema>;

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const parsed = schema.safeParse(env);
  if (!parsed.success) {
    const issues = parsed.error.issues.map((i) => `  ${i.path.join(".")}: ${i.message}`);
    throw new Error(`Invalid indexer configuration:\n${issues.join("\n")}`);
  }
  return parsed.data;
}
