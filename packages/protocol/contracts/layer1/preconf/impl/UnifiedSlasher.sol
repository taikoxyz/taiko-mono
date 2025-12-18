// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ISlasher } from "@eth-fabric/urc/ISlasher.sol";
import { ILookaheadSlasher } from "src/layer1/preconf/iface/ILookaheadSlasher.sol";
import { IPreconfSlasherL1 } from "src/layer1/preconf/iface/IPreconfSlasherL1.sol";

import { LibPreconfConstants } from "src/layer1/preconf/libs/LibPreconfConstants.sol";
import { IMessageInvocable } from "src/shared/bridge/IBridge.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";

/// @title UnifiedSlasher
/// @dev A common entry point for `PreconfSlasherL1` and `LookaheadSlasher`.
/// @dev The operators are only required to opt-in to the unified slasher in order
/// to preconf and post lookaheads.
/// @custom:security-contact security@taiko.xyz
contract UnifiedSlasher is EssentialContract, ISlasher, IMessageInvocable {
    address public immutable urc;
    address public immutable preconfSlasherL1;
    address public immutable lookaheadSlasher;

    constructor(
        address _preconfSlasherL1,
        address _lookaheadSlasher,
        address _urc
    )
        EssentialContract()
    {
        preconfSlasherL1 = _preconfSlasherL1;
        lookaheadSlasher = _lookaheadSlasher;
        urc = _urc;
    }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @inheritdoc ISlasher
    function slash(
        Delegation calldata, /* delegation */
        Commitment calldata _commitment,
        address, /* committer */
        bytes calldata _evidence,
        address _challenger
    )
        external
        override
        returns (uint256 slashAmount_)
    {
        require(msg.sender == urc, CallerIsNotURC());

        // Route to the correct slasher contract based on the commitment type
        if (_commitment.commitmentType == LibPreconfConstants.PRECONF_COMMITMENT_TYPE) {
            // Preconfirmation slashing
            (bool success, bytes memory data) = preconfSlasherL1.delegatecall(
                abi.encodeWithSelector(
                    IPreconfSlasherL1.slash.selector, _commitment, _evidence, _challenger
                )
            );
            if (!success) {
                assembly {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            }
            slashAmount_ = abi.decode(data, (uint256));
        } else if (_commitment.commitmentType == LibPreconfConstants.LOOKAHEAD_COMMITMENT_TYPE) {
            // Lookahead slashing
            (bool success, bytes memory data) = lookaheadSlasher.delegatecall(
                abi.encodeWithSelector(ILookaheadSlasher.slash.selector, _commitment, _evidence)
            );
            if (!success) {
                assembly {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            }
            slashAmount_ = abi.decode(data, (uint256));
        } else {
            revert UnsupportedCommitmentType();
        }
    }

    /// @inheritdoc IMessageInvocable
    function onMessageInvocation(bytes calldata _data) external payable override {
        // We only delegatecall to preconfSlasherL1, as only preconfirmation faults use message
        // invocation via bridge
        (bool success,) = preconfSlasherL1.delegatecall(
            abi.encodeWithSelector(IMessageInvocable.onMessageInvocation.selector, _data)
        );
        if (!success) {
            assembly {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error CallerIsNotURC();
    error UnsupportedCommitmentType();
}
