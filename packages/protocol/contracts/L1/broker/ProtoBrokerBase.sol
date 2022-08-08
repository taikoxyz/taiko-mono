// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

import "../../common/EssentialContract.sol";
import "./IProtoBroker.sol";

abstract contract ProtoBrokerBase is IProtoBroker, EssentialContract {
    using SafeCastUpgradeable for uint256;
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
        uint256 gasLimit,
        uint256 numUnprovenBlocks
    ) public virtual override returns (uint256 proposerFee) {
        proposerFee = getProposerFee(gasLimit, numUnprovenBlocks);

        require(chargeFee(proposer, proposerFee), "failed to charge");
        emit FeeReceived(blockId, proposer, proposerFee);
    }

    function payProvers(
        uint256 blockId,
        uint256 proposedAt,
        uint256 provenAt,
        uint256 proposerFee,
        address[] memory provers
    ) public virtual override returns (uint256 totalProverFee) {
        uint256[] memory proverFees;
        (proverFees, totalProverFee) = calculateProverFees(
            proposerFee,
            provenAt - proposedAt,
            provers
        );

        for (uint256 i = 0; i < proverFees.length; i++) {
            address prover = provers[i];
            uint256 proverFee = proverFees[i];
            if (proverFee == 0) break;

            payFee(prover, proverFee);
            emit FeePaid(blockId, prover, proverFee, i);
        }

        if (totalProverFee > proposerFee) {
            amountToMintToDAO += totalProverFee.toUint128();
        }

        if (
            amountToMintToDAO > amountToMintToDAOThreshold &&
            !payFee(resolve("dao_reserve"), amountToMintToDAO - 1)
        ) {
            amountToMintToDAO = 1;
        }
    }

    function getProposerFee(uint256 gasLimit, uint256 numUnprovenBlocks)
        public
        view
        override
        returns (uint256)
    {
        return
            getProposerGasPrice(numUnprovenBlocks) *
            (gasLimit + getGasLimitBase());
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
        uint256 proposerFee,
        uint256, /*provingDelay*/
        address[] memory provers
    ) internal virtual returns (uint256[] memory fees, uint256 totalFees);

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
        uint256 /*numUnprovenBlocks*/
    ) internal view virtual returns (uint256);

    function getGasLimitBase() internal pure virtual returns (uint256);
}
