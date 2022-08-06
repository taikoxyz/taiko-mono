// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../../common/IMintableERC20.sol";
import "./StatsBasedProtoBroker.sol";

contract TaiProtoBroker is StatsBasedProtoBroker {
    uint256[50] private __gap;

    /// @dev Initializer to be called after being deployed behind a proxy.
    function init(
        address _addressManager,
        uint128 _gasPriceNow,
        uint256 _unsettledProverFeeThreshold,
        uint256 _amountMintToDAO,
        uint256 _amountMintToTeam
    ) external initializer {
        StatsBasedProtoBroker._init(
            _addressManager,
            _gasPriceNow,
            _unsettledProverFeeThreshold
        );

        IMintableERC20 taiToken = IMintableERC20(resolve("tai_token"));
        taiToken.mint(resolve("dao_vault"), _amountMintToDAO);
        taiToken.mint(resolve("team_vault"), _amountMintToTeam);
    }

    function feeToken() public view override returns (address) {
        return resolve("tai_token");
    }

    function pay(address recipient, uint256 amount)
        internal
        override
        returns (bool success)
    {
        if (amount > 0) {
            IMintableERC20(feeToken()).mint(recipient, amount);
        }
        return true;
    }

    function charge(address recipient, uint256 amount)
        internal
        override
        returns (bool success)
    {
        if (amount > 0) {
            IMintableERC20(feeToken()).burn(recipient, amount);
        }
        return true;
    }
}
