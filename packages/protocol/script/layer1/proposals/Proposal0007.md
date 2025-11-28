# PROPOSAL-0007: Shasta Post-Fork Cleanup

Upgrade the Shasta fork router deployments to the final implementations now that the fork has passed. This replaces the fork router implementations on L1/L2 SignalService and L2 Anchor proxies with the direct Shasta implementations.

## Addresses

| Contract               | Proxy                                        | Notes                                                 |
| ---------------------- | -------------------------------------------- | ----------------------------------------------------- |
| L1 SignalService proxy | `0x9e0a24964e5397B566c1ed39258e21aB5E35C77C` | Uses `ForkRouter(proxy).newFork()`                    |
| L2 SignalService proxy | `0x1670000000000000000000000000000000000005` | Uses `ForkRouter(proxy).newFork()`                    |
| L2 Anchor proxy        | `0x1670000000000000000000000000000000010001` | Uses `ForkRouter(proxy).newFork()`                    |

The script calls `ForkRouter(proxy).newFork()` on each proxy (assuming it’s still the fork router implementation) to target the post-fork implementation—no manual address entry needed.

## Verification & Execution

1. Verify calldata: `P=0007 pnpm proposal`.
2. Dry-run L1: `P=0007 pnpm proposal:dryrun:l1`.
3. Dry-run L2: `P=0007 pnpm proposal:dryrun:l2`.

L2 actions are sent via the delegate controller message with gas limit `1_500_000`.
