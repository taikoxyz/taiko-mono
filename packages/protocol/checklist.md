**THIS CHECKLIST IS NOT COMPLETE**. Use `--show-ignored-findings` to show all the results.
Summary
 - [arbitrary-send-erc20](#arbitrary-send-erc20) (6 results) (High)
 - [encode-packed-collision](#encode-packed-collision) (1 results) (High)
 - [unchecked-transfer](#unchecked-transfer) (12 results) (High)
 - [divide-before-multiply](#divide-before-multiply) (1 results) (Medium)
 - [reentrancy-no-eth](#reentrancy-no-eth) (3 results) (Medium)
 - [uninitialized-local](#uninitialized-local) (9 results) (Medium)
 - [unused-return](#unused-return) (8 results) (Medium)
## arbitrary-send-erc20
Impact: High
Confidence: High
 - [ ] ID-0
[AssignmentHook.onBlockProposed(TaikoData.Block,TaikoData.BlockMetadata,bytes)](contracts/L1/hooks/AssignmentHook.sol#L62-L130) uses arbitrary from in transferFrom: [tko.transferFrom(_blk.assignedProver,taikoL1Address,_blk.livenessBond)](contracts/L1/hooks/AssignmentHook.sol#L102)

contracts/L1/hooks/AssignmentHook.sol#L62-L130


 - [ ] ID-1
[USDCAdapter._burnToken(address,uint256)](contracts/tokenvault/adapters/USDCAdapter.sol#L47-L50) uses arbitrary from in transferFrom: [usdc.transferFrom(_from,address(this),_amount)](contracts/tokenvault/adapters/USDCAdapter.sol#L48)

contracts/tokenvault/adapters/USDCAdapter.sol#L47-L50


 - [ ] ID-2
[ERC20Airdrop2.withdraw(address)](contracts/team/airdrop/ERC20Airdrop2.sol#L88-L94) uses arbitrary from in transferFrom: [IERC20(token).transferFrom(vault,user,amount)](contracts/team/airdrop/ERC20Airdrop2.sol#L91)

contracts/team/airdrop/ERC20Airdrop2.sol#L88-L94


 - [ ] ID-3
[AssignmentHook.onBlockProposed(TaikoData.Block,TaikoData.BlockMetadata,bytes)](contracts/L1/hooks/AssignmentHook.sol#L62-L130) uses arbitrary from in transferFrom: [IERC20(assignment.feeToken).safeTransferFrom(_meta.coinbase,_blk.assignedProver,proverFee)](contracts/L1/hooks/AssignmentHook.sol#L114-L116)

contracts/L1/hooks/AssignmentHook.sol#L62-L130


 - [ ] ID-4
[TimelockTokenPool._withdraw(address,address)](contracts/team/TimelockTokenPool.sol#L208-L223) uses arbitrary from in transferFrom: [IERC20(taikoToken).transferFrom(sharedVault,_to,amountToWithdraw)](contracts/team/TimelockTokenPool.sol#L219)

contracts/team/TimelockTokenPool.sol#L208-L223


 - [ ] ID-5
[ERC20Airdrop.claimAndDelegate(address,uint256,bytes32[],bytes)](contracts/team/airdrop/ERC20Airdrop.sol#L50-L72) uses arbitrary from in transferFrom: [IERC20(token).transferFrom(vault,user,amount)](contracts/team/airdrop/ERC20Airdrop.sol#L63)

contracts/team/airdrop/ERC20Airdrop.sol#L50-L72


## encode-packed-collision
Impact: High
Confidence: High
 - [ ] ID-6
[BridgedERC721.tokenURI(uint256)](contracts/tokenvault/BridgedERC721.sol#L107-L113) calls abi.encodePacked() with multiple dynamic arguments:
	- [string(abi.encodePacked(LibBridgedToken.buildURI(srcToken,srcChainId),Strings.toString(_tokenId)))](contracts/tokenvault/BridgedERC721.sol#L108-L112)

contracts/tokenvault/BridgedERC721.sol#L107-L113


## unchecked-transfer
Impact: High
Confidence: Medium
 - [ ] ID-7
[LibVerifying.verifyBlocks(TaikoData.State,TaikoData.Config,IAddressResolver,uint64)](contracts/L1/libs/LibVerifying.sol#L85-L222) ignores return value by [tko.transfer(ts.prover,bondToReturn)](contracts/L1/libs/LibVerifying.sol#L189)

contracts/L1/libs/LibVerifying.sol#L85-L222


 - [ ] ID-8
[LibProving._overrideWithHigherProof(TaikoData.TransitionState,TaikoData.Transition,TaikoData.TierProof,ITierProvider.Tier,IERC20,bool)](contracts/L1/libs/LibProving.sol#L350-L398) ignores return value by [_tko.transfer(_ts.prover,_ts.validityBond + reward)](contracts/L1/libs/LibProving.sol#L367)

contracts/L1/libs/LibProving.sol#L350-L398


 - [ ] ID-9
[LibProving._overrideWithHigherProof(TaikoData.TransitionState,TaikoData.Transition,TaikoData.TierProof,ITierProvider.Tier,IERC20,bool)](contracts/L1/libs/LibProving.sol#L350-L398) ignores return value by [_tko.transferFrom(msg.sender,address(this),_tier.validityBond - reward)](contracts/L1/libs/LibProving.sol#L384)

contracts/L1/libs/LibProving.sol#L350-L398


 - [ ] ID-10
[LibProving._overrideWithHigherProof(TaikoData.TransitionState,TaikoData.Transition,TaikoData.TierProof,ITierProvider.Tier,IERC20,bool)](contracts/L1/libs/LibProving.sol#L350-L398) ignores return value by [_tko.transfer(msg.sender,reward - _tier.validityBond)](contracts/L1/libs/LibProving.sol#L382)

contracts/L1/libs/LibProving.sol#L350-L398


 - [ ] ID-11
[LibProving.proveBlock(TaikoData.State,TaikoData.Config,IAddressResolver,TaikoData.BlockMetadata,TaikoData.Transition,TaikoData.TierProof)](contracts/L1/libs/LibProving.sol#L91-L266) ignores return value by [tko.transferFrom(msg.sender,address(this),tier.contestBond)](contracts/L1/libs/LibProving.sol#L242)

contracts/L1/libs/LibProving.sol#L91-L266


 - [ ] ID-12
[TimelockTokenPool._withdraw(address,address)](contracts/team/TimelockTokenPool.sol#L208-L223) ignores return value by [IERC20(taikoToken).transferFrom(sharedVault,_to,amountToWithdraw)](contracts/team/TimelockTokenPool.sol#L219)

contracts/team/TimelockTokenPool.sol#L208-L223


 - [ ] ID-13
[LibProving.proveBlock(TaikoData.State,TaikoData.Config,IAddressResolver,TaikoData.BlockMetadata,TaikoData.Transition,TaikoData.TierProof)](contracts/L1/libs/LibProving.sol#L91-L266) ignores return value by [tko.transfer(blk.assignedProver,blk.livenessBond)](contracts/L1/libs/LibProving.sol#L196)

contracts/L1/libs/LibProving.sol#L91-L266


 - [ ] ID-14
[ERC20Airdrop.claimAndDelegate(address,uint256,bytes32[],bytes)](contracts/team/airdrop/ERC20Airdrop.sol#L50-L72) ignores return value by [IERC20(token).transferFrom(vault,user,amount)](contracts/team/airdrop/ERC20Airdrop.sol#L63)

contracts/team/airdrop/ERC20Airdrop.sol#L50-L72


 - [ ] ID-15
[USDCAdapter._burnToken(address,uint256)](contracts/tokenvault/adapters/USDCAdapter.sol#L47-L50) ignores return value by [usdc.transferFrom(_from,address(this),_amount)](contracts/tokenvault/adapters/USDCAdapter.sol#L48)

contracts/tokenvault/adapters/USDCAdapter.sol#L47-L50


 - [ ] ID-16
[ERC20Airdrop2.withdraw(address)](contracts/team/airdrop/ERC20Airdrop2.sol#L88-L94) ignores return value by [IERC20(token).transferFrom(vault,user,amount)](contracts/team/airdrop/ERC20Airdrop2.sol#L91)

contracts/team/airdrop/ERC20Airdrop2.sol#L88-L94


 - [ ] ID-17
[LibProving._overrideWithHigherProof(TaikoData.TransitionState,TaikoData.Transition,TaikoData.TierProof,ITierProvider.Tier,IERC20,bool)](contracts/L1/libs/LibProving.sol#L350-L398) ignores return value by [_tko.transfer(_ts.contester,_ts.contestBond + reward)](contracts/L1/libs/LibProving.sol#L371)

contracts/L1/libs/LibProving.sol#L350-L398


 - [ ] ID-18
[AssignmentHook.onBlockProposed(TaikoData.Block,TaikoData.BlockMetadata,bytes)](contracts/L1/hooks/AssignmentHook.sol#L62-L130) ignores return value by [tko.transferFrom(_blk.assignedProver,taikoL1Address,_blk.livenessBond)](contracts/L1/hooks/AssignmentHook.sol#L102)

contracts/L1/hooks/AssignmentHook.sol#L62-L130


## divide-before-multiply
Impact: Medium
Confidence: Medium
 - [ ] ID-19
[TimelockTokenPool.getMyGrantSummary(address)](contracts/team/TimelockTokenPool.sol#L176-L199) performs a multiplication on the result of a division:
	- [_amountUnlocked = amountUnlocked / 1e18](contracts/team/TimelockTokenPool.sol#L197)
	- [costToWithdraw = _amountUnlocked * r.grant.costPerToken - r.costPaid](contracts/team/TimelockTokenPool.sol#L198)

contracts/team/TimelockTokenPool.sol#L176-L199


## reentrancy-no-eth
Impact: Medium
Confidence: Medium
 - [ ] ID-20
Reentrancy in [CrossChainOwned.onMessageInvocation(bytes)](contracts/L2/CrossChainOwned.sol#L34-L52):
	External calls:
	- [(success) = address(this).call(txdata)](contracts/L2/CrossChainOwned.sol#L48)
	State variables written after the call(s):
	- [TransactionExecuted(nextTxId ++,bytes4(txdata))](contracts/L2/CrossChainOwned.sol#L51)
	[CrossChainOwned.nextTxId](contracts/L2/CrossChainOwned.sol#L19) can be used in cross function reentrancies:
	- [CrossChainOwned.nextTxId](contracts/L2/CrossChainOwned.sol#L19)
	- [CrossChainOwned.onMessageInvocation(bytes)](contracts/L2/CrossChainOwned.sol#L34-L52)

contracts/L2/CrossChainOwned.sol#L34-L52


 - [ ] ID-21
Reentrancy in [ERC20Vault.changeBridgedToken(ERC20Vault.CanonicalERC20,address)](contracts/tokenvault/ERC20Vault.sol#L148-L200):
	External calls:
	- [IBridgedERC20(btokenOld_).changeMigrationStatus(_btokenNew,false)](contracts/tokenvault/ERC20Vault.sol#L184)
	- [IBridgedERC20(_btokenNew).changeMigrationStatus(btokenOld_,true)](contracts/tokenvault/ERC20Vault.sol#L185)
	State variables written after the call(s):
	- [bridgedToCanonical[_btokenNew] = _ctoken](contracts/tokenvault/ERC20Vault.sol#L188)
	[ERC20Vault.bridgedToCanonical](contracts/tokenvault/ERC20Vault.sol#L45) can be used in cross function reentrancies:
	- [ERC20Vault.bridgedToCanonical](contracts/tokenvault/ERC20Vault.sol#L45)
	- [canonicalToBridged[_ctoken.chainId][_ctoken.addr] = _btokenNew](contracts/tokenvault/ERC20Vault.sol#L189)
	[ERC20Vault.canonicalToBridged](contracts/tokenvault/ERC20Vault.sol#L49) can be used in cross function reentrancies:
	- [ERC20Vault.canonicalToBridged](contracts/tokenvault/ERC20Vault.sol#L49)

contracts/tokenvault/ERC20Vault.sol#L148-L200


 - [ ] ID-22
Reentrancy in [TaikoL2.anchor(bytes32,bytes32,uint64,uint32)](contracts/L2/TaikoL2.sol#L107-L158):
	External calls:
	- [ISignalService(resolve(signal_service,false)).syncChainData(ownerChainId,LibSignals.STATE_ROOT,_l1BlockId,_l1StateRoot)](contracts/L2/TaikoL2.sol#L148-L150)
	State variables written after the call(s):
	- [lastSyncedBlock = _l1BlockId](contracts/L2/TaikoL2.sol#L151)
	[TaikoL2.lastSyncedBlock](contracts/L2/TaikoL2.sol#L50) can be used in cross function reentrancies:
	- [TaikoL2._calc1559BaseFee(TaikoL2.Config,uint64,uint32)](contracts/L2/TaikoL2.sol#L252-L297)
	- [TaikoL2.lastSyncedBlock](contracts/L2/TaikoL2.sol#L50)
	- [publicInputHash = publicInputHashNew](contracts/L2/TaikoL2.sol#L155)
	[TaikoL2.publicInputHash](contracts/L2/TaikoL2.sol#L43) can be used in cross function reentrancies:
	- [TaikoL2.init(address,address,uint64,uint64)](contracts/L2/TaikoL2.sol#L71-L98)
	- [TaikoL2.publicInputHash](contracts/L2/TaikoL2.sol#L43)

contracts/L2/TaikoL2.sol#L107-L158


## uninitialized-local
Impact: Medium
Confidence: Medium
 - [ ] ID-23
[TaikoL2._calc1559BaseFee(TaikoL2.Config,uint64,uint32).numL1Blocks](contracts/L2/TaikoL2.sol#L274) is a local variable never initialized

contracts/L2/TaikoL2.sol#L274


 - [ ] ID-24
[ERC20Vault.sendToken(ERC20Vault.BridgeTransferOp).message](contracts/tokenvault/ERC20Vault.sol#L219) is a local variable never initialized

contracts/tokenvault/ERC20Vault.sol#L219


 - [ ] ID-25
[LibVerifying.verifyBlocks(TaikoData.State,TaikoData.Config,IAddressResolver,uint64).tierProvider](contracts/L1/libs/LibVerifying.sol#L118) is a local variable never initialized

contracts/L1/libs/LibVerifying.sol#L118


 - [ ] ID-26
[ERC721Vault.sendToken(BaseNFTVault.BridgeTransferOp).message](contracts/tokenvault/ERC721Vault.sol#L44) is a local variable never initialized

contracts/tokenvault/ERC721Vault.sol#L44


 - [ ] ID-27
[Bridge.processMessage(IBridge.Message,bytes).refundAmount](contracts/bridge/Bridge.sol#L266) is a local variable never initialized

contracts/bridge/Bridge.sol#L266


 - [ ] ID-28
[ERC1155Vault._handleMessage(address,BaseNFTVault.BridgeTransferOp).i_scope_0](contracts/tokenvault/ERC1155Vault.sol#L265) is a local variable never initialized

contracts/tokenvault/ERC1155Vault.sol#L265


 - [ ] ID-29
[ERC1155Vault.sendToken(BaseNFTVault.BridgeTransferOp).message](contracts/tokenvault/ERC1155Vault.sol#L58) is a local variable never initialized

contracts/tokenvault/ERC1155Vault.sol#L58


 - [ ] ID-30
[Guardians.isApproved(uint256).count](contracts/L1/provers/Guardians.sol#L129) is a local variable never initialized

contracts/L1/provers/Guardians.sol#L129


 - [ ] ID-31
[LibVerifying.verifyBlocks(TaikoData.State,TaikoData.Config,IAddressResolver,uint64).numBlocksVerified](contracts/L1/libs/LibVerifying.sol#L117) is a local variable never initialized

contracts/L1/libs/LibVerifying.sol#L117


## unused-return
Impact: Medium
Confidence: Medium
 - [ ] ID-32
[Bridge._updateMessageStatus(bytes32,IBridge.Status)](contracts/bridge/Bridge.sol#L515-L526) ignores return value by [ISignalService(resolve(signal_service,false)).sendSignal(signalForFailedMessage(_msgHash))](contracts/bridge/Bridge.sol#L522-L524)

contracts/bridge/Bridge.sol#L515-L526


 - [ ] ID-33
[Bridge.sendMessage(IBridge.Message)](contracts/bridge/Bridge.sol#L115-L152) ignores return value by [ISignalService(resolve(signal_service,false)).sendSignal(msgHash_)](contracts/bridge/Bridge.sol#L150)

contracts/bridge/Bridge.sol#L115-L152


 - [ ] ID-34
[LibVerifying._syncChainData(TaikoData.Config,IAddressResolver,uint64,bytes32)](contracts/L1/libs/LibVerifying.sol#L224-L243) ignores return value by [signalService.syncChainData(_config.chainId,LibSignals.STATE_ROOT,_lastVerifiedBlockId,_stateRoot)](contracts/L1/libs/LibVerifying.sol#L239-L241)

contracts/L1/libs/LibVerifying.sol#L224-L243


 - [ ] ID-35
[TaikoL2.anchor(bytes32,bytes32,uint64,uint32)](contracts/L2/TaikoL2.sol#L107-L158) ignores return value by [ISignalService(resolve(signal_service,false)).syncChainData(ownerChainId,LibSignals.STATE_ROOT,_l1BlockId,_l1StateRoot)](contracts/L2/TaikoL2.sol#L148-L150)

contracts/L2/TaikoL2.sol#L107-L158


 - [ ] ID-36
[LibVerifying._syncChainData(TaikoData.Config,IAddressResolver,uint64,bytes32)](contracts/L1/libs/LibVerifying.sol#L224-L243) ignores return value by [(lastSyncedBlock) = signalService.getSyncedChainData(_config.chainId,LibSignals.STATE_ROOT,0)](contracts/L1/libs/LibVerifying.sol#L234-L236)

contracts/L1/libs/LibVerifying.sol#L224-L243


 - [ ] ID-37
[SgxVerifier.registerInstance(V3Struct.ParsedV3QuoteStruct)](contracts/verifiers/SgxVerifier.sol#L118-L136) ignores return value by [(verified) = IAttestation(automataDcapAttestation).verifyParsedQuote(_attestation)](contracts/verifiers/SgxVerifier.sol#L128)

contracts/verifiers/SgxVerifier.sol#L118-L136


 - [ ] ID-38
[LibAddress.sendEther(address,uint256,uint256)](contracts/libs/LibAddress.sol#L22-L37) ignores return value by [(success) = ExcessivelySafeCall.excessivelySafeCall(_to,_gasLimit,_amount,64,)](contracts/libs/LibAddress.sol#L27-L33)

contracts/libs/LibAddress.sol#L22-L37


 - [ ] ID-39
[Bridge._invokeMessageCall(IBridge.Message,bytes32,uint256)](contracts/bridge/Bridge.sol#L477-L508) ignores return value by [(success_,None) = ExcessivelySafeCall.excessivelySafeCall(_message.to,_gasLimit,_message.value,64,_message.data)](contracts/bridge/Bridge.sol#L497-L503)

contracts/bridge/Bridge.sol#L477-L508


