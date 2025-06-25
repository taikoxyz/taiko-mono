// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/EssentialContract.sol";
import "src/shared/based/ITaiko.sol";
import "./libs/LibBonds2.sol";
// import "./libs/LibInit2.sol";
import "./libs/LibPropose2.sol";
import "./libs/LibProve2.sol";
// import "./libs/LibRead2.sol";
import "./libs/LibVerify2.sol";
import "./ITaikoInbox2.sol";
import "./IProposeBatch2.sol";

/// @title TaikoInbox2
/// @notice Acts as the inbox for the Taiko Alethia protocol, a simplified version of the
/// original Taiko-Based Contestable Rollup (BCR) but with the tier-based proof system and
/// contestation mechanisms removed.
///
/// Key assumptions of this protocol:
/// - Block proposals and proofs are asynchronous. Proofs are not available at proposal time,
///   unlike Taiko Gwyneth, which assumes synchronous composability.
/// - Proofs are presumed error-free and thoroughly validated, with subproofs/multiproofs management
/// delegated to IVerifier contracts.
///
/// @dev Registered in the address resolver as "taiko".
/// @custom:security-contact security@taiko.xyz
abstract contract TaikoInbox2 is
    EssentialContract,
    ITaikoInbox2,
    IProposeBatch2,
    IBondManager2,
    ITaiko
{
    using LibBonds2 for ITaikoInbox2.State;
    using LibPropose2 for ITaikoInbox2.State;
    using LibProve2 for ITaikoInbox2.State;
    using LibVerify2 for ITaikoInbox2.State;

    address public immutable inboxWrapper;
    address public immutable verifier;
    address internal immutable bondToken;
    address public immutable signalService;

    State public state; // storage layout much match Ontake fork
    uint256[50] private __gap;

    // External functions ------------------------------------------------------------------------

    constructor(
        address _inboxWrapper,
        address _verifier,
        address _bondToken,
        address _signalService
    )
        nonZeroAddr(_verifier)
        nonZeroAddr(_signalService)
        EssentialContract()
    {
        inboxWrapper = _inboxWrapper;
        verifier = _verifier;
        bondToken = _bondToken;
        signalService = _signalService;
    }

    function v4Init(address _owner, bytes32 _genesisBlockHash) external initializer {
        __Taiko_init(_owner, _genesisBlockHash);
    }

    function v4ProposeBatch(
        I.Summary calldata _summary,
        I.BatchProposeMetadataEvidence calldata _parentProposeMetaEvidence,
        I.BatchParams calldata _params,
        bytes calldata _txList,
        bytes calldata _additionalData,
        I.TransitionMeta[] calldata _trans
    )
        public
        // override(ITaikoInbox2, IProposeBatch2)
        nonReentrant
        returns (I.BatchMetadata memory meta_, I.Summary memory summary_)
    {
        LibData2.Env memory env = _loadEnv();
        (meta_, summary_) = state.proposeBatch(
            env, _summary, _parentProposeMetaEvidence, _params, _txList, _additionalData
        );

        summary_ = state.verifyBatches(env, summary_, _trans, 1);

        bytes32 newSummaryHash = (keccak256(abi.encode(summary_)) & ~bytes32(uint256(1)))
            | (env.prevSummaryHash & bytes32(uint256(1)));
        state.summaryHash = newSummaryHash;
        emit I.SummaryUpdated(summary_, newSummaryHash);
    }

    function v4ProveBatches(
        I.Summary calldata _summary,
        I.BatchProveMetadataEvidence[] calldata _evidences,
        I.Transition[] calldata _trans,
        bytes calldata _proof
    )
        external
        nonReentrant
        returns (I.Summary memory summary_)
    {
        LibData2.Env memory env = _loadEnv();
        summary_ = state.proveBatches(env, _summary, _evidences, _trans, _proof);

        bytes32 newSummaryHash = (keccak256(abi.encode(summary_)) & ~bytes32(uint256(1)))
            | (env.prevSummaryHash & bytes32(uint256(1)));
        state.summaryHash = newSummaryHash;
        emit I.SummaryUpdated(summary_, newSummaryHash);
    }

    function v4DepositBond(uint256 _amount) external payable whenNotPaused {
        state.bondBalance[msg.sender] += LibBonds2.depositBond(bondToken, msg.sender, _amount);
    }

    function v4WithdrawBond(uint256 _amount) external whenNotPaused {
        state.withdrawBond(bondToken, _amount);
    }

    function v4BondToken() external view returns (address) {
        return bondToken;
    }

    function v4BondBalanceOf(address _user) external view returns (uint256) {
        return state.bondBalance[_user];
    }

    function v4IsInbox() external pure override returns (bool) {
        return true;
    }

    // Public functions -------------------------------------------------------------------------

    function paused() public view override returns (bool) {
        return state.summaryHash & bytes32(uint256(1)) != 0;
    }

    function v4GetConfig() external view virtual returns (Config memory) {
        return _getConfig();
    }

    // Internal functions ----------------------------------------------------------------------

    function __Taiko_init(address _owner, bytes32 _genesisBlockHash) internal onlyInitializing {
        __Essential_init(_owner);
        // state.init(_genesisBlockHash); // TODO
    }

    function _unpause() internal override {
        // TODO
        // state.stats2.lastUnpausedAt = uint64(block.timestamp);
        // state.stats2.paused = false;
    }

    function _pause() internal override {
        // TODO
        // state.stats2.paused = true;
    }

    function _getConfig() internal view virtual returns (Config memory);

    function _loadEnv() private view returns (LibData2.Env memory) {
        return LibData2.Env({
            config: _getConfig(),
            bondToken: bondToken,
            verifier: verifier,
            inboxWrapper: inboxWrapper,
            signalService: signalService,
            prevSummaryHash: state.summaryHash
        });
    }
}
