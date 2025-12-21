// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";
import { IProverAuction } from "src/layer1/core/iface/IProverAuction.sol";
import { ISignalService } from "src/shared/signal/ISignalService.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {
        _mint(msg.sender, 1_000_000 ether);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockProofVerifier is IProofVerifier {
    function verifyProof(uint256, bytes32, bytes calldata) external pure { }
}

contract MockProverAuction is IProverAuction {
    address public currentProver;
    uint256 public currentFee;
    uint256 public penalizeProverCallCount;
    address public lastDesignatedProver;
    address public lastActualProver;

    constructor(address _prover) {
        currentProver = _prover;
        currentFee = 0; // No fee by default for tests
    }

    function getCurrentProverAndFee() external view returns (address, uint256) {
        return (currentProver, currentFee);
    }

    function penalizeProver(address _designatedProver, address _actualProver) external {
        penalizeProverCallCount++;
        lastDesignatedProver = _designatedProver;
        lastActualProver = _actualProver;
    }

    function setCurrentFee(uint256 _fee) external {
        currentFee = _fee;
    }

    function resetCallCounts() external {
        penalizeProverCallCount = 0;
        lastDesignatedProver = address(0);
        lastActualProver = address(0);
    }
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
