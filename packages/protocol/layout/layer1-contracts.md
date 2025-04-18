## ERC1155Vault

Slot Type Name

---

0 t_uint8 \_initialized
0 t_bool \_initializing
1 t_array(t_uint256)50_storage **gap
51 t_address \_owner
52 t_array(t_uint256)49_storage **gap
101 t_address \_pendingOwner
102 t_array(t_uint256)49_storage **gap
151 t_array(t_uint256)50_storage **gapFromOldAddressResolver
201 t_uint8 **reentry
201 t_uint8 **paused
202 t_array(t_uint256)49_storage **gap
251 t_array(t_uint256)50_storage **gap
301 t_mapping(t_address,t_struct(CanonicalNFT)1190_storage) bridgedToCanonical
302 t_mapping(t_uint256,t_mapping(t_address,t_address)) canonicalToBridged
303 t_array(t_uint256)48_storage **gap
351 t_array(t_uint256)50_storage **gap
401 t_array(t_uint256)50_storage **gap
451 t_array(t_uint256)50_storage **gap

## ERC20Vault

Slot Type Name

---

0 t_uint8 \_initialized
0 t_bool \_initializing
1 t_array(t_uint256)50_storage **gap
51 t_address \_owner
52 t_array(t_uint256)49_storage **gap
101 t_address \_pendingOwner
102 t_array(t_uint256)49_storage **gap
151 t_array(t_uint256)50_storage **gapFromOldAddressResolver
201 t_uint8 **reentry
201 t_uint8 **paused
202 t_array(t_uint256)49_storage **gap
251 t_array(t_uint256)50_storage **gap
301 t_mapping(t_address,t_struct(CanonicalERC20)2055_storage) bridgedToCanonical
302 t_mapping(t_uint256,t_mapping(t_address,t_address)) canonicalToBridged
303 t_mapping(t_address,t_bool) btokenDenylist
304 t_mapping(t_uint256,t_mapping(t_address,t_uint256)) lastMigrationStart
305 t_mapping(t_bytes32,t_address) solverConditionToSolver
306 t_array(t_uint256)45_storage \_\_gap

## ERC20VaultOriginal

Slot Type Name

---

0 t_uint8 \_initialized
0 t_bool \_initializing
1 t_array(t_uint256)50_storage **gap
51 t_address \_owner
52 t_array(t_uint256)49_storage **gap
101 t_address \_pendingOwner
102 t_array(t_uint256)49_storage **gap
151 t_array(t_uint256)50_storage **gapFromOldAddressResolver
201 t_uint8 **reentry
201 t_uint8 **paused
202 t_array(t_uint256)49_storage **gap
251 t_array(t_uint256)50_storage **gap
301 t_mapping(t_address,t_struct(CanonicalERC20)1497_storage) bridgedToCanonical
302 t_mapping(t_uint256,t_mapping(t_address,t_address)) canonicalToBridged
303 t_mapping(t_address,t_bool) btokenDenylist
304 t_mapping(t_uint256,t_mapping(t_address,t_uint256)) lastMigrationStart
305 t_array(t_uint256)46_storage \_\_gap

## ERC721Vault

Slot Type Name

---

0 t_uint8 \_initialized
0 t_bool \_initializing
1 t_array(t_uint256)50_storage **gap
51 t_address \_owner
52 t_array(t_uint256)49_storage **gap
101 t_address \_pendingOwner
102 t_array(t_uint256)49_storage **gap
151 t_array(t_uint256)50_storage **gapFromOldAddressResolver
201 t_uint8 **reentry
201 t_uint8 **paused
202 t_array(t_uint256)49_storage **gap
251 t_array(t_uint256)50_storage **gap
301 t_mapping(t_address,t_struct(CanonicalNFT)1190_storage) bridgedToCanonical
302 t_mapping(t_uint256,t_mapping(t_address,t_address)) canonicalToBridged
303 t_array(t_uint256)48_storage **gap
351 t_array(t_uint256)50_storage **gap

## BridgedERC20

Slot Type Name

---

