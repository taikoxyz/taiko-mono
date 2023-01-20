// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

/**
 * @author dantaik <dan@taiko.xyz>
 * @notice This library offers two functions for EIP-1559-style math.
 *      See more at https://dankradfeist.de/ethereum/2022/03/16/exponential-eip1559.html
 */
library Lib1559Math {
    /**
     * @notice Calculates and returns the next round's target value using the equation below:
     *
     *      `nextTarget = prevTarget * ((A-1) * T + prevMeasured / (A * T)`
     *      which implies if `prevMeasured` is larger than `T`, `nextTarget` will
     *      become larger than `prevTarget`.
     *
     * @param prevTarget The previous round's target value.
     * @param prevMeasured The previous round's measured value. It must be in the same unit as `T`.
     * @param T The base target value. It must be in the same unit as `prevMeasured`.
     * @param A The adjustment factor. Bigger values change the next round's target more slowly.
     * @return nextTarget The next round's target value.
     */
    function adjustTarget(
        uint256 prevTarget,
        uint256 prevMeasured,
        uint256 T,
        uint256 A
    ) internal pure returns (uint256 nextTarget) {
        assert(prevTarget != 0 && T != 0 && A > 1);

        uint256 x = prevTarget * ((A - 1) * T + prevMeasured);
        uint256 y = A * T;
        nextTarget = x / y;

        if (nextTarget == 0) {
            nextTarget = prevTarget;
        }
    }

    /**
     * @notice Calculates and returns the next round's target value using the equation below:
     *
     *      `nextTarget = prevTarget * A * T / ((A-1) * T + prevMeasured)`
     *      which implies if `prevMeasured` is larger than `T`, `nextTarget` will
     *      become smaller than `prevTarget`.
     *
     * @param prevTarget The previous round's target value.
     * @param prevMeasured The previous round's measured value. It must be in the same unit as `T`.
     * @param T The base target value. It must be in the same unit as `prevMeasured`.
     * @param A The adjustment factor. Bigger values change the next round's target more slowly.
     * @return nextTarget The next round's target value.
     */
    function adjustTargetReverse(
        uint256 prevTarget,
        uint256 prevMeasured,
        uint256 T,
        uint256 A
    ) internal pure returns (uint256 nextTarget) {
        assert(prevTarget != 0 && T != 0 && A > 1);

        uint256 x = prevTarget * A * T;
        uint256 y = (A - 1) * T + prevMeasured;
        nextTarget = x / y;

        if (nextTarget == 0) {
            nextTarget = prevTarget;
        }
    }
}
