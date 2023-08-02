// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { SD59x18, convert} from "https://github.com/PaulRBerg/prb-math/blob/main/src/SD59x18.sol";

library LibFixedPointMath {

  /// @notice Calculates the natural exponent of x using the following formula:
  ///
  /// $$
  /// e^x = 2^{x * log_2{e}}
  /// $$
  ///
  /// @dev Notes:
  /// - Refer to the notes in {exp2}.
  ///
  /// Requirements:
  /// - Refer to the requirements in {exp2}.
  /// - x must be less than 133_084258667509499441.
  ///
  /// @param x The exponent as an SD59x18 number.
  /// @return result The result as an SD59x18 number.
  /// @custom:smtchecker abstract-function-nondet
  function exp(SD59x18 x) external pure returns (int256 result) {
    result = convert(x.exp());
  }

}