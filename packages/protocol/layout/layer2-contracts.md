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

## BridgedTaikoToken

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
403 t_mapping(t_address,t_struct(Counter)3610_storage) \_nonces
404 t_bytes32 \_PERMIT_TYPEHASH_DEPRECATED_SLOT
405 t_array(t_uint256)49_storage **gap
454 t_mapping(t_address,t_address) \_delegates
455 t_mapping(t_address,t_array(t_struct(Checkpoint)2428_storage)dyn_storage) \_checkpoints
456 t_array(t_struct(Checkpoint)2428_storage)dyn_storage \_totalSupplyCheckpoints
457 t_array(t_uint256)47_storage **gap
504 t_array(t_uint256)50_storage \_\_gap

## DelegateOwner

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
251 t_uint64 remoteChainId
251 t_address admin
252 t_uint64 nextTxId
252 t_address remoteOwner
253 t_array(t_uint256)48_storage **gap

## TaikoAnchor

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
251 t_mapping(t_uint256,t_bytes32) \_blockhashes
252 t_bytes32 publicInputHash
253 t_uint64 parentGasExcess
253 t_uint64 lastSyncedBlock
253 t_uint64 parentTimestamp
253 t_uint64 parentGasTarget
254 t_uint64 l1ChainId
255 t_array(t_uint256)46_storage **gap
