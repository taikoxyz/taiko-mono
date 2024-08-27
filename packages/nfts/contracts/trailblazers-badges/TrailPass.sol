// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "./ECDSAWhitelist.sol";
import "@taiko/blacklist/IMinimalBlacklist.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@taiko/blacklist/IMinimalBlacklist.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@taiko/blacklist/IMinimalBlacklist.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

contract TrailPass is
    PausableUpgradeable,
    UUPSUpgradeable,
    Ownable2StepUpgradeable,
    AccessControlUpgradeable,
    ERC1155SupplyUpgradeable
{
    // important wallets
    address public levelUpSigner;

    // token ids
    uint256 public constant PASS_TIER_A_PINK = 0;
    uint256 public constant PASS_TIER_A_PURPLE = 1;
    uint256 public constant PASS_TIER_B_PINK = 2;
    uint256 public constant PASS_TIER_B_PURPLE = 3;
    uint256 public constant PASS_TIER_C_PINK = 4;
    uint256 public constant PASS_TIER_C_PURPLE = 5;

    mapping(address _user => uint256 _exp) public userExp;

    uint256[] public TOKEN_IDS = [
        PASS_TIER_A_PINK,
        PASS_TIER_A_PURPLE,
        PASS_TIER_B_PINK,
        PASS_TIER_B_PURPLE,
        PASS_TIER_C_PINK,
        PASS_TIER_C_PURPLE
    ];

    // tier prices
    uint256 public constant TIER_A_PRICE = 10 ether;
    uint256 public constant TIER_B_PRICE = 5 ether;
    uint256 public constant TIER_C_PRICE = 3 ether;

    uint256[42] private __gap;

    error TOKEN_CANNOT_BE_TRANSFERRED();
    error BATTLE_PASS_ALREADY_OWNED();
    error BATTLE_PASS_NOT_OWNED();
    error INVALID_TIER();
    error INVALID_LEVEL_UP_SIGNATURE();
    error INVALID_EXP_AMOUNT();

    function initialize(address _levelUpSigner) external initializer {
        __ERC1155_init("");
        __ERC1155Supply_init();
        _transferOwnership(_msgSender());
        __Context_init();

        levelUpSigner = _levelUpSigner;
    }

    modifier onlyNewUser() {
        if (hasPass(_msgSender())) {
            revert BATTLE_PASS_ALREADY_OWNED();
        }
        _;
    }

    modifier requireBattlePass(uint256 _tier) {
        if (!hasPass(_msgSender(), _tier)) {
            revert BATTLE_PASS_NOT_OWNED();
        }
        _;
    }

    modifier requireAnyBattlePass() {
        if (!hasPass(_msgSender())) {
            revert BATTLE_PASS_NOT_OWNED();
        }
        _;
    }

    function getTierPrice(uint256 _tokenId) public view returns (uint256) {
        if (_tokenId == PASS_TIER_A_PINK || _tokenId == PASS_TIER_A_PURPLE) {
            return TIER_A_PRICE;
        } else if (_tokenId == PASS_TIER_B_PINK || _tokenId == PASS_TIER_B_PURPLE) {
            return TIER_B_PRICE;
        } else if (_tokenId == PASS_TIER_C_PINK || _tokenId == PASS_TIER_C_PURPLE) {
            return TIER_C_PRICE;
        }
        revert INVALID_TIER();
    }

    function mint(uint256 _tier) public payable onlyNewUser {
        uint256 price = getTierPrice(_tier);
        if (msg.value < price) {
            revert("Insufficient funds");
        }

        _mint(_msgSender(), _tier, 1, "");
    }

    function withdrawStake() public requireAnyBattlePass {
        uint256 tier = getUserTier(_msgSender());
        uint256 price = getTierPrice(tier);
        _burn(_msgSender(), tier, 1);
        payable(_msgSender()).transfer(price);
    }

    function hasPass(address _user, uint256 _tier) public view returns (bool) {
        return balanceOf(_user, _tier) > 0;
    }

    function hasPass(address _user) public view returns (bool) {
        for (uint256 i = 0; i < TOKEN_IDS.length; i++) {
            if (hasPass(_user, TOKEN_IDS[i])) {
                return true;
            }
        }
        return false;
    }

    function getUserTier(address _user) public view returns (uint256 tier) {
        for (uint256 i = 0; i < TOKEN_IDS.length; i++) {
            if (hasPass(_user, TOKEN_IDS[i])) {
                return TOKEN_IDS[i];
            }
        }
        revert BATTLE_PASS_NOT_OWNED();
    }

    // makes the season pass non-transferable
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    )
        internal
        override
    {
        if (from != address(0)) {
            revert TOKEN_CANNOT_BE_TRANSFERRED();
        }
        super._update(from, to, ids, values);
    }

    /// @notice supportsInterface implementation
    /// @param interfaceId The interface ID
    /// @return Whether the interface is supported
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /// @notice Internal method to authorize an upgrade
    function _authorizeUpgrade(address) internal virtual override onlyOwner { }

    // todo: methods to register points from the backend
    /// @notice Generate a standardized hash for externally signing
    /// @param _minter Address of the minter
    /// @param _tokenId ID for the token to mint
    function getHash(address _minter, uint256 _tokenId) public pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(_minter, _tokenId))));
    }

    function _isSignatureValid(
        bytes memory _signature,
        address _minter,
        uint256 _exp
    )
        internal
        view
        returns (bool)
    {
        bytes32 _hash = getHash(_minter, _exp);
        (address _recovered,,) = ECDSA.tryRecover(_hash, _signature);

        return _recovered == levelUpSigner;
    }

    function getExp(address _user) public view returns (uint256) {
        if (!hasPass(_user)) {
            revert BATTLE_PASS_NOT_OWNED();
        }
        return userExp[_user];
    }

    function getLevel(address _user) public view returns (uint256) {
        if (!hasPass(_user)) {
            revert BATTLE_PASS_NOT_OWNED();
        }
        return userExp[_user] / 100;
    }

    function levelUp(uint256 _exp, bytes memory _signature) public requireAnyBattlePass {
        if (!_isSignatureValid(_signature, _msgSender(), _exp)) {
            revert INVALID_LEVEL_UP_SIGNATURE();
        }
        if (_exp < getExp(_msgSender())) {
            revert INVALID_EXP_AMOUNT();
        }
        userExp[_msgSender()] = _exp;
    }
}