0 t_uint8 \_initialized
0 t_bool \_initializing
1 t_array(t_uint256)50_storage **gap
51 t_address \_owner
52 t_array(t_uint256)49_storage **gap
101 t_address \_pendingOwner
102 t_array(t_uint256)49_storage **gap
151 t_array(t_uint256)50_storage **gapFromOldAddressResolver
201 t_uint8 **reentry
201 t_uint8 **paused
202 t_array(t_uint256)49_storage **gap
251 t_mapping(t_address,t_uint256) \_balances
252 t_mapping(t_address,t_mapping(t_address,t_uint256)) \_allowances
253 t_uint256 \_totalSupply
254 t_string_storage \_name
255 t_string_storage \_symbol
256 t_array(t_uint256)45_storage **gap
301 t_address srcToken
301 t_uint8 **srcDecimals
302 t_uint256 srcChainId
303 t_address migratingAddress
303 t_bool migratingInbound
304 t_array(t_uint256)47_storage **gap

## BridgedERC20V2

Slot Type Name

---

0 t_uint8 \_initialized
0 t_bool \_initializing
1 t_array(t_uint256)50_storage **gap
51 t_address \_owner
52 t_array(t_uint256)49_storage **gap
101 t_address \_pendingOwner
102 t_array(t_uint256)49_storage **gap
151 t_array(t_uint256)50_storage **gapFromOldAddressResolver
201 t_uint8 **reentry
201 t_uint8 **paused
202 t_array(t_uint256)49_storage **gap
251 t_mapping(t_address,t_uint256) \_balances
252 t_mapping(t_address,t_mapping(t_address,t_uint256)) \_allowances
253 t_uint256 \_totalSupply
254 t_string_storage \_name
255 t_string_storage \_symbol
256 t_array(t_uint256)45_storage **gap
301 t_address srcToken
301 t_uint8 **srcDecimals
302 t_uint256 srcChainId
303 t_address migratingAddress
303 t_bool migratingInbound
304 t_array(t_uint256)47_storage **gap
351 t_bytes32 \_hashedName
352 t_bytes32 \_hashedVersion
353 t_string_storage \_name
354 t_string_storage \_version
355 t_array(t_uint256)48_storage **gap
403 t_mapping(t_address,t_struct(Counter)3147_storage) \_nonces
404 t_array(t_uint256)49_storage **gap

## BridgedERC721

Slot Type Name

---

0 t_uint8 \_initialized
0 t_bool \_initializing
1 t_array(t_uint256)50_storage **gap
51 t_address \_owner
52 t_array(t_uint256)49_storage **gap
101 t_address \_pendingOwner
102 t_array(t_uint256)49_storage **gap
151 t_array(t_uint256)50_storage **gapFromOldAddressResolver
201 t_uint8 **reentry
201 t_uint8 **paused
202 t_array(t_uint256)49_storage **gap
251 t_array(t_uint256)50_storage **gap
301 t_string_storage \_name
302 t_string_storage \_symbol
303 t_mapping(t_uint256,t_address) \_owners
304 t_mapping(t_address,t_uint256) \_balances
305 t_mapping(t_uint256,t_address) \_tokenApprovals
306 t_mapping(t_address,t_mapping(t_address,t_bool)) \_operatorApprovals
307 t_array(t_uint256)44_storage **gap
351 t_address srcToken
352 t_uint256 srcChainId
353 t_array(t_uint256)48_storage **gap

## BridgedERC1155

Slot Type Name

---

0 t_uint8 \_initialized
0 t_bool \_initializing
1 t_array(t_uint256)50_storage **gap
51 t_address \_owner
52 t_array(t_uint256)49_storage **gap
101 t_address \_pendingOwner
102 t_array(t_uint256)49_storage **gap
151 t_array(t_uint256)50_storage **gapFromOldAddressResolver
201 t_uint8 **reentry
201 t_uint8 **paused
202 t_array(t_uint256)49_storage **gap
251 t_array(t_uint256)50_storage **gap
301 t_mapping(t_uint256,t_mapping(t_address,t_uint256)) \_balances
302 t_mapping(t_address,t_mapping(t_address,t_bool)) \_operatorApprovals
303 t_string_storage \_uri
304 t_array(t_uint256)47_storage **gap
351 t_address srcToken
352 t_uint256 srcChainId
353 t_string_storage symbol
354 t_string_storage name
355 t_array(t_uint256)46_storage **gap

