# OrkoPay

On-chain settlement for OrkoNet merchant payments. Customers pay for checkout
invoices in ETH or USDC on EVM chains; OrkoPay credits the merchant net of the
platform fee and lets the merchant withdraw to a registered payout address.

| Component | Path | Description |
|---|---|---|
| Settlement contract | `src/OrkoPay.sol` | Payments, refunds, withdrawals, fee sweeps |
| Merchant registry | `src/OrkoPayRegistry.sol` | Merchant directory, fee tiers, payout addresses |
| Lens | `src/periphery/OrkoPayLens.sol` | Batch reads for the dashboard and indexer |
| Indexer | `indexer/` | Confirms on-chain payments against checkout invoices |

See [docs/architecture.md](docs/architecture.md) for the end-to-end flow and
trust model.

## Payment flow

1. The OrkoNet API creates a checkout invoice and derives
   `orderId = keccak256(invoiceId)`.
2. The customer's wallet calls `deposit(orderId, merchant)` with ETH, or
   `depositToken(orderId, merchant, usdc, amount)` after approving USDC.
3. OrkoPay records the order, credits the merchant's balance net of fees and
   emits `PaymentReceived`.
4. The indexer waits for confirmations, checks the payment against the invoice
   and marks it `paid`. The API then releases the order to the merchant.
5. Merchants call `withdraw(asset, amount)` whenever they like; funds go to
   their registered payout address.
6. Within the refund window a merchant (or ops) can call `refund(orderId)` to
   return the full amount to the customer.
7. Finance sweeps platform revenue with `collectFees(asset)`.

## Fee model

Fees are in basis points (1 bp = 0.01%). Merchants in higher volume tiers get a
discount off the base rate.

```
effective_bps = max(base_bps - tier_discount_bps, 0)
fee           = floor(gross × effective_bps / 10_000)
net           = gross − fee
```

`base_bps` is capped at 1,000 (10%) and tier discounts at 1,000. The fee is
fixed per order at payment time; later tier or base-fee changes do not affect
existing orders.

## Getting started

Requires [Foundry](https://book.getfoundry.sh/getting-started/installation)
(stable channel) and Node 20+ for the indexer.

```bash
forge install foundry-rs/forge-std   # add --no-git outside a git checkout
forge build
forge test
```

Useful variants:

```bash
forge test -vvv --match-contract OrkoPayRefundTest
forge test --match-path "test/invariant/*"
forge coverage
make snapshot          # gas snapshot
```

## Deploying

```bash
cp .env.example .env   # fill in values
source .env
forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast --verify
```

The deployer is the initial owner and hands off to `OWNER` (the ops multisig)
via a two-step transfer. **The multisig must call `acceptOwnership()` on both
`OrkoPayRegistry` and `OrkoPay`** before the deployment is considered live.
Deployment addresses per network are tracked in the ops runbook.

| Variable | Description |
|---|---|
| `DEPLOYER_PRIVATE_KEY` | Hot key used only for the deployment transaction |
| `OWNER` | Ops multisig that will own both contracts |
| `OPERATOR` | Onboarding service address (optional) |
| `FEE_RECIPIENT` | Treasury for swept fees (defaults to `OWNER`) |
| `BASE_FEE_BPS` | Platform base fee (default 250 = 2.5%) |
| `REFUND_WINDOW` | Seconds after payment during which refunds are allowed (default 14 days) |
| `USDC_ADDRESS` | Canonical USDC on the target chain (optional) |

## Repository layout

```
src/
  OrkoPay.sol               settlement
  OrkoPayRegistry.sol       merchant directory
  interfaces/               IOrkoPay, IMerchantRegistry, IERC20
  libraries/                FeeMath, SafeTransferLib
  periphery/                OrkoPayLens
  utils/                    Ownable2Step, Pausable, ReentrancyGuard (adapted from OZ v5)
test/
  *.t.sol                   unit tests per feature area
  invariant/                stateful fuzzing
  mocks/, harness/, utils/  fixtures
script/                     deployment and ops scripts
indexer/                    TypeScript payment confirmation service
docs/                       architecture and runbooks
```

## Security

Please report vulnerabilities privately — see [SECURITY.md](SECURITY.md).

---

© OrkoNet LLC. All rights reserved.