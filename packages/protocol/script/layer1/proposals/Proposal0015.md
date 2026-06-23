# PROPOSAL-0015: Prune SGX Instances and Rotate SGX Trust

## Summary

This proposal prunes stale SGX prover instances, rotates the trusted SGX `MRSIGNER`, retains the
selected production SGX `MRENCLAVE` values, and revokes the other previously trusted `MRENCLAVE`
values on the existing mainnet SGX attesters.

The proposal keeps the explicitly allowed existing instance ids. It does not enable any new
`MRENCLAVE`; future SGX instance registration under a new enclave measurement will need a follow-up
allowlist proposal.

## Mainnet Contracts

| Name               | Address                                      |
| ------------------ | -------------------------------------------- |
| `SGXGETH_VERIFIER` | `0x08568df252ecf37d6c3efd24f6ca3688118697f1` |
| `SGXRETH_VERIFIER` | `0xa1018Ba2e22139076f91dA2A856B2CAB22d968F6` |
| `SGXGETH_ATTESTER` | `0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261` |
| `SGXRETH_ATTESTER` | `0x8d7C954960a36a7596d7eA4945dDf891967ca8A3` |

## SGX Instance Pruning

The proposal keeps only the explicitly allowed instance ids and deletes every currently registered
non-allowed id below `nextInstanceId`.

| Verifier           | Observed `nextInstanceId` | Allowed ids | Deleted ids          |
| ------------------ | ------------------------: | ----------- | -------------------- |
| `SGXGETH_VERIFIER` |                       `6` | `[4]`       | `[0, 1, 2, 3, 5]`    |
| `SGXRETH_VERIFIER` |                       `7` | `[5]`       | `[0, 1, 2, 3, 4, 6]` |

If the live instance set changes before execution, regenerate and re-review the delete lists before
submitting calldata.

## Signer Rotation

The proposal enables a new trusted signer and then disables the old signer on both SGX attesters.

| Signer          | Value                                                                |
| --------------- | -------------------------------------------------------------------- |
| `OLD_MR_SIGNER` | `0xca0583a715534a8c981b914589a7f0dc5d60959d9ae79fb5353299a4231673d5` |
| `NEW_MR_SIGNER` | `0xe08aef23d4357d47e5ac5f278ba5492a5f5fb145c4fc026995367210f21a333c` |

Before this proposal, `OLD_MR_SIGNER` is trusted on both SGX attesters and `NEW_MR_SIGNER` is not
trusted on either SGX attester.

## MRENCLAVE Retention

The following values are intentionally retained. Both were confirmed with
`trustedUserMrEnclave(bytes32) == true` before proposal update.

| Attester           | Retained `MRENCLAVE` value                                           |
| ------------------ | -------------------------------------------------------------------- |
| `SGXGETH_ATTESTER` | `0x398be8424f27802b38e6e8d3413bf6a0b187349e68522a218f5bfc00279006ac` |
| `SGXRETH_ATTESTER` | `0x72258d3cae0e9901d0efc1f630064f1c44f11950bd25fee0b62ec8df84532da2` |

## MRENCLAVE Revocation

The following values were enumerated from `MrEnclaveUpdated(bytes32 indexed mrEnclave, bool trusted)`
events on the two mainnet attesters and confirmed with `trustedUserMrEnclave(bytes32) == true`.
The retained values above are intentionally excluded from this revocation list.