## Bridge

Slot Type Name

---

0 t_uint8 \_initialized
0 t_bool \_initializing
1 t_array(t_uint256)50_storage **gap
51 t_address \_owner
52 t_array(t_uint256)49_storage **gap
101 t_address \_pendingOwner
102 t_array(t_uint256)49_storage **gap
151 t_array(t_uint256)50_storage **gapFromOldAddressResolver
201 t_uint8 **reentry
201 t_uint8 **paused
202 t_array(t_uint256)49_storage **gap
251 t_uint64 **reserved1
251 t_uint64 nextMessageId
252 t_mapping(t_bytes32,t_enum(Status)1680) messageStatus
253 t_struct(Context)1715_storage **ctx
255 t_uint256 **reserved2
256 t_uint256 **reserved3
257 t_array(t_uint256)44_storage **gap

## QuotaManager

Slot Type Name

---

0 t_uint8 \_initialized
0 t_bool \_initializing
1 t_array(t_uint256)50_storage **gap
51 t_address \_owner
52 t_array(t_uint256)49_storage **gap
101 t_address \_pendingOwner
102 t_array(t_uint256)49_storage **gap
151 t_array(t_uint256)50_storage **gapFromOldAddressResolver
201 t_uint8 **reentry
201 t_uint8 **paused
202 t_array(t_uint256)49_storage **gap
251 t_mapping(t_address,t_struct(Quota)32_storage) tokenQuota
252 t_uint24 quotaPeriod
253 t_array(t_uint256)48_storage **gap

## DefaultResolver

Slot Type Name

---

0 t_uint8 \_initialized
0 t_bool \_initializing
1 t_array(t_uint256)50_storage **gap
51 t_address \_owner
52 t_array(t_uint256)49_storage **gap
101 t_address \_pendingOwner
102 t_array(t_uint256)49_storage **gap
151 t_array(t_uint256)50_storage **gapFromOldAddressResolver
201 t_uint8 **reentry
201 t_uint8 **paused
202 t_array(t_uint256)49_storage **gap
251 t_mapping(t_uint256,t_mapping(t_bytes32,t_address)) **addresses
252 t_array(t_uint256)49_storage \_\_gap

## EssentialContract

Slot Type Name

---

0 t_uint8 \_initialized
0 t_bool \_initializing
1 t_array(t_uint256)50_storage **gap
51 t_address \_owner
52 t_array(t_uint256)49_storage **gap
101 t_address \_pendingOwner
102 t_array(t_uint256)49_storage **gap
151 t_array(t_uint256)50_storage **gapFromOldAddressResolver
201 t_uint8 **reentry
201 t_uint8 **paused
202 t_array(t_uint256)49_storage \_\_gap

## SignalService

Slot Type Name

---

0 t_uint8 \_initialized
0 t_bool \_initializing
1 t_array(t_uint256)50_storage **gap
51 t_address \_owner
52 t_array(t_uint256)49_storage **gap
101 t_address \_pendingOwner
102 t_array(t_uint256)49_storage **gap
151 t_array(t_uint256)50_storage **gapFromOldAddressResolver
201 t_uint8 **reentry
201 t_uint8 **paused
202 t_array(t_uint256)49_storage **gap
251 t_mapping(t_uint64,t_mapping(t_bytes32,t_uint64)) topBlockId
252 t_mapping(t_address,t_bool) isAuthorized
253 t_mapping(t_bytes32,t_bool) \_receivedSignals
254 t_array(t_uint256)47_storage **gap

## TaikoToken

Slot Type Name

---

