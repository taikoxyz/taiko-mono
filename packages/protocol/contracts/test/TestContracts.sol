// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SignalService } from "../signal/SignalService.sol";
import { TokenVault } from "../bridge/TokenVault.sol";
import { EtherVault } from "../bridge/EtherVault.sol";
import { BridgedERC20 } from "../bridge/BridgedERC20.sol";
import { Bridge } from "../bridge/Bridge.sol";
import { TaikoToken } from "../L1/TaikoToken.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

// The old implementation that is also used in hardhat tests.

contract TestERC20 is ERC20 {
    constructor(uint256 initialSupply) ERC20("TestERC20", "TEST") {
        _mint(msg.sender, initialSupply);
    }
}

contract TestSignalService is SignalService { }

contract TestTokenVault is TokenVault { }

contract TestEtherVault is EtherVault { }

contract TestBridgedERC20 is BridgedERC20 { }

contract TestBridge is Bridge { }

contract TestTaikoToken is TaikoToken {
    function mintAnyone(address account, uint256 amount) public {
        _mint(account, amount);
    }
}
