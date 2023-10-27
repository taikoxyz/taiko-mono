// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { TaikoL2 } from "./TaikoL2.sol";
import { Proxied } from "../common/Proxied.sol";

/// @title TaikoL2EIP1559Configurable
/// @notice Taiko L2 extended with parameter setting
contract TaikoL2EIP1559Configurable is TaikoL2 {
    event ConfigChanged(Config config);

    /// @notice Sets EIP1559 related configurations
    /// @param _baseFeeConfig The new config settings.
    function setConfig(Config memory _baseFeeConfig)
        public
        virtual
        onlyOwner
        validConfig(_baseFeeConfig)
    {
        gasExcess = _baseFeeConfig.gasExcess;
        gasTargetPerL1Block = _baseFeeConfig.gasTargetPerL1Block;
        basefeeAdjustmentQuotient = _baseFeeConfig.basefeeAdjustmentQuotient;

        emit ConfigChanged(_baseFeeConfig);
    }
}

/// @title ProxiedTaikoL2EIP1559Configurable
/// @notice Proxied version of the TaikoL2EIP1559Configurable contract.
contract ProxiedTaikoL2EIP1559Configurable is
    Proxied,
    TaikoL2EIP1559Configurable
{ }