0 t_uint8 \_initialized
0 t_bool \_initializing
1 t_array(t_uint256)50_storage **gap
51 t_address \_owner
52 t_array(t_uint256)49_storage **gap
101 t_address \_pendingOwner
102 t_array(t_uint256)49_storage **gap
151 t_array(t_uint256)50_storage **gapFromOldAddressResolver
201 t_uint8 **reentry
201 t_uint8 **paused
202 t_array(t_uint256)49_storage **gap
251 t_array(t_uint256)50_storage **slots_previously_used_by_ERC20SnapshotUpgradeable
301 t_mapping(t_address,t_uint256) \_balances
302 t_mapping(t_address,t_mapping(t_address,t_uint256)) \_allowances
303 t_uint256 \_totalSupply
304 t_string_storage \_name
305 t_string_storage \_symbol
306 t_array(t_uint256)45_storage **gap
351 t_bytes32 \_hashedName
352 t_bytes32 \_hashedVersion
353 t_string_storage \_name
354 t_string_storage \_version
355 t_array(t_uint256)48_storage **gap
403 t_mapping(t_address,t_struct(Counter)3579_storage) \_nonces
404 t_bytes32 \_PERMIT_TYPEHASH_DEPRECATED_SLOT
405 t_array(t_uint256)49_storage **gap
454 t_mapping(t_address,t_address) \_delegates
455 t_mapping(t_address,t_array(t_struct(Checkpoint)2397_storage)dyn_storage) \_checkpoints
456 t_array(t_struct(Checkpoint)2397_storage)dyn_storage \_totalSupplyCheckpoints
457 t_array(t_uint256)47_storage **gap
504 t_array(t_uint256)50_storage \_\_gap

## SgxAndZkVerifier

Slot Type Name

---

0 t_uint8 \_initialized
0 t_bool \_initializing
1 t_array(t_uint256)50_storage **gap
51 t_address \_owner
52 t_array(t_uint256)49_storage **gap
101 t_address \_pendingOwner
102 t_array(t_uint256)49_storage **gap
151 t_array(t_uint256)50_storage **gapFromOldAddressResolver
201 t_uint8 **reentry
201 t_uint8 **paused
202 t_array(t_uint256)49_storage **gap
251 t_array(t_uint256)50_storage **gap
301 t_array(t_uint256)50_storage \_\_gap

## Risc0Verifier

Slot Type Name

---

0 t_uint8 \_initialized
0 t_bool \_initializing
1 t_array(t_uint256)50_storage **gap
51 t_address \_owner
52 t_array(t_uint256)49_storage **gap
101 t_address \_pendingOwner
102 t_array(t_uint256)49_storage **gap
151 t_array(t_uint256)50_storage **gapFromOldAddressResolver
201 t_uint8 **reentry
201 t_uint8 **paused
202 t_array(t_uint256)49_storage **gap
251 t_mapping(t_bytes32,t_bool) isImageTrusted
252 t_array(t_uint256)49_storage **gap

## SP1Verifier

Slot Type Name

---

0 t_uint8 \_initialized
0 t_bool \_initializing
1 t_array(t_uint256)50_storage **gap
51 t_address \_owner
52 t_array(t_uint256)49_storage **gap
101 t_address \_pendingOwner
102 t_array(t_uint256)49_storage **gap
151 t_array(t_uint256)50_storage **gapFromOldAddressResolver
201 t_uint8 **reentry
201 t_uint8 **paused
202 t_array(t_uint256)49_storage **gap
251 t_mapping(t_bytes32,t_bool) isProgramTrusted
252 t_array(t_uint256)49_storage **gap

## SgxVerifier

Slot Type Name

---

0 t_uint8 \_initialized
0 t_bool \_initializing
1 t_array(t_uint256)50_storage **gap
51 t_address \_owner
52 t_array(t_uint256)49_storage **gap
101 t_address \_pendingOwner
102 t_array(t_uint256)49_storage **gap
151 t_array(t_uint256)50_storage **gapFromOldAddressResolver
201 t_uint8 **reentry
201 t_uint8 **paused
202 t_array(t_uint256)49_storage **gap
251 t_uint256 nextInstanceId
252 t_mapping(t_uint256,t_struct(Instance)728_storage) instances
253 t_mapping(t_address,t_bool) addressRegistered
254 t_array(t_uint256)47_storage **gap

## AutomataDcapV3Attestation

Slot Type Name

---

