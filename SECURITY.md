# Security Policy

## Supported versions

| Version | Status |
|---|---|
| 0.4.x | ✅ Active (staging; mainnet launch pending audit) |
| 0.3.x | ⚠️ Security fixes only |
| < 0.3 | ❌ End of life |

## Reporting a vulnerability

**Do not open a public issue for security vulnerabilities.**

Email **security@orkonet.com** with:

- A description of the issue and its impact.
- Steps to reproduce or a Foundry proof of concept.
- Affected contract(s), version, and network if deployed.

We acknowledge reports within 2 business days and provide an initial
assessment within 7 days.

## Disclosure

We follow coordinated disclosure. Please give us reasonable time to patch
before publishing, and do not access funds that are not yours. We credit
researchers who report valid issues unless they prefer to stay anonymous.

## Scope

In scope:

- `src/OrkoPay.sol`
- `src/OrkoPayRegistry.sol`
- `src/libraries/*`
- `indexer/` payment reconciliation logic

Out of scope:

- `src/periphery/OrkoPayLens.sol` (read-only)
- Third-party contracts (USDC, wallets, RPC providers)
- Issues that require a compromised owner multisig
- Gas optimisations without a security impact
