# orkopay-indexer

Watches OrkoPay for `PaymentReceived` and `OrderRefunded` events and updates
the matching checkout invoice in Postgres. The OrkoNet API reads invoice status
to release orders to merchants.

## How it works

1. The API creates an invoice (`pending`) and derives `orderId = keccak256(invoiceId)`.
2. The checkout page calls `OrkoPay.deposit` / `depositToken` with that `orderId`.
3. The indexer polls in block ranges, waiting `CONFIRMATIONS` blocks, and for
   each `PaymentReceived`:
   - unknown or non-pending invoice → logged and ignored
   - wrong asset → `underpaid` (`asset_mismatch`)
   - `gross < amount` → `underpaid` (`amount_short`)
   - otherwise → `paid` (overpayments are logged for support)
4. `OrderRefunded` marks the invoice `refunded`.

Each block range is applied in one transaction together with the cursor update,
so a crash mid-range replays the range instead of skipping events.

## Running locally

```bash
cp .env.example .env        # fill in RPC_URL and ORKOPAY_ADDRESS
npm install
npm run migrate
npm run dev
```

Against a local Anvil node:

```bash
anvil &
cd .. && forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

## Tests

```bash
npm test
npm run typecheck
```
