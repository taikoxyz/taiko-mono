// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { IProverMarket } from "src/layer1/core/iface/IProverMarket.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";
import { ISignalService } from "src/shared/signal/ISignalService.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {
        _mint(msg.sender, 1_000_000 ether);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockProverMarket is IProverMarket {
    address private _bondToken;
    uint48 private _provingWindow;

    constructor(address bondToken_, uint48 provingWindow_) {
        _bondToken = bondToken_;
        _provingWindow = provingWindow_;
    }

    function bid(uint64) external { }
    function exit() external { }
    function depositBond(uint64) external { }
    function withdrawBond(uint64) external { }
    function withdrawFees(uint256) external { }

    function bondBalances(address) external pure returns (uint64) {
        return 0;
    }

    function feeBalances(address) external pure returns (uint256) {
        return 0;
    }

    function canSubmitProof(address, uint48, uint256) external pure returns (bool) {
        return true;
    }

    function onProposalAccepted(uint48, address _proposer, uint48) external payable {
        if (msg.value > 0) payable(_proposer).transfer(msg.value);
    }

    function onProofAccepted(address, uint48, uint48, uint256) external { }
    function forcePermissionlessMode(bool) external { }
    function creditMigratedBond(address, uint64) external { }

    function bondToken() external view returns (address) {
        return _bondToken;
    }

    function provingWindow() external view returns (uint48) {
        return _provingWindow;
    }

    function activeFeeInGwei() external pure returns (uint64) {
        return 0;
    }

    function minBond() external pure returns (uint64) {
        return 0;
    }

    function bidDiscountBps() external pure returns (uint16) {
        return 500;
    }

    function reservedBondGwei(address) external pure returns (uint64) {
        return 0;
    }

    function bondPerProposal() external pure returns (uint64) {
        return 0;
    }

    function slashPerProof() external pure returns (uint64) {
        return 0;
    }
}

contract MockProofVerifier is IProofVerifier {
    function verifyProof(uint256, bytes32, bytes calldata) external pure { }
}

contract MockSignalService is ISignalService {
    mapping(uint48 => Checkpoint) public checkpoints;
    mapping(bytes32 => bool) public sentSignals;
    mapping(bytes32 => bool) public receivedSignals;

    function sendSignal(bytes32 _signal) external returns (bytes32 slot_) {
        slot_ = getSignalSlot(uint64(block.chainid), msg.sender, _signal);
        sentSignals[slot_] = true;
        emit SignalSent(msg.sender, _signal, slot_, _signal);
    }

    function sendSignalFrom(
        uint64 _chainId,
        address _app,
        bytes32 _signal
    )
        external
        returns (bytes32 slot_)
    {
        slot_ = getSignalSlot(_chainId, _app, _signal);
        sentSignals[slot_] = true;
        emit SignalSent(_app, _signal, slot_, _signal);
    }

    function proveSignalReceived(
        uint64 _chainId,
        address _app,
        bytes32 _signal,
        bytes calldata
    )
        external
        returns (uint256)
    {
        bytes32 slot = getSignalSlot(_chainId, _app, _signal);
        require(sentSignals[slot], "signal not sent");
        receivedSignals[slot] = true;
        return 0;
    }

    function verifySignalReceived(
        uint64 _chainId,
        address _app,
        bytes32 _signal,
        bytes calldata
    )
        external
        view
    {
        bytes32 slot = getSignalSlot(_chainId, _app, _signal);
        require(sentSignals[slot], "signal not sent");
        require(receivedSignals[slot], "signal not proved");
    }

    function isSignalSent(address _app, bytes32 _signal) external view returns (bool) {
        return sentSignals[getSignalSlot(uint64(block.chainid), _app, _signal)];
    }

    function isSignalSent(bytes32 _signalSlot) external view returns (bool) {
        return sentSignals[_signalSlot];
    }

    function getSignalSlot(
        uint64 _chainId,
        address _app,
        bytes32 _signal
    )
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked("SIGNAL", _chainId, _app, _signal));
    }

    function saveCheckpoint(Checkpoint calldata _checkpoint) external {
        checkpoints[_checkpoint.blockNumber] = _checkpoint;
        emit CheckpointSaved(_checkpoint.blockNumber, _checkpoint.blockHash, _checkpoint.stateRoot);
    }

    function getCheckpoint(uint48 _blockNumber) external view returns (Checkpoint memory) {
        return checkpoints[_blockNumber];
    }
}
