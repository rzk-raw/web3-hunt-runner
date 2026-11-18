# web3-hunt-runner

Heavy-test runner for authorized Web3 smart-contract security work, on
GitHub Actions runners (2-core, 7 GB RAM, free for public repos) — so the
low-RAM local VM (7.9 GB total, ~126 MB free at last check) is never the
blocker for a test.

## What it is

Four `workflow_dispatch`-only workflows. Nothing runs automatically on
push — every run is started manually, with inputs, and is bounded by
`timeout-minutes` and a configurable fuzz budget.

| Workflow | What it does |
|---|---|
| `slither.yml` | Slither + solc-select static analysis, SARIF + text report artifact |
| `echidna-medusa.yml` | Echidna + Medusa fuzzing (prebuilt binaries), logs as artifact |
| `foundry.yml` | Foundry `forge build` + `forge test` (fuzz runs configurable) |
| `wake-semgrep.yml` | Wake + Semgrep scan, reports as artifact |

## How to trigger a run

1. GitHub repo → **Actions** → pick a workflow → **Run workflow**.
2. Fill in the inputs:
   - `target_repo` — full repo to test, e.g. `GuardianOrg/valantis-stakedhypeescrow-defender-contest-guardian`.
     Leave empty to test this repo's own smoke-test contract in
     `contracts/test/Vault.sol`.
   - `target_ref` — branch / tag / commit, e.g. `0f245011cc5e93dc4232b29c29786859566c586e`.
     Default: `main`.
   - `target_path` — directory inside the target repo to analyse, e.g. `src`.
     Default: `.`
   - `fuzz_runs` / `test_limit` / `timeout` — budget for the fuzz run
     (defaults are small on purpose; raise them deliberately).
3. Download the run's artifacts (reports / logs) from the run page.

## Rules — read before use

- **Authorized work only.** Only test targets that are in scope of an
  active bug-bounty program, audit contest, or a repo you own / have
  permission to test. Never point these workflows at a live mainnet
  contract, a production deployment, or anyone else's code without scope.
- The workflows clone the target repo at runtime. No target code is
  embedded in this repo.
- No secrets, tokens, or private keys are stored in this repo or in any
  workflow. Fuzzing is local to the runner; no RPC key is required
  (mainnet-fork PoCs need a fork URL — supply it as a run input only if
  the target's scope allows it, never commit one).
- Findings from these tools are **leads, not proof**. Every candidate
  must be reproduced with a Foundry PoC and pass the 7-Question Gate
  before any report is written.

## Smoke test

`contracts/test/Vault.sol` is a deliberately vulnerable 20-line vault
(reentrancy: balance updated after the external call). Running
`slither.yml` or `foundry.yml` with no `target_repo` should flag it.
That is the expected result — it proves the runner works.

## Limits

- GitHub-hosted runners: 2 vCPU, 7 GB RAM, 14 GB SSD. Public repos get
  free Actions minutes (2,000 min/month on the free plan is the usual
  public-repo allowance; check current GitHub billing docs — limits
  change).
- Local VM still does: reading scope, manual code review, triage,
  writing PoCs, and the final report. Actions does the heavy,
  memory-hungry runs: Slither on big repos, Echidna/Medusa fuzzing,
  long Foundry fuzz campaigns.
- `timeout-minutes` is set on every job. If a run times out, lower the
  fuzz budget or split the target by directory and re-run.
