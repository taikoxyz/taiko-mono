// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaStakingRegistryTestBase } from "./EtnaStakingRegistryTestBase.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { LibCometVote } from "src/layer1/etna/libs/LibCometVote.sol";
import { LibEtnaKeys } from "src/layer1/etna/libs/LibEtnaKeys.sol";

contract CometVoteZeroHashTest is EtnaStakingRegistryTestBase {
    bytes32 private constant _BLOCK_HASH =
        0x1111111111111111111111111111111111111111111111111111111111111111;
    bytes32 private constant _PARTS_HASH =
        0x2222222222222222222222222222222222222222222222222222222222222222;

    function setUp() public override {
        super.setUp();
        mockInbox.setInitialized(true);
        vm.roll(30);
        assertEq(_register(Alice, 1), 0);
    }

    /// @dev Stock CometBFT writes the 32-byte zero hash as a present protobuf bytes field.
    function test_signBytes_PreservesPresentZeroPartsHash() external view {
        IEtnaStakingRegistry.Vote memory vote = _vote(bytes32(0));
        bytes memory chainId = _chainId();
        assertEq(LibCometVote.signBytes(vote, chainId), _stockSignBytes(bytes32(0), chainId));
    }

    /// @dev Valid stock signatures over conflicting full block ids must slash the bond even
    /// when one part set hash contains 32 zero bytes.
    function test_slashDoubleSign_AcceptsStockSignedZeroPartsHash() external {
        bytes memory chainId = _chainId();
        IEtnaStakingRegistry.Vote memory a = _signedVote(_PARTS_HASH, chainId);
        IEtnaStakingRegistry.Vote memory b = _signedVote(bytes32(0), chainId);
        assertEq(LibCometVote.signBytes(a, chainId), _stockSignBytes(_PARTS_HASH, chainId));

        vm.prank(Bob);
        registry.slashDoubleSign(0, a, b);

        assertEq(registry.bondAt(0).entry.effStake, 0);
        assertEq(token.balanceOf(Bob), 100 ether);
        assertEq(token.balanceOf(SLASH_SINK), 900 ether);
    }

    /// @dev The vote fields checked by CometBFT v0.40.0's Vote.ValidateBasic and
    /// evidence.VerifyDuplicateVote in the independent stock encoder fixture.
    /// @param _partsHash The present, 32-byte part set hash.
    /// @return vote_ The unsigned vote.
    function _vote(bytes32 _partsHash)
        private
        pure
        returns (IEtnaStakingRegistry.Vote memory vote_)
    {
        vote_.voteType = 2;
        vote_.height = 6;
        vote_.blockHash = abi.encodePacked(_BLOCK_HASH);
        vote_.partsTotal = 1;
        vote_.partsHash = abi.encodePacked(_partsHash);
        vote_.timestampSeconds = 1_700_000_000;
    }

    /// @dev Signs the independently encoded stock bytes and checks that the signature recovers
    /// the registered key before handing it to the registry.
    /// @param _partsHash The present, 32-byte part set hash.
    /// @param _chainId The deployment's chain id.
    /// @return vote_ The signed vote.
    function _signedVote(
        bytes32 _partsHash,
        bytes memory _chainId
    )
        private
        view
        returns (IEtnaStakingRegistry.Vote memory vote_)
    {
        vote_ = _vote(_partsHash);
        bytes32 digest = keccak256(_stockSignBytes(_partsHash, _chainId));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, digest);
        vote_.signature = abi.encodePacked(r, s, v - 27);
        assertEq(LibEtnaKeys.recoverSigner(digest, vote_.signature), vm.addr(1));
    }

    /// @dev The literal stock VoteSignBytes prefix/suffix for height 6, round 0, total 1 and
    /// timestamp 1700000000; the deployment's 48-byte chain id is the only variable-length input.
    /// @param _partsHash The present, 32-byte part set hash.
    /// @param _chainId The deployment's chain id.
    /// @return The independently encoded sign bytes.
    function _stockSignBytes(
        bytes32 _partsHash,
        bytes memory _chainId
    )
        private
        pure
        returns (bytes memory)
    {
        assert(_chainId.length == 48);
        return bytes.concat(
            hex"8f01080211060000000000000022480a20",
            _BLOCK_HASH,
            hex"122408011220",
            _partsHash,
            hex"2a060880e2cfaa063230",
            _chainId
        );
    }

    /// @dev The runtime deployment's generation-zero stock CometBFT chain id.
    /// @return The chain id.
    function _chainId() private view returns (bytes memory) {
        return LibCometVote.chainId(
            LibCometVote.chainDomain(block.chainid, L2_CHAIN_ID, address(mockInbox), 0)
        );
    }
}
