// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from
"@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import {IStandardERC20Upgradeable} from "./IStandardERC20Upgradeable.sol";
import {IERC677Receiver} from "../callbacks/IERC677Receiver.sol";



contract StandardERC20 is ERC20PermitUpgradeable, IStandardERC20Upgradeable {
    /// @inheritdoc IStandardERC20Upgradeable
    address public override gateway;

    /// @inheritdoc IStandardERC20Upgradeable
    address public override counterpart;

    uint8 private decimals_;

    modifier onlyGateway() {
        require(gateway == _msgSender(), "Only Gateway");
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _gateway,
        address _counterpart
    ) external initializer {
        __ERC20Permit_init(_name);
        __ERC20_init(_name, _symbol);

        decimals_ = _decimals;
        gateway = _gateway;
        counterpart = _counterpart;
    }

    function decimals() public view override returns (uint8) {
        return decimals_;
    }

    /// @dev ERC677 Standard, see https://github.com/ethereum/EIPs/issues/677
    /// Defi can use this method to transfer L1/L2 token to L2/L1,
    /// and deposit to L2/L1 contract in one transaction
    function transferAndCall(
        address receiver,
        uint256 amount,
        bytes calldata data
    ) external returns (bool success) {
        ERC20Upgradeable.transfer(receiver, amount);
        if (isContract(receiver)) {
            contractFallback(receiver, amount, data);
        }
        return true;
    }

    function contractFallback(
        address to,
        uint256 value,
        bytes memory data
    ) private {
        IERC677Receiver receiver = IERC677Receiver(to);
        receiver.onTokenTransfer(_msgSender(), value, data);
    }

    function isContract(address _addr) private view returns (bool hasCode) {
        hasCode = _addr.code.length > 0;
    }

    /// @inheritdoc IStandardERC20Upgradeable
    function mint(address _to, uint256 _amount) external onlyGateway {
        _mint(_to, _amount);
    }

    /// @inheritdoc IStandardERC20Upgradeable
    function burn(address _from, uint256 _amount) external onlyGateway {
        _burn(_from, _amount);
    }
}
