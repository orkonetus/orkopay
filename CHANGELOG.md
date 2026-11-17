# Changelog

All notable changes to OrkoPay are documented here.
Follows [Keep a Changelog](https://keepachangelog.com) and
[Semantic Versioning](https://semver.org).

---

## [0.4.0] — 2026-10-28

### Added
- USDC settlement: `depositToken`, per-asset merchant balances and fee
  accounting, `setSupportedAsset` allowlist.
- Refunds: `refund(orderId)` callable by the order's merchant or the owner
  within `refundWindow` (default 14 days, max 30).
- `OrkoPayRegistry` operator role for the onboarding service, `setTier`, and
  paginated `merchants(offset, limit)`.
- `OrkoPayLens` batch-read helper.
- `indexer/` — payment confirmation service moved into this repo from
  `orkonet-api`.
- Invariant test for ETH backing; fuzz tests for `FeeMath`.

### Changed
- **Breaking:** `withdraw(amount)` → `withdraw(asset, amount)`;
  `collectFees()` → `collectFees(asset)`; `balanceOf(merchant)` →
  `balanceOf(merchant, asset)`. `PaymentReceived` gains an `asset` field.
- Ownership is now two-step (`Ownable2Step`) on both contracts.
- Registry `updatePayout` no longer changes the tier; tiers move to the
  operator-callable `setTier`. Payout changes stay owner-only.
- Fee cap lowered from 25% to 10%.
- Compiler 0.8.19 → 0.8.24, EVM `cancun`.
- `Deploy.s.sol` no longer seeds merchants; use `RegisterMerchant.s.sol`.

---

## [0.3.0] — 2026-08-12

### Added
- `Pausable` — owner can halt new deposits in an emergency without affecting
  pending withdrawals.
- `totalVolume` — lifetime gross settlement tracking.
- `BaseFeeUpdated`, `RegistryUpdated`, `FeeRecipientUpdated` admin events.

### Changed
- `collectFees` also callable by the fee recipient (previously owner-only).

---

## [0.2.0] — 2026-06-20

### Added
- Merchant tier discounts via `OrkoPayRegistry.tierDiscountBps`.
- `FeeMath.effectiveBps` helper.
- `ReentrancyGuard` on all value-moving functions.

### Fixed
- `withdraw` sent ETH before updating state. Reordered to follow
  Checks-Effects-Interactions.

---

## [0.1.0] — 2026-05-04

### Added
- Initial staging deployment: `OrkoPay`, `OrkoPayRegistry`, `FeeMath`.
- ETH-denominated settlement with per-order deduplication via `orderId`.
- `collectFees` for platform revenue sweep.
