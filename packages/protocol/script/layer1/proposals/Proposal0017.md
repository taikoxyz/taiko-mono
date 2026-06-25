# PROPOSAL-0017: L1 Security Recovery

## Executive Summary

This proposal restores the L1 recovery surface after the Shasta forged-proof incident.

It executes **61 L1 actions** and **no L2 actions**:

1. Upgrade `SignalService`.
2. Upgrade `Bridge`.
3. Upgrade `ERC20Vault`.
4. Call `Bridge.init3(bytes32[])` to disable the three remaining attacker retriable messages.
5. Upgrade `Inbox` to a new implementation deployed with the new `MainnetVerifier`.
6. Call `Inbox.init2(uint48,bytes32)` with the last known-good finalized Shasta state from L1 block
   `25,367,937`, one block before the first forged proof.
7. Rotate SGX-geth and SGX-reth MRSIGNER trust on the existing attesters.
8. Trust the new SGX-geth and SGX-reth MRENCLAVE values on the existing attesters.
9. Disable all currently trusted RISC0 and SP1 image/program IDs.
10. Disable all stale SGX-geth and SGX-reth MRENCLAVE values.

The implementation, new QuotaManager, and new verifier addresses in
[`Proposal0017.s.sol`](./Proposal0017.s.sol) are the mainnet contracts deployed by
`DeployHackRecoveryContracts` (chain 1, commit `b73608696`, the `taiko-alethia-protocol-v3.0.0`
branch tip). See [Deployed Addresses](#deployed-addresses).

New RISC0 and SP1 IDs remain pending and are intentionally not encoded yet. New SGX-geth and
SGX-reth MRENCLAVE values are encoded below; instance registration remains a separate follow-up
transaction through the new SGX verifiers' registrar.

## Action Order

### Group One: Eliminate Forged Checkpoints and Retriable Messages

1. Upgrade `L1.SIGNAL_SERVICE` to `SIGNAL_SERVICE_NEW_IMPL`.
2. Upgrade `L1.BRIDGE` to `MAINNET_BRIDGE_NEW_IMPL`.
3. Upgrade `L1.ERC20_VAULT` to `MAINNET_ERC20_VAULT_NEW_IMPL`.
4. Call `Bridge.init3(...)` with the three remaining retriable message hashes.

The SignalService upgrade must execute before the Bridge action so old forged checkpoints become
unreachable before retriable message cleanup. The new Bridge and ERC20Vault implementations are
deployed with the new immutable `QUOTA_MANAGER` address. This proposal does not upgrade
`QuotaManager` and does not call `updateQuota`; the intended recovery quotas must already be set by
the new QuotaManager constructor.

### Group Two: Restore the Proving System

1. Upgrade `L1.INBOX` to `MAINNET_INBOX_NEW_IMPL`.
2. Call `Inbox.init2(uint48,bytes32)` with the last correct pre-forgery finalized state.
3. Rotate SGX attester MRSIGNER trust.
4. Trust the new SGX-geth and SGX-reth MRENCLAVE values.
5. Revoke stale verifier trust from RISC0, SP1, SGX-geth, and SGX-reth.

`MainnetInbox` stores its proof verifier as an immutable. The proposal therefore cannot set the new
`MainnetVerifier` by calldata; the new `MAINNET_INBOX_NEW_IMPL` must be deployed with the new
`MAINNET_VERIFIER` before this proposal is generated. The new `MAINNET_VERIFIER` must reference the
newly deployed SGX-geth and SGX-reth verifier contracts. The old SGX verifier contracts
`0x08568Df252ecf37D6C3eFD24f6ca3688118697F1` and
`0xa1018Ba2e22139076f91dA2A856B2CAB22d968F6` are intentionally not touched because they will no
longer be part of the verification chain.

## Production Addresses

| Constant              | Address                                      | Notes                |
| --------------------- | -------------------------------------------- | -------------------- |
| `L1.SIGNAL_SERVICE`   | `0x9e0a24964e5397B566c1ed39258e21aB5E35C77C` | SignalService proxy  |
| `L1.BRIDGE`           | `0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC` | Mainnet Bridge proxy |
| `L1.ERC20_VAULT`      | `0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab` | ERC20Vault proxy     |
| `L1.INBOX`            | `0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f` | Shasta Inbox proxy   |
| `RISC0_RETH_VERIFIER` | `0x059dAF31F571da48Ab4e74Ae12F64f907681Cd8b` | RISC0 verifier       |
| `SP1_RETH_VERIFIER`   | `0x96337327648dcFA22b014009cf10A2D5E2F305f6` | SP1 verifier         |
| `SGXGETH_ATTESTER`    | `0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261` | SGX-geth attester    |
| `SGXRETH_ATTESTER`    | `0x8d7C954960a36a7596d7eA4945dDf891967ca8A3` | SGX-reth attester    |

The proxy and verifier addresses were cross-checked against the Taiko mainnet contract-address
documentation and live L1 calls.

## Deployed Addresses

These are the mainnet contracts deployed by `DeployHackRecoveryContracts` (chain 1) at commit
`b73608696`, the `taiko-alethia-protocol-v3.0.0` branch tip. Codediff and Etherscan links are
listed below.

| Constant                       | Address                                      | Contract                                          |
| ------------------------------ | -------------------------------------------- | ------------------------------------------------- |
| `MAINNET_INBOX_NEW_IMPL`       | `0x724012AECFdF963ea962f90a2743E66f870564C2` | `MainnetInbox` implementation                     |
| `SIGNAL_SERVICE_NEW_IMPL`      | `0x1A06832992785766a105838C95c1E13a0045AC85` | `SignalService` implementation                    |
| `MAINNET_BRIDGE_NEW_IMPL`      | `0x1c94D798CFA08F396E5BA9F81697289c53273381` | `MainnetBridge` implementation                    |
| `MAINNET_ERC20_VAULT_NEW_IMPL` | `0x024253C6FDC27d3161aFd43fb0241411A28dDc3c` | `MainnetERC20Vault` implementation                |
| `QUOTA_MANAGER`                | `0xBaCb003f0B13CeAF09Eb9Baf5915A640BD4Bc6cC` | New immutable `QuotaManager`                      |
| `MAINNET_VERIFIER`             | `0x0834aCfE76C46054d12478511b79Bf473a154A86` | New `MainnetVerifier` (`MainnetInbox` immutable)  |
| `NEW_SGXGETH_VERIFIER`         | `0x41e79EB4F03aBB5DF8716B759528dc5d8f6a84Ee` | New SGX-geth verifier (used by `MainnetVerifier`) |
| `NEW_SGXRETH_VERIFIER`         | `0x9D3C595BFf6Ff7D2b2CbdEcF94aD917eB2fCFFd8` | New SGX-reth verifier (used by `MainnetVerifier`) |

The `MainnetInbox` implementation links two libraries deployed via the canonical CREATE2 deployer:
`LibForcedInclusion` (`0x02747F462Ce82fdC5F8Fb01Fb98dfb71C8eb65b5`) and `LibInboxSetup`
(`0xB71afBDa15ad72A6e69Eba27A8C14EC46f31Fbe8`).

### Proxy upgrades — current impl → new impl

| Contract      | codediff                                                                                                                                 | Proxy                                        | Current implementation                       | New implementation                           |
| ------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------- | -------------------------------------------- | -------------------------------------------- |
| Inbox         | https://codediff.taiko.xyz/?addr=0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f&newimpl=0x724012AECFdF963ea962f90a2743E66f870564C2&chainid=1 | `0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f` | `0x349Ae3578f48F758d79451EeAB61Cdd5fedD0098` | `0x724012AECFdF963ea962f90a2743E66f870564C2` |
| SignalService | https://codediff.taiko.xyz/?addr=0x9e0a24964e5397B566c1ed39258e21aB5E35C77C&newimpl=0x1A06832992785766a105838C95c1E13a0045AC85&chainid=1 | `0x9e0a24964e5397B566c1ed39258e21aB5E35C77C` | `0xBC442F342FE247Dc7981AC7Fbe8293c8891F8752` | `0x1A06832992785766a105838C95c1E13a0045AC85` |
| Bridge        | https://codediff.taiko.xyz/?addr=0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC&newimpl=0x1c94D798CFA08F396E5BA9F81697289c53273381&chainid=1 | `0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC` | `0x2705B12a971dA766A3f9321a743d61ceAD67dA2F` | `0x1c94D798CFA08F396E5BA9F81697289c53273381` |
| ERC20Vault    | https://codediff.taiko.xyz/?addr=0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab&newimpl=0x024253C6FDC27d3161aFd43fb0241411A28dDc3c&chainid=1 | `0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab` | `0xb20C8Ffc2dD49596508d262b6E8B6817e9790E63` | `0x024253C6FDC27d3161aFd43fb0241411A28dDc3c` |

### Replaced verifiers — old impl → new impl

The new MainnetVerifier reuses the existing RISC0/SP1 verifiers and swaps in the two new SGX
verifiers. Old addresses read on-chain: live Inbox `getConfig().proofVerifier` → its
`sgxGethVerifier()` / `sgxRethVerifier()`.

| Contract          | codediff                                                                                                                                 | Old impl                                     | New impl                                     |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------- | -------------------------------------------- |
| MainnetVerifier   | https://codediff.taiko.xyz/?addr=0x9cAa4948381590900FCdd8a4F06EB24138eD665d&newimpl=0x0834aCfE76C46054d12478511b79Bf473a154A86&chainid=1 | `0x9cAa4948381590900FCdd8a4F06EB24138eD665d` | `0x0834aCfE76C46054d12478511b79Bf473a154A86` |
| SGX-geth verifier | https://codediff.taiko.xyz/?addr=0x08568Df252ecf37D6C3eFD24f6ca3688118697F1&newimpl=0x41e79EB4F03aBB5DF8716B759528dc5d8f6a84Ee&chainid=1 | `0x08568Df252ecf37D6C3eFD24f6ca3688118697F1` | `0x41e79EB4F03aBB5DF8716B759528dc5d8f6a84Ee` |
| SGX-reth verifier | https://codediff.taiko.xyz/?addr=0xa1018Ba2e22139076f91dA2A856B2CAB22d968F6&newimpl=0x9D3C595BFf6Ff7D2b2CbdEcF94aD917eB2fCFFd8&chainid=1 | `0xa1018Ba2e22139076f91dA2A856B2CAB22d968F6` | `0x9D3C595BFf6Ff7D2b2CbdEcF94aD917eB2fCFFd8` |

### New contract — no predecessor

QuotaManager is introduced by this bundle (the live Bridge and ERC20Vault have no quota manager —
`quotaManager()` reverts), so there is no old impl to diff against; the link views its deployed
contract on Etherscan.

| Contract     | Etherscan                                                               | Address                                      |
| ------------ | ----------------------------------------------------------------------- | -------------------------------------------- |
| QuotaManager | https://etherscan.io/address/0xBaCb003f0B13CeAF09Eb9Baf5915A640BD4Bc6cC | `0xBaCb003f0B13CeAF09Eb9Baf5915A640BD4Bc6cC` |

### Linked libraries — Etherscan

Deployed via the canonical CREATE2 deployer and linked into the MainnetInbox implementation
(`0x7240…`).

| Library            | Etherscan                                                               | Address                                      |
| ------------------ | ----------------------------------------------------------------------- | -------------------------------------------- |
| LibForcedInclusion | https://etherscan.io/address/0x02747F462Ce82fdC5F8Fb01Fb98dfb71C8eb65b5 | `0x02747F462Ce82fdC5F8Fb01Fb98dfb71C8eb65b5` |
| LibInboxSetup      | https://etherscan.io/address/0xB71afBDa15ad72A6e69Eba27A8C14EC46f31Fbe8 | `0xB71afBDa15ad72A6e69Eba27A8C14EC46f31Fbe8` |

## New QuotaManager

The new `QUOTA_MANAGER` is an immutable, non-UUPS contract deployed before this proposal. The new
`MAINNET_BRIDGE_NEW_IMPL` and `MAINNET_ERC20_VAULT_NEW_IMPL` must both be deployed with this exact
address in their constructors.

The new QuotaManager is temporarily owned by `admin.taiko.eth`
(`0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F`) so the Taiko admin can adjust quotas in an
emergency. The constructor must also set the existing L1 Bridge proxy
(`0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC`) and ERC20Vault proxy
(`0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab`) as the only quota consumers.

The QuotaManager constructor must initialize the following token quotas:

| Token | Address                                      | Constructor Quota  |
| ----- | -------------------------------------------- | ------------------ |
| ETH   | `address(0)`                                 | `250 ether`        |
| WETH  | `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2` | `250 ether`        |
| TKO   | `0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800` | `10,000,000 ether` |
| USDT  | `0xdAC17F958D2ee523a2206206994597C13D831ec7` | `150,000,000,000`  |
| USDC  | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` | `150,000,000,000`  |

## Retriable Messages

Current `Bridge.messageStatus(bytes32)` for all three hashes is `1` (`RETRIABLE`). These were the
only hashes left in `RETRIABLE` status after enumerating `MessageStatusChanged` events in the
incident window.

| Message Hash                                                         | Evidence                                                                                                                                            |
| -------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| `0x997216448ef88e6398e82b0f003abb8637d25441ca6d22b09a65f63ef077480a` | `MessageStatusChanged(..., RETRIABLE)`, block `25,367,938`, tx `0x2f44dc1b883522a88f9b0cbbdfabf9ec33884b69dd4326600c3fab7fb2277260`, logIndex `4`   |
| `0xf2994252987db0f55b6accdf1ff979bc508cd4acfcc229ad64b23a67f6fd984d` | `MessageStatusChanged(..., RETRIABLE)`, block `25,367,938`, tx `0x2f44dc1b883522a88f9b0cbbdfabf9ec33884b69dd4326600c3fab7fb2277260`, logIndex `6`   |
| `0xea26be1009e743aec78e1f566e91db0b9fda29e16fec1e72e2d74c6983a68e70` | `MessageStatusChanged(..., RETRIABLE)`, block `25,368,925`, tx `0xabed9edc7c63191109617757814d8151110eb60b43329f4d36f0ebf5328ee96b`, logIndex `141` |

Etherscan links for these transactions are embedded as comments in `Proposal0017.s.sol`.

## Inbox State Recovery

The first forged proof transaction is
`0x2f44dc1b883522a88f9b0cbbdfabf9ec33884b69dd4326600c3fab7fb2277260` at L1 block
`25,367,938`.

`Inbox.getCoreState()` was queried at block `25,367,937`, exactly one block before that forged
proof. The proposal restores:

| Field                     | Value                                                                |
| ------------------------- | -------------------------------------------------------------------- |
| `lastFinalizedProposalId` | `18,051`                                                             |
| `lastFinalizedBlockHash`  | `0x64c2ada556b6862d2c8796e0f709c454fede9d03908711a9f04d9f9f9dcce470` |

For comparison, the forged proof finalized proposal `18,056` in block `25,367,938`, so proposal
`18,051` is the last correct finalized proposal before the incident.

## Verifier Cleanup

The proposal removes all trust entries currently enabled on the existing mainnet verifiers. Because
the new SGX verifier contracts keep using the existing SGX attesters, it also rotates MRSIGNER trust
on those attesters and trusts the new SGX-geth and SGX-reth MRENCLAVE values. New RISC0 and SP1
image/program IDs are pending and must be added in a follow-up edit once available.

### SGX MRSIGNER Values

`SGXGETH_ATTESTER.setMrSigner(mrSigner, trusted)` and
`SGXRETH_ATTESTER.setMrSigner(mrSigner, trusted)`:

- `0x48fa5bbad91d274735d238715913c8712a7505bb6d0dd832764bedb46d587013` -> `true`
- `0xca0583a715534a8c981b914589a7f0dc5d60959d9ae79fb5353299a4231673d5` -> `false`

### New SGX MRENCLAVE Values

These measurements come from the Raiko
[`hotfix-1.16.1-2`](https://github.com/taikoxyz/raiko/releases/tag/hotfix-1.16.1-2)
release image; see its
[`Reproduce MRENCLAVE`](https://github.com/taikoxyz/raiko/releases/tag/hotfix-1.16.1-2#reproduce-mrenclave)
notes for the reproduction steps.

`SGXGETH_ATTESTER.setMrEnclave(mrEnclave, trusted)`:

- `0xf1e2450016a361e082355526627229adb339cc85f04ec15d1cabd123c984aca9` -> `true`

`SGXRETH_ATTESTER.setMrEnclave(mrEnclave, trusted)`:

- `0xe30515ee34e76054335e96d66820ff835e8e16e3b63c048dbbc9ef3a794567ed` -> `true`

### RISC0 Image IDs

`RISC0_RETH_VERIFIER.setImageIdTrusted(id, false)`:

- `0x26abb0237d10e891443e2a76bd3c1f6704c1ad03c07cb2165f4afcfc64b3cee7`
- `0x46efe5e0c74976548ee6856789fbfb4929b8f2f9118a119c57ced6e1062e727b`
- `0x779c032b91d0730ef13b26eafa47b32df7ebdaa4ed766d587fe905530afa2544`
- `0xbee1be4cbe2bdf9b0034a1ab6572061a76019e73189ff96322e58ab229b75f92`
- `0xcecc85819e15d173c2991577727525b136e820728f7aaaede612f1281cac2249`
- `0xdfbce2039ad8b78b236b5a9dceba5d8cee0d9e4638fc8f1fe11a0b2d8bfa039e`

### SP1 Program IDs

`SP1_RETH_VERIFIER.setProgramTrusted(id, false)`:

- `0x0002ac747570512099ca19c17f5a3b9f39697e5617a19ff2f2b2464229a50c7c`
- `0x0026ff63d649779a5dbc88c3359ab83399a21fb6ef9b7ec082f77a8a465806e7`
- `0x0033e2cccc3296e7def7b381a4fb96fafec64f45420b6d24686779ef6236dff1`
- `0x0079682c7b5af614273de79761aaad20d1c8e1a65091388b81be836632d382f8`
- `0x008e24716118be9594358d8882d93d5425f0827cf0a7a4fd0ea2fc4414debfe7`
- `0x009d26a03d10b4e70eef6a339187c258a7701d6a0150524684cb46b56cf9e540`
- `0x01563a3a5c1448263943382f75a3b9f34b4bf2b05e867fcb65648c8429a50c7c`
- `0x137fb1eb125de6973791186659ab83394d10fdb73e6dfb0205eef514465806e7`
- `0x19f166660ca5b9f75ef670344fb96faf76327a2a082db49150cef3de6236dff1`
- `0x3cb4163d56bd850967bcf2ec1aaad20d0e470d324244e22e037d06cc32d382f8`
- `0x471238b0462fa56506b1b1102d93d5422f8413e7429e93f41d45f88814debfe7`
- `0x4e93501e442d39c35ded4672187c258a3b80eb500541491a09968d6a6cf9e540`

### SGX-geth MRENCLAVE Values

`SGXGETH_ATTESTER.setMrEnclave(mrEnclave, false)`:

- `0x398be8424f27802b38e6e8d3413bf6a0b187349e68522a218f5bfc00279006ac`
- `0x3e6113a23bbdf9231520153253047d02db8f1dd38a9b52914ab7943278f52db0`
- `0x692c8624d30a327340b0dfbb67203e941175ac700d1a058c717e5269103d37e6`
- `0xd1f43acede51c4eb2f66b86cce52682edad80b810b9d87fba3a9b67254c91b77`
- `0xfda8bb1fc9938700c25353c0a5fabc96a238e69ce8e35f08e558831a20db33a6`

### SGX-reth MRENCLAVE Values

`SGXRETH_ATTESTER.setMrEnclave(mrEnclave, false)`:

- `0x13ea9869632ac20b176ae0fdc39998b2a644a695db024ef7fe0e4b3c59084160`
- `0x3551faac39edee5abfaa19ab065c217db1485aebae255a9edddf6dfff6b29b52`
- `0x3b589538b775ddbfc5fb028167ff846116159e6687aef9f849ca5a70a7871ea5`
- `0x3f71cf178a032816c2731a43aef746c464a5326e891dc881773ec2b599b2cf0a`
- `0x482b06132c4306ea55bc34ff90d46532ff4151f473dbfe4d2cb2442af2ff288b`
- `0x59bf7d48610cc8a56ba8a390b68c31a1443297869b174aeacac67dc152820f0e`
- `0x605ad10c1a56ed7289f198d64a39a952cd3b8a0bed3fcb19c8301c1847dc3a2f`
- `0x631778b0d420d2d0bba4c730b0fd74857afeefb3429371ae97ab450e40ca127e`
- `0x67742ab222790e20ba3656b3b294645a3384a5df5a770b86f8c06529523d990e`
- `0x6e43c1d575b5b785d0f6259dfac44998c6f0c164864f9f98270fb740c14eb943`
- `0x72258d3cae0e9901d0efc1f630064f1c44f11950bd25fee0b62ec8df84532da2`
- `0x8f73135b83a84126c7fff37ea02f9363e134aea0f6446b13e198b20d94e75099`
- `0x9546301721e2ea111ab0f79b6e529d6bb6c486ac98bcf7739429ad06c09db63d`
- `0xa096348d480eb0474f5eab182671933c029545521960d87d4e49283005809be9`
- `0xa4eedfc6484494d4c08bfb9b9dd887c6e0540ba9d8ee207fe0e16814852e3356`
- `0xa5f741bfed254a1e21738d429e7bd074e25918af7f71fbe1e0135c3974b06e00`
- `0xb09f9005e4612526e378466b5c16ab6028478e81c085812d6ed37166c4cda10e`
- `0xbdec26abd36fde2cfbb8db7a0793a9346b11bd558b39890407d458500711c88c`
- `0xc90e5d2e39d1d3f8397a6048c32ba50139d1577c28985e1f7638785935f41734`
- `0xca349ba0dfeced0bd837a56c97417c11e51d490eec4ff08321dd130776a413bd`
- `0xdcd483d3406d9b1871bb92420f5a080c4372e0d6b8522a4a2cb91a0f736669c6`
- `0xddda8ba9c9153e3d2f680f2f53adbc774a9753cc55d40dde4cb02aef38c42109`
- `0xdfcb4fca3073e3f3a90b05d328688c32619d56f26789c0a9797aa10e765a7807`
- `0xe2375b778ee5700a73c7fcf449abb4a62e00127d324b6694898073ba5aff4f5c`
- `0xe5774b71990b0d5f3eca8d4d22546764dd9549c743a1a6d4d4863d97f6b8c67a`
- `0xf285b7cbd78d2b96cdc54cfea3e47d8f510a4b4f91b719c97f8bbb90974f805b`

## Verification

Before submission:

1. Confirm the eight deployed addresses in `Proposal0017.s.sol` match the deployment broadcast
   (`broadcast/DeployHackRecoveryContracts.s.sol/1`, commit `b73608696`).
2. Confirm the new `MainnetVerifier` was deployed with the new SGX-geth and SGX-reth verifier
   contracts.
3. Confirm the new `MainnetInbox` implementation was deployed with the new `MAINNET_VERIFIER`.
4. Confirm the new Bridge and ERC20Vault implementations were deployed with the new immutable
   `QUOTA_MANAGER`.
5. Confirm bytecode exists at each implementation, new QuotaManager, and new verifier address:

   ```bash
   cast code <IMPLEMENTATION_ADDRESS> --rpc-url <RPC_URL>
   ```

6. Confirm each production target is owned by the DAO Controller:

   ```bash
   cast call <TARGET> "owner()(address)" --rpc-url <RPC_URL>
   ```

   Expected: `0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a`.

7. Confirm the new QuotaManager is owned by `admin.taiko.eth`, has a `86400` second quota period,
   and has the constructor quota values listed above:

   ```bash
   cast call <QUOTA_MANAGER> "tokenQuota(address)(uint48,uint104,uint104)" <TOKEN> --rpc-url <RPC_URL>
   ```

8. Confirm the three message hashes still return `RETRIABLE` before execution:

   ```bash
   cast call 0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC \
     "messageStatus(bytes32)(uint8)" \
     <MESSAGE_HASH> \
     --rpc-url <RPC_URL>
   ```

   Expected: `1`.

9. Confirm the pre-forgery recovery state:

   ```bash
   cast call 0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f \
     "getCoreState()(uint48,uint48,uint48,uint64,uint64,bytes32)" \
     --block 25367937 \
     --rpc-url <ARCHIVE_RPC_URL>
   ```

10. Confirm every verifier cleanup target is still trusted before execution, confirm the new
    MRSIGNER and new MRENCLAVE values are not yet trusted, and confirm the old MRSIGNER is still
    trusted.
11. Generate calldata:

```bash
P=0017 pnpm proposal
```

12. Dryrun on L1:

```bash
P=0017 pnpm proposal:dryrun:l1
```

After execution:

1. Confirm proxy implementations match the four replacement constants.
2. Confirm the three message hashes return `2` (`DONE`).
3. Confirm `Bridge` and `ERC20Vault` behavior uses the new immutable `QUOTA_MANAGER`, and that
   `tokenQuota(token).quota` still matches the constructor quota table above.
4. Confirm `Inbox.getCoreState()` matches the restored state.
5. Confirm the new MRSIGNER and new SGX MRENCLAVE values return true on the SGX attesters.
6. Confirm the old MRSIGNER and every removed RISC0, SP1, and stale SGX MRENCLAVE entry returns
   false.

## Security Contacts

- security@taiko.xyz
