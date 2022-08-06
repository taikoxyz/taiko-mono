// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../../common/EssentialContract.sol";
import "./IProtoBroker.sol";

abstract contract ProtoBrokerBase is IProtoBroker, EssentialContract {
    uint128 public unsettledProverFeeThreshold;
    uint128 public unsettledProverFee;
    uint128 internal _suggestedGasPrice;

    uint256[48] private __gap;

    event FeeReceived(
        uint256 indexed blockId,
        address indexed account,
        uint256 amount
    );
    event FeePaid(
        uint256 indexed blockId,
        address indexed account,
        uint256 amount,
        uint256 uncleId
    );

    function chargeProposer(
        uint256 blockId,
        address proposer,
        uint128 gasLimit,
        uint64 numUnprovenBlocks
    ) public virtual override returns (uint128 proposerFee) {
        proposerFee = getProposerFee(gasLimit, numUnprovenBlocks);

        require(_chargeFee(proposer, proposerFee), "failed to charge");
        emit FeeReceived(blockId, proposer, proposerFee);
    }

    function payProver(
        uint256 blockId,
        address prover,
        uint256 uncleId,
        uint64 proposedAt,
        uint64 provenAt,
        uint128 proposerFee
    ) public virtual override returns (uint128 proverFee) {
        proverFee = _getProverFee(proposerFee, provenAt - proposedAt);

        proverFee /= uint128(uncleId + 1);

        if (proverFee > 0) {
            address daoVault = resolve("dao_reserve");
            if (uncleId == 0 && proverFee > proposerFee) {
                uint128 mintAmount = proverFee - proposerFee;
                if (!_payFee(daoVault, mintAmount)) {
                    unsettledProverFee += mintAmount;
                }
            } else {
                if (!_payFee(daoVault, proverFee)) {
                    unsettledProverFee += proverFee;
                }
            }

            if (!_payFee(prover, proverFee)) {
                unsettledProverFee += proverFee;
            }

            if (unsettledProverFee > unsettledProverFeeThreshold) {
                if (_payFee(resolve("dao_vault"), unsettledProverFee - 1)) {
                    unsettledProverFee = 1;
                }
            }
        }

        emit FeePaid(blockId, prover, proverFee, uncleId);
    }

    function getProposerFee(uint128 gasLimit, uint64 numUnprovenBlocks)
        public
        view
        override
        returns (uint128)
    {
        uint128 gasPrice = _getProposerGasPrice(numUnprovenBlocks);
        return _calculateFee(gasPrice, gasLimit);
    }

    /// @dev Initializer to be called after being deployed behind a proxy.
    function _init(
        address _addressManager,
        uint128 _unsettledProverFeeThreshold
    ) internal virtual {
        require(_unsettledProverFeeThreshold > 0, "threshold too small");
        EssentialContract._init(_addressManager);
        unsettledProverFeeThreshold = _unsettledProverFeeThreshold;
    }

    function _getProverFee(
        uint128 proposerFee,
        uint64 /*provingDelay*/
    ) internal virtual returns (uint128) {
        return proposerFee;
    }

    function _payFee(
        address, /*recipient*/
        uint256 /*amount*/
    )
        internal
        virtual
        returns (
            bool /*success*/
        );

    function _chargeFee(
        address, /*recipient*/
        uint256 /*amount*/
    )
        internal
        virtual
        returns (
            bool /*success*/
        );

    function _getProposerGasPrice(
        uint64 /*numUnprovenBlocks*/
    ) internal view virtual returns (uint128);

    function _gasLimitBase() internal pure virtual returns (uint128);

    function _calculateFee(uint128 gasPrice, uint128 gasLimit)
        private
        pure
        returns (uint128)
    {
        return gasPrice * (gasLimit + _gasLimitBase());
    }
}
