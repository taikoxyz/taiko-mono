// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/preconf/impl/LookaheadSlasher.sol";
import "src/layer1/preconf/impl/PreconfSlasherL1.sol";
import "src/shared/common/EssentialResolverContract.sol";
import "src/shared/bridge/IBridge.sol";
import "src/shared/libs/LibNames.sol";
import "src/layer2/preconf/IPreconfSlasherL2.sol";
import "@eth-fabric/urc/IRegistry.sol";
import "@eth-fabric/urc/ISlasher.sol";

/// @title UnifiedSlasher
/// @notice This contract is the common entry point for slashing invalid lookahead and
/// preconfirmation faults.
/// @dev For slashing invalid lookahead, this contract is invoked by the URC.
/// @dev For slashing invalid preconfs, this contract is invoked by `PreconfSlasherL2`
/// via the bridge.
/// @custom:security-contact security@taiko.xyz
contract UnifiedSlasher is
    ISlasher,
    IMessageInvocable,
    LookaheadSlasher,
    PreconfSlasherL1,
    EssentialResolverContract
{
    /// @dev Used as the first byte of the evidence to identify the internal slashing function
    /// to use
    enum Slasher {
        Lookahead,
        Preconf
    }

    error CallerIsNotPreconfSlasherL2();
    error ChallengerIsNotSelf();

    struct SlashingAmounts {
        uint256 invalidLookahead;
        uint256 preconfLivenessFault;
        uint256 preconfSafetyFault;
    }

    address public immutable urc;

    constructor(
        address _resolver,
        address _urc,
        address _lookaheadStore
    )
        EssentialResolverContract(_resolver)
        LookaheadSlasher(_lookaheadStore)
    {
        urc = _urc;
    }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    // Slashing logic
    // --------------------------------------------------------------------------

    function slash(
        Delegation calldata, // delegation
        Commitment calldata _commitment,
        address, // committer
        bytes calldata _evidence,
        address _challenger
    )
        external
        view
        onlyFrom(urc)
        returns (uint256 slashAmount_)
    {
        Slasher slasher = Slasher(uint8(_evidence[0]));
        if (slasher == Slasher.Lookahead) {
            _validateLookaheadSlashingEvidence(urc, _commitment, _evidence[1:]);
            slashAmount_ = getSlashingAmounts().invalidLookahead;
        } else {
            // For preconf slashing, `onMessageInvocation` calls the URC, which further
            // calls this slashing function internally
            require(_challenger == address(this), ChallengerIsNotSelf());
            IPreconfSlasherL2.Fault fault = _getPreconfSlashingFault(_commitment, _evidence[1:]);
            SlashingAmounts memory amounts = getSlashingAmounts();
            slashAmount_ = fault == IPreconfSlasherL2.Fault.Liveness
                ? amounts.preconfLivenessFault
                : amounts.preconfSafetyFault;
        }
    }

    // Bridge communication
    // --------------------------------------------------------------------------

    /// @dev Invoked by `PreconfSlasherL2`
    function onMessageInvocation(bytes calldata _data)
        external
        payable
        onlyFromNamed(LibNames.B_BRIDGE)
    {
        // Verify that the sender on the L2 side is PreconfSlasherL2
        IBridge.Context memory ctx = IBridge(msg.sender).context();
        address preconfSlasherL2 = resolve(ctx.srcChainId, LibNames.B_PRECONF_SLASHER_L2, false);
        require(ctx.from == preconfSlasherL2, CallerIsNotPreconfSlasherL2());

        (
            IPreconfSlasherL2.Fault fault,
            bytes32 registrationRoot,
            ISlasher.SignedCommitment memory signedCommitment
        ) = abi.decode(_data, (IPreconfSlasherL2.Fault, bytes32, ISlasher.SignedCommitment));

        // Slash the operator via the URC
        IRegistry(urc).slashCommitment(registrationRoot, signedCommitment, abi.encode(fault));
    }

    // Views
    // --------------------------------------------------------------------------

    function getSlashingAmounts() public pure returns (SlashingAmounts memory) {
        // Note: These amounts will change
        return SlashingAmounts({
            invalidLookahead: 1 ether,
            preconfLivenessFault: 0.5 ether,
            preconfSafetyFault: 1 ether
        });
    }
}
