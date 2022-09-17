// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

import "../common/EssentialContract.sol";
import "../thirdparty/ERC20Upgradeable.sol";

/// @author dantaik <dan@taiko.xyz>
interface IBridgedERC20 is IERC20Upgradeable, IERC20MetadataUpgradeable {
    event BridgeMint(address indexed account, uint256 amount);
    event BridgeBurn(address indexed account, uint256 amount);

    function bridgeMintTo(address account, uint256 amount) external;

    function bridgeBurnFrom(address account, uint256 amount) external;

    function source()
        external
        view
        returns (address srcToken, uint256 srcChainId);
}

/// @author dantaik <dan@taiko.xyz>
contract BridgedERC20 is EssentialContract, ERC20Upgradeable, IBridgedERC20 {
    address public srcToken;
    uint256 public srcChainId;

    uint256[48] private __gap;

    /// @dev Initializer to be called after being deployed behind a proxy.
    function init(
        address _addressManager,
        address _srcToken,
        uint256 _srcChainId,
        uint8 _decimals,
        string memory _symbol,
        string memory _name
    ) external initializer {
        require(
            srcToken != address(0) &&
                _srcChainId != 0 &&
                _srcChainId != block.chainid &&
                bytes(_symbol).length > 0 &&
                bytes(_name).length > 0,
            "BE:params"
        );
        EssentialContract._init(_addressManager);
        ERC20Upgradeable.__ERC20_init(_name, _symbol, _decimals);
        srcToken = _srcToken;
        srcChainId = _srcChainId;
    }

    function bridgeMintTo(address account, uint256 amount)
        public
        override
        onlyFromNamed("token_vault")
    {
        _mint(account, amount);
        emit BridgeMint(account, amount);
    }

    function bridgeBurnFrom(address account, uint256 amount)
        public
        override
        onlyFromNamed("token_vault")
    {
        _burn(account, amount);
        emit BridgeBurn(account, amount);
    }

    function transfer(address to, uint256 amount)
        public
        override(ERC20Upgradeable, IERC20Upgradeable)
        returns (bool)
    {
        require(to != address(this), "BE:to");
        return ERC20Upgradeable.transfer(to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override(ERC20Upgradeable, IERC20Upgradeable) returns (bool) {
        require(to != address(this), "BE:to");
        return ERC20Upgradeable.transferFrom(from, to, amount);
    }

    function source() public view returns (address, uint256) {
        return (srcToken, srcChainId);
    }
}
