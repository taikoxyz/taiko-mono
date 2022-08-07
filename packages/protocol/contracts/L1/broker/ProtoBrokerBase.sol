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
    /**********************
     * State Variables    *
     **********************/
    uint128 public amountToMintToDAOThreshold;
    uint128 public amountToMintToDAO;
    uint256[49] private __gap;

    /**********************
     * Events             *
     **********************/
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

    /**********************
     * Public Functions   *
     **********************/

    function chargeProposer(
        uint256 blockId,
        address proposer,
        uint128 gasLimit,
        uint64 numUnprovenBlocks
    ) public virtual override returns (uint128 proposerFee) {
        proposerFee = getProposerFee(gasLimit, numUnprovenBlocks);

        require(chargeFee(proposer, proposerFee), "failed to charge");
        emit FeeReceived(blockId, proposer, proposerFee);
    }

    function payProvers(
        uint256 blockId,
        uint64 proposedAt,
        uint64 provenAt,
        uint128 proposerFee,
        address[] memory provers
    ) public virtual override returns (uint128 totalProverFee) {
        uint128[] memory proverFees;
        (proverFees, totalProverFee) = calculateProverFees(
            proposerFee,
            provenAt - proposedAt,
            provers
        );

        for (uint256 i = 0; i < proverFees.length; i++) {
            address prover = provers[i];
            uint128 proverFee = proverFees[i];
            if (proverFee == 0) break;

            if (!payFee(prover, proverFee)) {
                amountToMintToDAO += proverFee;
            }

            emit FeePaid(blockId, prover, proverFee, i);
        }

        amountToMintToDAO += totalProverFee;

        if (
            amountToMintToDAO > amountToMintToDAOThreshold &&
            !payFee(resolve("dao_reserve"), amountToMintToDAO - 1)
        ) {
            amountToMintToDAO = 1;
        }
    }

    function getProposerFee(uint128 gasLimit, uint64 numUnprovenBlocks)
        public
        view
        override
        returns (uint128)
    {
        uint128 gasPrice = getProposerGasPrice(numUnprovenBlocks);
        return gasPrice * (gasLimit + getGasLimitBase());
    }

    /**********************
     * Internal Functions *
     **********************/

    /// @dev Initializer to be called after being deployed behind a proxy.
    function _init(address _addressManager, uint128 _amountToMintToDAOThreshold)
        internal
        virtual
    {
        require(_amountToMintToDAOThreshold > 0, "threshold too small");
        EssentialContract._init(_addressManager);
        amountToMintToDAOThreshold = _amountToMintToDAOThreshold;
    }

    function calculateProverFees(
        uint128 proposerFee,
        uint64, /*provingDelay*/
        address[] memory provers
    ) internal virtual returns (uint128[] memory fees, uint128 totalFees);

    function payFee(
        address, /*recipient*/
        uint256 /*amount*/
    )
        internal
        virtual
        returns (
            bool /*success*/
        );

    function chargeFee(
        address, /*recipient*/
        uint256 /*amount*/
    )
        internal
        virtual
        returns (
            bool /*success*/
        );

    function getProposerGasPrice(
        uint64 /*numUnprovenBlocks*/
    ) internal view virtual returns (uint128);

    function getGasLimitBase() internal pure virtual returns (uint128);
}