0 t_uint8 \_initialized
0 t_bool \_initializing
1 t_array(t_uint256)50_storage **gap
51 t_address \_owner
52 t_array(t_uint256)49_storage **gap
101 t_address \_pendingOwner
102 t_array(t_uint256)49_storage **gap
151 t_array(t_uint256)50_storage **gapFromOldAddressResolver
201 t_uint8 **reentry
201 t_uint8 **paused
202 t_array(t_uint256)49_storage **gap
251 t_contract(ISigVerifyLib)1359 sigVerifyLib
252 t_contract(IPEMCertChainLib)3949 pemCertLib
252 t_bool checkLocalEnclaveReport
253 t_mapping(t_bytes32,t_bool) trustedUserMrEnclave
254 t_mapping(t_bytes32,t_bool) trustedUserMrSigner
255 t_mapping(t_uint256,t_mapping(t_bytes_memory_ptr,t_bool)) serialNumIsRevoked
256 t_mapping(t_string_memory_ptr,t_struct(TCBInfo)3863_storage) tcbInfo
257 t_struct(EnclaveId)1379_storage qeIdentity
261 t_array(t_uint256)39_storage **gap

## TaikoInbox

Slot Type Name

---

0 t_uint8 \_initialized
0 t_bool \_initializing
1 t_array(t_uint256)50_storage **gap
51 t_address \_owner
52 t_array(t_uint256)49_storage **gap
101 t_address \_pendingOwner
102 t_array(t_uint256)49_storage **gap
151 t_array(t_uint256)50_storage **gapFromOldAddressResolver
201 t_uint8 **reentry
201 t_uint8 **paused
202 t_array(t_uint256)49_storage **gap
251 t_struct(State)269_storage state
301 t_array(t_uint256)50_storage **gap

## HeklaInbox

Slot Type Name

---

0 t_uint8 \_initialized
0 t_bool \_initializing
1 t_array(t_uint256)50_storage **gap
51 t_address \_owner
52 t_array(t_uint256)49_storage **gap
101 t_address \_pendingOwner
102 t_array(t_uint256)49_storage **gap
151 t_array(t_uint256)50_storage **gapFromOldAddressResolver
201 t_uint8 **reentry
201 t_uint8 **paused
202 t_array(t_uint256)49_storage **gap
251 t_struct(State)269_storage state
301 t_array(t_uint256)50_storage **gap

## MainnetBridge

Slot Type Name

---

0 t_uint8 \_initialized
0 t_bool \_initializing
1 t_array(t_uint256)50_storage **gap
51 t_address \_owner
52 t_array(t_uint256)49_storage **gap
101 t_address \_pendingOwner
102 t_array(t_uint256)49_storage **gap
151 t_array(t_uint256)50_storage **gapFromOldAddressResolver
201 t_uint8 **reentry
201 t_uint8 **paused
202 t_array(t_uint256)49_storage **gap
251 t_uint64 **reserved1
251 t_uint64 nextMessageId
252 t_mapping(t_bytes32,t_enum(Status)1791) messageStatus
253 t_struct(Context)1826_storage **ctx
255 t_uint256 **reserved2
256 t_uint256 **reserved3
257 t_array(t_uint256)44_storage **gap

## MainnetSignalService

Slot Type Name

---

0 t_uint8 \_initialized
0 t_bool \_initializing
1 t_array(t_uint256)50_storage **gap
51 t_address \_owner
52 t_array(t_uint256)49_storage **gap
101 t_address \_pendingOwner
102 t_array(t_uint256)49_storage **gap
151 t_array(t_uint256)50_storage **gapFromOldAddressResolver
201 t_uint8 **reentry
201 t_uint8 **paused
202 t_array(t_uint256)49_storage **gap
251 t_mapping(t_uint64,t_mapping(t_bytes32,t_uint64)) topBlockId
252 t_mapping(t_address,t_bool) isAuthorized
253 t_mapping(t_bytes32,t_bool) \_receivedSignals
254 t_array(t_uint256)47_storage **gap

## MainnetERC20Vault

Slot Type Name

---

