# SimpleTokenUnlock — batch `changeRecipient`

Repoints the `recipient()` of seven `SimpleTokenUnlock` contracts on Ethereum
mainnet to a single Safe. Import `safe_batch_change_recipient.json` into the
Safe UI's **Transaction Builder** app (drag & drop), or regenerate it with
`safe_batch_change_recipient.py`.

## Ownership

All seven proxies resolve to the same implementation and the same owner:

| Field | Value |
| --- | --- |
| Implementation (EIP-1967) | [`0x1223C617fe9FBC111a23879D0C31eecd7443281a`](https://etherscan.io/address/0x1223C617fe9FBC111a23879D0C31eecd7443281a) (`SimpleTokenUnlock`) |
| `owner()` | [`0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F`](https://etherscan.io/address/0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F) |
| Owner type | Safe (`GnosisSafeProxy`, singleton `0x4167…461a`, `VERSION()` = `1.4.1`) |
| Owner threshold | 4 of 6 |

The new recipient [`0xB73b0FC4C0Cfc73cF6e034Af6f6b42Ebe6c8b49D`](https://etherscan.io/address/0xB73b0FC4C0Cfc73cF6e034Af6f6b42Ebe6c8b49D)
is itself a Safe v1.4.1 (3 of 5) that shares four of its five owners with the
owning Safe.

## Transactions

Each entry calls `changeRecipient(0xB73b0FC4C0Cfc73cF6e034Af6f6b42Ebe6c8b49D)`
with `value = 0`.

| # | Unlock contract | `recipient()` before | TKO held |
| --: | --- | --- | --: |
| 1 | `0xa2910373DD7ac2431F85AD5133A939906d794b44` | `0xCd593600Edd72738aa285039D791B0dc9779e9e9` | 271,877 |
| 2 | `0x0090ffD878336257F60F43517bE2507b0673bbd4` | `0xD202a56c5e7ba279431e43d945C5Cc6F68D083b7` | 405,517 |
| 3 | `0xb8bCb4F3f113039626b99Fe148cef1200DB88637` | `0xaa0711d32942bd6a01B27722847f7c1D7F5928b5` | 1,200,000 |
| 4 | `0x165ecf7265fC2539a7a28E19629A0f96Ce49C971` | `0x7bb998A98f60811dEa7Df9048134e14DC3a38F97` | 228,103 |
| 5 | `0xEdf73B266B1c9D6C14D6B23Db91B77ff2f244EdB` | `0x7adfffe518369F4824f3eCcfB4754ee5BfF6c2a7` | 100,000 |
| 6 | `0x19227fe0C6f38322411b5EfcceACb2CAC2e2017c` | `0xBADBE033362E66c13e17888e7C7fC88B5373afbF` | 200,000 |
| 7 | `0x7e2c062f7D363C93920c9BDCe595B4358e4e01D0` | `0x9be64D1E195900AEBa4E2b900700090E62Ea26b9` | 265,517 |

`amountGranted` equals the TKO balance for every contract; the total reassigned
is 2,671,014 TKO. Nothing is withdrawable until the cliff at
`GRANT_TIMESTAMP + 183 days` = 2026-11-30 00:00 UTC.

## Why it does not revert

`changeRecipient` is guarded by `onlyRecipientOrOwner` and `nonReentrant` only —
there is no `whenNotPaused`, and all seven contracts are unpaused anyway. The
two `require`s both hold: the new recipient is non-zero, and it differs from
every current recipient.

Because `changeRecipient` also calls `delegate(_newRecipient)` on the TKO token,
the batch was simulated end to end rather than reasoned about statically.

## Simulation

Simulated against mainnet state with `eth_call` / `eth_simulateV1` state
overrides, reproducing the exact `execTransaction` the Safe UI would build
(`DELEGATECALL` into `MultiSendCallOnly` v1.4.1 `0x9641d764fc13c8B624c04430C7356C1C7C8102e2`),
with a real 4-of-6 quorum supplied via `approvedHashes` overrides.

| Check | Result |
| --- | --- |
| `domainSeparator()` recomputed vs on-chain | match |
| `safeTxHash` vs on-chain `getTransactionHash(...)` | match (`0x836ea924…27ebd7`, nonce 146) |
| `execTransaction` | success, returns `true` |
| `recipient()` on all 7 after execution | `0xB73b0FC4C0Cfc73cF6e034Af6f6b42Ebe6c8b49D` |
| Control: same call from a non-owner | reverts |
| Control: same batch with 3 of 4 signatures | reverts `GS025` |

`safeTxGas` and `gasPrice` are both 0, so Safe reverts with `GS013` if any inner
call fails, and `MultiSendCallOnly` reverts if any sub-call fails — a successful
`execTransaction` therefore proves all seven calls succeeded.

The `safeTxHash` above is bound to Safe nonce 146. If another transaction
executes first, the nonce moves and the hash changes; the batch itself stays
valid, but re-simulate before signing.
