// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IProverAuction } from "src/layer1/core/iface/IProverAuction.sol";
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

contract MockProverAuction is IProverAuction {
    address public prover;
    uint32 public feeInGwei;
    uint128 public requiredBond;
    uint96 public livenessBond;
    uint128 public ejectionThreshold;
    uint128 public totalSlashedAmount;

    mapping(address => bool) public slashedProvers;
    mapping(address => bool) public hasSufficientBond;
    address public lastSlashedProver;
    address public lastSlashRecipient;
    bool public defaultBondCheck;

    constructor(address _prover, uint32 _feeInGwei) {
        prover = _prover;
        feeInGwei = _feeInGwei;
        requiredBond = 10 ether;
        livenessBond = 1 ether;
        ejectionThreshold = 5 ether;
        defaultBondCheck = true;
    }

    function setProver(address _prover, uint32 _feeInGwei) external {
        prover = _prover;
        feeInGwei = _feeInGwei;
    }

    function setDefaultBondCheck(bool _value) external {
        defaultBondCheck = _value;
    }

    function setHasSufficientBond(address _prover, bool _value) external {
        hasSufficientBond[_prover] = _value;
    }

    function bid(uint32) external pure { }

    function deposit(uint128) external pure { }

    function withdraw(uint128) external pure { }

    function requestExit() external pure { }

    function slashProver(address _proverAddr, address _recipient) external {
        slashedProvers[_proverAddr] = true;
        lastSlashedProver = _proverAddr;
        lastSlashRecipient = _recipient;
        totalSlashedAmount += uint128(livenessBond);
        emit ProverSlashed(_proverAddr, livenessBond, _recipient, uint128(livenessBond) / 2);
    }

    function checkBondDeferWithdrawal(address _prover) external view returns (bool success_) {
        if (hasSufficientBond[_prover]) return true;
        return defaultBondCheck;
    }

    function getProver() external view returns (address prover_, uint32 feeInGwei_) {
        return (prover, feeInGwei);
    }

    function getRequiredBond() external view returns (uint128 requiredBond_) {
        return requiredBond;
    }

    function getLivenessBond() external view returns (uint96 livenessBond_) {
        return livenessBond;
    }

    function getEjectionThreshold() external view returns (uint128 threshold_) {
        return ejectionThreshold;
    }

    function getTotalSlashedAmount() external view returns (uint128 totalSlashedAmount_) {
        return totalSlashedAmount;
    }
}
