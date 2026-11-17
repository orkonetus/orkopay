# Contributing to OrkoPay

Internal contributors only.

## Branches

| Branch | Purpose |
|---|---|
| `main` | Deployed code, tagged releases only |
| `dev` | Integration branch |
| `feat/*` | Features, opened against `dev` |
| `fix/*` | Fixes; against `dev` unless a hotfix to `main` |

## Workflow

1. Branch off `dev` (`feat/polygon-deploy`, `fix/indexer-backfill`).
2. Write or update tests before changing implementation.
3. `forge fmt` and, for indexer changes, `npm run typecheck` before committing.
4. Open a PR against `dev` and fill in the template.
5. Contract changes need one review from the contracts team; anything touching
   value flow (`deposit*`, `refund`, `withdraw`, `collectFees`) needs two.

## Solidity style

- **Errors:** typed `error` declarations; no `require` strings in `src/`.
- **NatSpec:** every `external`/`public` function needs `@notice`; use
  `@inheritdoc` for interface implementations.
- **CEI:** update state before external calls, and mark value-moving functions
  `nonReentrant`.
- **Fee math:** always go through `FeeMath`. Never inline basis-point arithmetic.
- **Transfers:** always go through `SafeTransferLib`.
- **Modifier order:** `external payable whenNotPaused nonReentrant`.
- **Line length:** 100 (`forge fmt` enforces).

## Tests

We care about two things:

- **Properties** — what must always hold? (`net + fee == gross`, ETH backing)
- **Failure modes** — what should revert, for whom, and when?

Conventions:

- One test file per feature area (`OrkoPay.refund.t.sol`; core payment
  paths live in `OrkoPay.t.sol`), sharing
  `test/utils/BaseTest.sol`.
- `test_<function>_<behaviour>` for unit tests, `testFuzz_` for fuzz targets,
  `invariant_` for stateful properties.
- Assert exact custom errors with `vm.expectRevert(abi.encodeWithSelector(...))`.

```bash
forge test
FOUNDRY_PROFILE=ci forge test     # more fuzz/invariant runs
forge coverage
```

## Indexer

- Handlers are pure functions over an `InvoiceStore`; unit test them with the
  in-memory store in `handlers.test.ts`.
- Any change to an event signature in `IOrkoPay.sol` must update
  `indexer/src/abi.ts` in the same PR.

## Upgradeability

The contracts are **not upgradeable**. Breaking changes require a new
deployment, a registry migration, and an indexer cut-over (new
`ORKOPAY_ADDRESS` and `START_BLOCK`). Coordinate with ops before merging.