0 t_uint8 \_initialized
0 t_bool \_initializing
1 t_array(t_uint256)50_storage **gap
51 t_address \_owner
52 t_array(t_uint256)49_storage **gap
101 t_address \_pendingOwner
102 t_array(t_uint256)49_storage **gap
151 t_array(t_uint256)50_storage **gapFromOldAddressResolver
201 t_uint8 **reentry
201 t_uint8 **paused
202 t_array(t_uint256)49_storage **gap
251 t_array(t_uint256)50_storage **gap
301 t_mapping(t_address,t_struct(CanonicalERC20)1561_storage) bridgedToCanonical
302 t_mapping(t_uint256,t_mapping(t_address,t_address)) canonicalToBridged
303 t_mapping(t_address,t_bool) btokenDenylist
304 t_mapping(t_uint256,t_mapping(t_address,t_uint256)) lastMigrationStart
305 t_array(t_uint256)46_storage \_\_gap

## MainnetERC1155Vault

Slot Type Name

---

0 t_uint8 \_initialized
0 t_bool \_initializing
1 t_array(t_uint256)50_storage **gap
51 t_address \_owner
52 t_array(t_uint256)49_storage **gap
101 t_address \_pendingOwner
102 t_array(t_uint256)49_storage **gap
151 t_array(t_uint256)50_storage **gapFromOldAddressResolver
201 t_uint8 **reentry
201 t_uint8 **paused
202 t_array(t_uint256)49_storage **gap
251 t_array(t_uint256)50_storage **gap
301 t_mapping(t_address,t_struct(CanonicalNFT)1253_storage) bridgedToCanonical
302 t_mapping(t_uint256,t_mapping(t_address,t_address)) canonicalToBridged
303 t_array(t_uint256)48_storage **gap
351 t_array(t_uint256)50_storage **gap
401 t_array(t_uint256)50_storage **gap
451 t_array(t_uint256)50_storage **gap

## MainnetERC721Vault

Slot Type Name

---

0 t_uint8 \_initialized
0 t_bool \_initializing
1 t_array(t_uint256)50_storage **gap
51 t_address \_owner
52 t_array(t_uint256)49_storage **gap
101 t_address \_pendingOwner
102 t_array(t_uint256)49_storage **gap
151 t_array(t_uint256)50_storage **gapFromOldAddressResolver
201 t_uint8 **reentry
201 t_uint8 **paused
202 t_array(t_uint256)49_storage **gap
251 t_array(t_uint256)50_storage **gap
301 t_mapping(t_address,t_struct(CanonicalNFT)1253_storage) bridgedToCanonical
302 t_mapping(t_uint256,t_mapping(t_address,t_address)) canonicalToBridged
303 t_array(t_uint256)48_storage **gap
351 t_array(t_uint256)50_storage **gap

## MainnetInbox

Slot Type Name

---

0 t_uint8 \_initialized
0 t_bool \_initializing
1 t_array(t_uint256)50_storage **gap
51 t_address \_owner
52 t_array(t_uint256)49_storage **gap
101 t_address \_pendingOwner
102 t_array(t_uint256)49_storage **gap
151 t_array(t_uint256)50_storage **gapFromOldAddressResolver
201 t_uint8 **reentry
201 t_uint8 **paused
202 t_array(t_uint256)49_storage **gap
251 t_struct(State)269_storage state
301 t_array(t_uint256)50_storage **gap

## TokenUnlock

Slot Type Name

---

0 t_uint8 \_initialized
0 t_bool \_initializing
1 t_array(t_uint256)50_storage **gap
51 t_address \_owner
52 t_array(t_uint256)49_storage **gap
101 t_address \_pendingOwner
102 t_array(t_uint256)49_storage **gap
151 t_array(t_uint256)50_storage **gapFromOldAddressResolver
201 t_uint8 **reentry
201 t_uint8 **paused
202 t_array(t_uint256)49_storage **gap
251 t_uint256 amountVested
252 t_address recipient
252 t_uint64 tgeTimestamp
253 t_mapping(t_address,t_bool) isProverSet
254 t_array(t_uint256)47_storage **gap

## ProverSet

Slot Type Name

---

