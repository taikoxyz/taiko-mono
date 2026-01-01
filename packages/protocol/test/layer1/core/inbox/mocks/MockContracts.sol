// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
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

contract MockProverAuction {
    address public currentProver;
    uint32 public currentFeeInGwei;
    bool public bondOk = true;
    address public lastSlashedProver;
    address public lastSlashRecipient;

    function setCurrentProver(address _prover) external {
        currentProver = _prover;
    }

    function setCurrentFeeInGwei(uint32 _fee) external {
        currentFeeInGwei = _fee;
    }

    function setBondOk(bool _ok) external {
        bondOk = _ok;
    }

    function checkBondDeferWithdrawal(address) external view returns (bool success_) {
        return bondOk;
    }

    function getProver() external view returns (address prover_, uint32 feeInGwei_) {
        return (currentProver, currentFeeInGwei);
    }

    function slashProver(address _prover, address _recipient) external {
        lastSlashedProver = _prover;
        lastSlashRecipient = _recipient;
    }

    receive() external payable { }
}
