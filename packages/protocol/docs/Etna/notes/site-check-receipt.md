# Site-check receipt — 2026-10-01 PR-comment follow-up

This is a record of local observations, not an independent certification or retained CI/browser trace. Starting commit: `d1732e2bf04b61d813301074575201e3c7832347`; the tested final HTML contents are identified below. No production protocol behavior was exercised.

- Python3.12.14, lxml parser; Chromium151.0.7922.173 with Playwright and a localhost static server.
- All23 HTML files: local paths/fragments, unique IDs, referenced ARIA IDs and absence of scripts/iframes/external runtime assets checked; zero errors.
- Counts:27 inline SVG diagrams,35 native hidden-answer blocks. These describe this snapshot only.
- All23 pages loaded at1280- and390-pixel viewport widths; no page-width overflow or SVG text outside its viewBox. Native answers in lessons9/10 opened. Later fixture-wording edits to lessons3/12 received the same browser checks again.
- Desktop/mobile screenshots of the funding reference and competition lesson were inspected; a dark-mode checkpoint screenshot was captured. No claim of exhaustive visual accessibility auditing follows.
- HTML reformatting preserved parsed element/attribute/text order and exact preformatted blocks. Diagram coordinates were unchanged. Semantic edits were reviewed separately.
- Exact rational calculations of67.2,346.7625,715.2ETH/day, the hypothetical1/1344ETH rent ceiling and≤3N storage values were separately checked against their stated rules. Those are deductions, not measured gas/capacity or an economic equilibrium.

The task prohibits committing throwaway experiment code. The session's checking scripts and screenshots remain scratch artifacts and are deleted after publication; no durable validator or raw browser trace is claimed. The [manual reproduction procedure](../validation.md#manual-reproduction-procedure) states the checks and their limits. A future implementation task should supply reviewed generators and a maintained conformance suite before relying on provisional fixture outputs.

## Tested HTML identities

From the Etna directory, `sha256sum design/*.html learn/*.html` reproduces this file inventory and its byte identities. This receipt itself is not an input to the HTML checks.

| File | SHA-256 |
|---|---|
| `design/accountability.html` | `8623b675b6762e0256d1cff07cc7453b19da10516f33961ae46701bab831b27c` |
| `design/arguments.html` | `881367d7d43299e70ff83622abc1a2bc2165cc4869d09c568387b049b71a3fc5` |
| `design/assurance.html` | `d1a94f9796812d6e5159f59675bdd51ef8e49eeebcb57bbc3089dae2c7831e25` |
| `design/checkpoints.html` | `ae128d64df3da1dc71689afa2f67178d8c6a15033ee78d6067a71f9a4a48c6fa` |
| `design/codec.html` | `d727b65365b0330bf4938be9781676e07c5a5af57d9bed7c34eda807902ca043` |
| `design/index.html` | `50b65296c05530af993083ae3c3695e88c51eb66dca084c85f1cb8c4599bffdd` |
| `design/migration.html` | `7ba86dd007cdfb272d1a20da8d2a045b6e8826930cf068ddead26c46035e3f9d` |
| `design/proof-discovery.html` | `0cdbd060ab8bf1899f1e6786139c32869fc3e91f2aab53f56cae99ef9c85094c` |
| `design/roles.html` | `5ba7f501dddc7b68fec58ce9cd804f4e47a25381e4c1764744135c7c9ea52c94` |
| `design/staging.html` | `179611f64f48162765aecb17508b1f338a5ec61327e3aa63100a9d7b0d7dae0b` |
| `learn/01-confirmations.html` | `b9780ee32d81374e3a8b1c2eb6aecf4f2afa6a40e3491496a15131c2d8f6d77b` |
| `learn/02-origins.html` | `2e34d8b885242623003aef613035b2bf30bf9834c2f17c167efc84dba9233777` |
| `learn/03-body.html` | `de3937eea01ac2d9fa0ec8ad9cd268e3d0b9c7955e394dd8f4fa4719c20eef1c` |
| `learn/04-staging.html` | `7d83d609aba50fddf15aad4a0f47abaa822cc4ddccf18b82c4c8498b8ec869a1` |
| `learn/05-settlement.html` | `c07401dc48ac5427338cb8e41050131852a4588dd0d03a59d2eff85b75291a45` |
| `learn/06-forced-inclusion.html` | `4ab23b714066c132ee0c3f771e8ec2e2639e1efabdbca0f920fba797d1cd6b6f` |
| `learn/07-roles.html` | `561796a73c33ab8eb33fb6bb0f47fbd0d78475402ebdf84cf3e325e5933278d8` |
| `learn/08-publication.html` | `f6df5d4d9e26ad4c82b4a33582b55af48962736acb1a89ed7d098f22782dc816` |
| `learn/09-competition.html` | `0d9bd8e8a42990c042e2f258d2585b9745ec9ad129abcb129a99db454675f3c3` |
| `learn/10-checkpoints.html` | `742afe4c2e860d2e434bc785a09228ac1fc8f9fd44c4497f57b8dc94078ef02f` |
| `learn/10-migration.html` | `b50ecf3a1744dbfdd8bfa0eceb890f75039022f28d2bb834d4d198d2d32c4d5f` |
| `learn/11-assembly.html` | `07f3189991cafaa1ed79901b1c9c74da002776464605cd086d2761aa85da114a` |
| `learn/index.html` | `780b74fd28ae9d84e93634b9fe130df555436b68b4b83d03f27b20bb20f441d0` |