0 t_uint8 \_initialized
0 t_bool \_initializing
1 t_array(t_uint256)50_storage **gap
51 t_address \_owner
52 t_array(t_uint256)49_storage **gap
101 t_address \_pendingOwner
102 t_array(t_uint256)49_storage **gap
151 t_array(t_uint256)50_storage **gapFromOldAddressResolver
201 t_uint8 **reentry
201 t_uint8 **paused
202 t_array(t_uint256)49_storage **gap
251 t_mapping(t_address,t_bool) isProver
252 t_address admin
253 t_array(t_uint256)48_storage **gap

## ForkRouter

Slot Type Name

---

0 t_uint8 \_initialized
0 t_bool \_initializing
1 t_array(t_uint256)50_storage **gap
51 t_address \_owner
52 t_array(t_uint256)49_storage **gap
101 t_address \_pendingOwner
102 t_array(t_uint256)49_storage \_\_gap

## TaikoWrapper

Slot Type Name

---

0 t_uint8 \_initialized
0 t_bool \_initializing
1 t_array(t_uint256)50_storage **gap
51 t_address \_owner
52 t_array(t_uint256)49_storage **gap
101 t_address \_pendingOwner
102 t_array(t_uint256)49_storage **gap
151 t_array(t_uint256)50_storage **gapFromOldAddressResolver
201 t_uint8 **reentry
201 t_uint8 **paused
202 t_array(t_uint256)49_storage **gap
251 t_array(t_uint256)50_storage **gap

## ForcedInclusionStore

Slot Type Name

---

0 t_uint8 \_initialized
0 t_bool \_initializing
1 t_array(t_uint256)50_storage **gap
51 t_address \_owner
52 t_array(t_uint256)49_storage **gap
101 t_address \_pendingOwner
102 t_array(t_uint256)49_storage **gap
151 t_array(t_uint256)50_storage **gapFromOldAddressResolver
201 t_uint8 **reentry
201 t_uint8 **paused
202 t_array(t_uint256)49_storage **gap
251 t_mapping(t_uint256,t_struct(ForcedInclusion)961_storage) queue
252 t_uint64 head
252 t_uint64 tail
252 t_uint64 lastProcessedAtBatchId
252 t_uint64 **reserved1
253 t_array(t_uint256)48_storage \_\_gap

## PreconfRouter

Slot Type Name

---

0 t_uint8 \_initialized
0 t_bool \_initializing
1 t_array(t_uint256)50_storage **gap
51 t_address \_owner
52 t_array(t_uint256)49_storage **gap
101 t_address \_pendingOwner
102 t_array(t_uint256)49_storage **gap
151 t_array(t_uint256)50_storage **gapFromOldAddressResolver
201 t_uint8 **reentry
201 t_uint8 **paused
202 t_array(t_uint256)49_storage **gap
251 t_array(t_uint256)50_storage **gap

## PreconfWhitelist

Slot Type Name

---

0 t_uint8 \_initialized
0 t_bool \_initializing
1 t_array(t_uint256)50_storage **gap
51 t_address \_owner
52 t_array(t_uint256)49_storage **gap
101 t_address \_pendingOwner
102 t_array(t_uint256)49_storage **gap
151 t_array(t_uint256)50_storage **gapFromOldAddressResolver
201 t_uint8 **reentry
201 t_uint8 **paused
202 t_array(t_uint256)49_storage **gap
251 t_mapping(t_address,t_struct(OperatorInfo)72_storage) operators
252 t_mapping(t_uint256,t_address) operatorMapping
253 t_uint8 operatorCount
253 t_uint8 operatorChangeDelay
253 t_bool havingPerfectOperators
254 t_array(t_uint256)47_storage **gap

## TaikoTreasuryVault

Slot Type Name

---

0 t_uint8 \_initialized
0 t_bool \_initializing
1 t_array(t_uint256)50_storage **gap
51 t_address \_owner
52 t_array(t_uint256)49_storage **gap
101 t_address \_pendingOwner
102 t_array(t_uint256)49_storage **gap
151 t_array(t_uint256)50_storage **gapFromOldAddressResolver
201 t_uint8 **reentry
201 t_uint8 **paused
202 t_array(t_uint256)49_storage \_\_gap
