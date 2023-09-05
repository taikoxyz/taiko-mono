- *=*: Transition with the same values.
- *≠*: Transition with the different values.
- *!*: Optimistic transition that is being challanged.

For both ZK and OP blocks, proving fees are always given to the assigned prover regardless.

## ZK Blocks
| Existing Transiion     | New (replacing) Transition |  Proving Behavior   | Verification Behavior|
|----------|-------------------------|----------------------------|--------------------------------------------------------------|--------------------------------------------------------------|
|  -                     | ZK                         | Accepted once ZK proof is verified.                | (R1) Verifiable. Block reward goes to block proposer.|
| ZK                      | ZK≠      | Accept only from oracle prover                               |(R2) Verifiable. Block reward goes to block proposer; prover bond returned to assigned prover.|
|  -                     | OP                         | Revert   | Unverifiable                                                    |
| ZK                      | ZK=           | Revert                                                       | same as (R1)
| ZK                      | OP        | Revert    | same as (R1)


## OP Blocks

| Existing Transiion     | New (replacing) Transition |  Proving Behavior   | Verification Behavior|
|----------|-------------------------|----------------------------|--------------------------------------------------------------|--------------------------------------------------------------|
| -  | ZK  | Revert | Unverifiable
| -  | OP  | Accept | (R3) Veriable after maturity. Block reward to transition owner; Proving fee to assigned prover; prover bond returned to assigned prover.
|ZK  | ZK= | Revert | (R4) Verifiable. Block reward to transition owner; 1/4 optimistic bond goes to adtual prover, the rest 3/4 burned.
|ZK  | ZK≠ | Accept only from oracle prover |
|ZK  | OP= | Revert    |
|ZK  | OP≠ | Revert   |
|OP  | ZK= | Revert    |
|OP  | ZK≠ | Marked as challanged and proven    |
|OP  | OP= | Revert    |
|OP  | OP≠ | Mark as challanged, keep the old transition values   | Unverifiable
|OP! | ZK= | Mark as proven, clear challanger    | Verifiable.
|OP! | ZK≠ | Mark as proven, challanger becomes owner.    | Verifiable.
|OP! | OP= | Revert   | Unverifiable
|OP! | OP≠ | Revert    | Unverifiable
|OP! | OP≠ | Revert   | Unverifiable