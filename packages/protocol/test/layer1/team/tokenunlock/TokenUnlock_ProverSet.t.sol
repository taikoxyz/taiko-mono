// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
// import "src/layer1/team/TokenUnlock.sol";
// import "../../based/InboxTestBase.sol";

// contract TokenUnlock_ProverSet is InboxTestBase {
//     uint64 private constant TGE = 1_000_000;
//     uint96 private constant livenessBond = 125 ether;

//     address private taikoL1 = randAddress();

//     TokenUnlock private target;
//     TaikoToken private taikoToken;

//     function getConfig() internal pure override returns (ITaikoInbox.Config memory) {
//         return ITaikoInbox.Config({
//             chainId: LibNetwork.TAIKO_MAINNET,
//             maxUnverifiedBatches: 10,
//             batchRingBufferSize: 15,
//             maxBatchesToVerify: 5,
//             blockMaxGasLimit: 240_000_000,
//             livenessBond: livenessBond, // 125 Taiko token
//             stateRootSyncInternal: 5,
//             maxAnchorHeightOffset: 64,
//             baseFeeConfig: LibSharedData.BaseFeeConfig({
//                 adjustmentQuotient: 8,
//                 sharingPctg: 75,
//                 gasIssuancePerSecond: 5_000_000,
//                 minGasExcess: 1_340_000_000, // correspond to 0.008847185 gwei basefee
//                 maxGasIssuancePerBlock: 600_000_000 // two minutes: 5_000_000 * 120
//              }),
//             provingWindow: 1 hours,
//             cooldownWindow: 0 hours,
//             maxSignalsToReceive: 16,
//             forkHeights: ITaikoInbox.ForkHeights({ ontake: 0, pacaya: 0 })
//         });
//     }

//     function setUpOnEthereum() internal override {
//         super.setUpOnEthereum();
//         taikoToken = deployBondToken();

//         register("taiko_token", address(taikoToken));
//         register("prover_set", address(new ProverSet()));

//         target = TokenUnlock(
//             deploy({
//                 name: "token_unlock",
//                 impl: address(new TokenUnlock()),
//                 data: abi.encodeCall(TokenUnlock.init, (Alice, address(resolver), Bob, TGE))
//             })
//         );
//     }

//     function setUp() public override {
//         super.setUp();

//         vm.warp(TGE);

//         vm.prank(Alice);
//         taikoToken.approve(address(target), 1_000_000_000 ether);
//     }

//     function test_tokenunlock_proverset() public {
//         taikoToken.transfer(Alice, 1000 ether);

//         vm.startPrank(Alice);
//         target.vest(100 ether);
//         taikoToken.transfer(address(target), 20 ether);
//         vm.warp(TGE + target.ONE_YEAR() * 2);

//         vm.expectRevert(TokenUnlock.PERMISSION_DENIED.selector);
//         target.createProverSet();
//         vm.stopPrank();

//         vm.startPrank(Bob);
//         vm.expectRevert(TokenUnlock.NOT_PROVER_SET.selector);
//         target.depositToProverSet(vm.addr(0x1234), 1 ether);

//         ProverSet set1 = ProverSet(payable(target.createProverSet()));
//         assertEq(set1.owner(), target.owner());
//         assertEq(set1.admin(), address(target));

//         assertTrue(target.isProverSet(address(set1)));

//         vm.expectRevert(); // ERC20: transfer amount exceeds balance
//         target.depositToProverSet(address(set1), 121 ether);

//         target.depositToProverSet(address(set1), 120 ether);
//         assertEq(taikoToken.balanceOf(address(set1)), 120 ether);
//         assertEq(taikoToken.balanceOf(address(target)), 0 ether);
//         assertEq(target.amountVested(), 100 ether);
//         assertEq(target.amountWithdrawable(), 0 ether);

//         vm.expectRevert(); //  ERC20: transfer amount exceeds balance
//         set1.withdrawToAdmin(121 ether);

//         set1.withdrawToAdmin(120 ether);
//         assertEq(taikoToken.balanceOf(address(set1)), 0 ether);
//         assertEq(taikoToken.balanceOf(address(target)), 120 ether);
//         assertEq(target.amountVested(), 100 ether);
//         assertEq(target.amountWithdrawable(), 70 ether);

//         set1.enableProver(Carol, true);
//         assertTrue(set1.isProver(Carol));

//         vm.expectRevert(ProverSet.INVALID_STATUS.selector);
//         set1.enableProver(Carol, true);

//         set1.delegate(Carol);
//         assertEq(taikoToken.delegates(address(set1)), Carol);

//         // create another one
//         target.createProverSet();

//         vm.stopPrank();

//         vm.prank(target.owner());
//         vm.expectRevert(TokenUnlock.PERMISSION_DENIED.selector);
//         set1.enableProver(David, true);

//         vm.prank(David);
//         vm.expectRevert(TokenUnlock.PERMISSION_DENIED.selector);
//         set1.enableProver(Carol, true);
//     }

//     function test_tokenunlock_proverset_propose_and_prove_blocks() public {
//         uint256 initialBondBalance = 200 ether;

//         taikoToken.transfer(Alice, 1000 ether);

//         vm.startPrank(Alice);
//         target.vest(100 ether);
//         taikoToken.transfer(address(target), 100 ether);
//         vm.warp(TGE + target.ONE_YEAR() * 2);

//         vm.startPrank(Bob);
//         ProverSet set = ProverSet(payable(target.createProverSet()));
//         target.depositToProverSet(address(set), initialBondBalance);

//         vm.expectRevert(); // ERC20: transfer amount exceeds balance
//         set.depositBond(201 ether);

//         set.depositBond(200 ether);

//         set.enableProver(Carol, true);
//         assertTrue(set.isProver(Carol));
//         vm.stopPrank();

//         // Only prover in ProverSet can propose taiko blocks
//         vm.prank(Alice);
//         vm.expectRevert(TokenUnlock.PERMISSION_DENIED.selector);
//         ITaikoInbox.BlockParamsV3[] memory paramsArray = new ITaikoInbox.BlockParamsV3[](1);
//         set.proposeBatches(paramsArray, "txList", false);

//         vm.prank(Carol);
//         ITaikoInbox.BlockMetadataV3[] memory metas =
//             set.proposeBatches(paramsArray, "txList", false);

//         vm.startPrank(Bob);
//         vm.expectRevert();
//         set.withdrawBond(initialBondBalance);
//         set.withdrawBond(initialBondBalance - livenessBond);
//         vm.stopPrank();

//         // Only prover in ProverSet  can prove taiko blocks
//         ITaikoInbox.TransitionV3[] memory transitions = new ITaikoInbox.TransitionV3[](1);
//         for (uint256 i; i < metas.length; ++i) {
//             transitions[i].parentHash = correctBlockhash(metas[i].blockId - 1);
//             transitions[i].blockHash = correctBlockhash(metas[i].blockId);
//             transitions[i].stateRoot = correctStateRoot(metas[i].blockId);
//         }

//         vm.prank(Alice);
//         vm.expectRevert(TokenUnlock.PERMISSION_DENIED.selector);
//         set.proveBatches(metas, transitions, "proof");

//         vm.prank(Carol);
//         set.proveBatches(metas, transitions, "proof");

//         vm.startPrank(Bob);
//         set.withdrawBond(livenessBond);
//     }
// }
