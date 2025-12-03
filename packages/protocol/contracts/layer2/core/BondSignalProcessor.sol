// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IBondManager } from "./IBondManager.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { ISignalService } from "src/shared/signal/ISignalService.sol";

/// @title BondSignalProcessor
/// @notice Processes L1 bond signals on L2 with best-effort debits/credits.
/// @custom:security-contact security@taiko.xyz
contract BondSignalProcessor is EssentialContract {
    // ---------------------------------------------------------------
    // Immutables
    // ---------------------------------------------------------------

    IBondManager public immutable bondManager;
    ISignalService public immutable signalService;
    address public immutable l1Inbox;
    uint256 public immutable livenessBond;
    uint256 public immutable provabilityBond;
    uint64 public immutable l1ChainId;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    mapping(bytes32 signalId => bool processed) public processedSignals;

    uint256[49] private __gap;

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    event BondSignalProcessed(
        bytes32 indexed signal, LibBonds.BondInstruction instruction, uint256 debitedAmount
    );

    // ---------------------------------------------------------------
    // Constructor & Initializer
    // ---------------------------------------------------------------

    constructor(
        ISignalService _signalService,
        IBondManager _bondManager,
        address _l1Inbox,
        uint64 _l1ChainId,
        uint256 _livenessBond,
        uint256 _provabilityBond
    ) {
        if (address(_signalService) == address(0) || address(_bondManager) == address(0)) {
            revert InvalidAddress();
        }
        if (_l1Inbox == address(0)) revert InvalidAddress();
        if (_l1ChainId == 0 || _l1ChainId == block.chainid) revert InvalidL1ChainId();

        signalService = _signalService;
        bondManager = _bondManager;
        l1Inbox = _l1Inbox;
        l1ChainId = _l1ChainId;
        livenessBond = _livenessBond;
        provabilityBond = _provabilityBond;
    }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @notice Processes a proved bond signal from L1.
    /// @param _instruction Bond instruction tied to the signal.
    /// @param _proof Merkle proof that the signal was sent on L1.
    // TODO: allow processing multiple bond signals in a single call?
    function processBondSignal(LibBonds.BondInstruction calldata _instruction, bytes calldata _proof)
        external
        nonReentrant
    {
        if (_instruction.bondType == LibBonds.BondType.NONE) revert NoBondInstruction();
        if (uint8(_instruction.bondType) > uint8(LibBonds.BondType.LIVENESS)) {
            revert InvalidBondType();
        }

        bytes32 signal = _bondSignalHash(_instruction);
        bytes32 signalId = _signalId(signal);
        if (processedSignals[signalId]) revert SignalAlreadyProcessed();

        signalService.proveSignalReceived(l1ChainId, l1Inbox, signal, _proof);
        processedSignals[signalId] = true;

        uint256 debited;
        uint256 amount = _bondAmountFor(_instruction.bondType);
        if (amount != 0 && _instruction.payer != _instruction.payee) {
            debited = bondManager.debitBond(_instruction.payer, amount);
            bondManager.creditBond(_instruction.payee, debited);
        }

        emit BondSignalProcessed(signal, _instruction, debited);
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    function _bondSignalHash(LibBonds.BondInstruction memory _instruction)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_instruction));
    }

    function _signalId(bytes32 _signal) private view returns (bytes32) {
        return keccak256(abi.encode(l1ChainId, l1Inbox, _signal));
    }

    function _bondAmountFor(LibBonds.BondType _bondType) private view returns (uint256) {
        if (_bondType == LibBonds.BondType.LIVENESS) {
            return livenessBond;
        }
        if (_bondType == LibBonds.BondType.PROVABILITY) {
            return provabilityBond;
        }
        return 0;
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error InvalidAddress();
    error InvalidL1ChainId();
    error InvalidBondType();
    error NoBondInstruction();
    error SignalAlreadyProcessed();
}