| Attester           | Revoked `MRENCLAVE` values                                           |
| ------------------ | -------------------------------------------------------------------- |
| `SGXGETH_ATTESTER` | `0x3e6113a23bbdf9231520153253047d02db8f1dd38a9b52914ab7943278f52db0` |
| `SGXGETH_ATTESTER` | `0x692c8624d30a327340b0dfbb67203e941175ac700d1a058c717e5269103d37e6` |
| `SGXGETH_ATTESTER` | `0xd1f43acede51c4eb2f66b86cce52682edad80b810b9d87fba3a9b67254c91b77` |
| `SGXGETH_ATTESTER` | `0xfda8bb1fc9938700c25353c0a5fabc96a238e69ce8e35f08e558831a20db33a6` |
| `SGXRETH_ATTESTER` | `0x13ea9869632ac20b176ae0fdc39998b2a644a695db024ef7fe0e4b3c59084160` |
| `SGXRETH_ATTESTER` | `0x3551faac39edee5abfaa19ab065c217db1485aebae255a9edddf6dfff6b29b52` |
| `SGXRETH_ATTESTER` | `0x3b589538b775ddbfc5fb028167ff846116159e6687aef9f849ca5a70a7871ea5` |
| `SGXRETH_ATTESTER` | `0x3f71cf178a032816c2731a43aef746c464a5326e891dc881773ec2b599b2cf0a` |
| `SGXRETH_ATTESTER` | `0x482b06132c4306ea55bc34ff90d46532ff4151f473dbfe4d2cb2442af2ff288b` |
| `SGXRETH_ATTESTER` | `0x59bf7d48610cc8a56ba8a390b68c31a1443297869b174aeacac67dc152820f0e` |
| `SGXRETH_ATTESTER` | `0x605ad10c1a56ed7289f198d64a39a952cd3b8a0bed3fcb19c8301c1847dc3a2f` |
| `SGXRETH_ATTESTER` | `0x631778b0d420d2d0bba4c730b0fd74857afeefb3429371ae97ab450e40ca127e` |
| `SGXRETH_ATTESTER` | `0x67742ab222790e20ba3656b3b294645a3384a5df5a770b86f8c06529523d990e` |
| `SGXRETH_ATTESTER` | `0x6e43c1d575b5b785d0f6259dfac44998c6f0c164864f9f98270fb740c14eb943` |
| `SGXRETH_ATTESTER` | `0x8f73135b83a84126c7fff37ea02f9363e134aea0f6446b13e198b20d94e75099` |
| `SGXRETH_ATTESTER` | `0x9546301721e2ea111ab0f79b6e529d6bb6c486ac98bcf7739429ad06c09db63d` |
| `SGXRETH_ATTESTER` | `0xa096348d480eb0474f5eab182671933c029545521960d87d4e49283005809be9` |
| `SGXRETH_ATTESTER` | `0xa4eedfc6484494d4c08bfb9b9dd887c6e0540ba9d8ee207fe0e16814852e3356` |
| `SGXRETH_ATTESTER` | `0xa5f741bfed254a1e21738d429e7bd074e25918af7f71fbe1e0135c3974b06e00` |
| `SGXRETH_ATTESTER` | `0xb09f9005e4612526e378466b5c16ab6028478e81c085812d6ed37166c4cda10e` |
| `SGXRETH_ATTESTER` | `0xbdec26abd36fde2cfbb8db7a0793a9346b11bd558b39890407d458500711c88c` |
| `SGXRETH_ATTESTER` | `0xc90e5d2e39d1d3f8397a6048c32ba50139d1577c28985e1f7638785935f41734` |
| `SGXRETH_ATTESTER` | `0xca349ba0dfeced0bd837a56c97417c11e51d490eec4ff08321dd130776a413bd` |
| `SGXRETH_ATTESTER` | `0xdcd483d3406d9b1871bb92420f5a080c4372e0d6b8522a4a2cb91a0f736669c6` |
| `SGXRETH_ATTESTER` | `0xddda8ba9c9153e3d2f680f2f53adbc774a9753cc55d40dde4cb02aef38c42109` |
| `SGXRETH_ATTESTER` | `0xdfcb4fca3073e3f3a90b05d328688c32619d56f26789c0a9797aa10e765a7807` |
| `SGXRETH_ATTESTER` | `0xe2375b778ee5700a73c7fcf449abb4a62e00127d324b6694898073ba5aff4f5c` |
| `SGXRETH_ATTESTER` | `0xe5774b71990b0d5f3eca8d4d22546764dd9549c743a1a6d4d4863d97f6b8c67a` |
| `SGXRETH_ATTESTER` | `0xf285b7cbd78d2b96cdc54cfea3e47d8f510a4b4f91b719c97f8bbb90974f805b` |

## Actions

This proposal executes 35 L1 actions:

1. `SGXGETH_ATTESTER.setMrSigner(NEW_MR_SIGNER, true)`
2. `SGXRETH_ATTESTER.setMrSigner(NEW_MR_SIGNER, true)`
3. `SGXGETH_ATTESTER.setMrSigner(OLD_MR_SIGNER, false)`
4. `SGXRETH_ATTESTER.setMrSigner(OLD_MR_SIGNER, false)`
5. `SGXGETH_ATTESTER.setMrEnclave(..., false)` for the 4 GETH values above
6. `SGXRETH_ATTESTER.setMrEnclave(..., false)` for the 25 RETH values above
7. `SGXGETH_VERIFIER.deleteInstances([0, 1, 2, 3, 5])`
8. `SGXRETH_VERIFIER.deleteInstances([0, 1, 2, 3, 4, 6])`

There are no L2 actions and no verifier implementation upgrades.
