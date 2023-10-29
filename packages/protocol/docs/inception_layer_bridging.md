# Multi-Hop Briding

We expect that bridging acorss multiple layers are supported natively by Taiko. I'd like to explain how this is done.

First of all, we need to ensures some contracts are shared by multiple Taiko deployments. For example, if we deploy two layer 2s, L2A and L2B, if we would like users to deposit Ether to L2A, then bridge Ether from L2A directly to L2B, then withdraw the Ether on L1, then the contract that holds Ether must be shared by L2A and L2B.

## Shared contracts

On L2 or any laer, then following contracts shall be deployed as sigletonsshared by multiple TaikoL1 deployments.

- EtherVault
- SignalService
- Bridge
- and all token vaults e.g., ERC20Vault
- An AddressManager used by the above contracts.

There are some inter-dependency among these shared contracts. Specificly

- Bridge.sol depends on SignalService;
- Token vaults depend on Bridge.sol;

These 1-to-1 dependency relations are acheived by AddressResolver with a name-based address resolution (lookup).

### EtherVault

EtherVault has a dependency on a local Bridge. Therefore, we must perform:

```solidity
EtherVault(valut).setAddress("bridge", address(localBridge));
```

### SignalService

SignalService also use AuthorizableContract to authorize multiple TaikoL1 and TaikoL2 contracts deployed **on each chain** that is part of the path of multi-hop bridging.

For each TaikoL1/TaikoL2 contractswe need to perform:

```solidity
// 1 is Ethereum's chainID
SignalService(ss).authorize(address(TaikoL1A), 1);
SignalService(ss).authorize(address(TaikoL1B), 1);

// 10001 is the L2A's chainId
SignalService(ss).authorize(address(TaikoL2A, 10001);

// 10002 is the L2B's chainId
SignalService(ss).authorize(address(TaikoL2B, 10002);
...
```

The label **must be** the id of the chain where the smart contract has been deployed to.

### Bridge

Bridge depends on a local SignalService and a local EtherVault.Threfore, we need to registered the service as:

```solidity
Bridge(bridge).setAddress(
	block.chainId,
	"bridge",
	localSignalService);

Bridge(bridge).setAddress(
	block.chainId,
	"ether_vault",
	localSignalService);
```

Bridge also need to know eacn and every conterparty bridge deployed on all chains\*\* that are part of the path of multi-hop bridging.

```solidity
Bridge(bridge).setAddress(remoteChainId1, remoteSignalService1);
Bridge(bridge).setAddress(remoteChainId2, remoteSignalService2);
...
```

### ERC20Vault

ERC20Vault (and other token vaults) depends on a local Bridge, you must have:

```solidity
ERC20Vault(vault).setAddress(block.chainId, localBridge)
```

Similiar with Bridge, ERC20Vault also needs to know their conterpart vaults **on each chain** that is part of the path of multi-hop bridging. Therefore, we must perform:

```solidity
ERC20Vault(vault).setAddress(remoteChainId1, remoteERC20Vault1);
ERC20Vault(vault).setAddress(remoteChainId2, remoteERC20Vault2);
...

### Dedicated AddressManager
A dedicated AddressManager should be deployed on each chain to support only these shared contracts. This AddressManager shall not be used by the TaikoL1 deployments.

## Per Rollup Contracts

```
