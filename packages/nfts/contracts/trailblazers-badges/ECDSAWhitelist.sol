// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { UUPSUpgradeable } from
    "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Ownable2StepUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { ContextUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import { IMinimalBlacklist } from "@taiko/blacklist/IMinimalBlacklist.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/// @title ECDSAWhitelist
/// @dev Merkle Tree Whitelist
/// @custom:security-contact security@taiko.xyz
contract ECDSAWhitelist is ContextUpgradeable, UUPSUpgradeable, Ownable2StepUpgradeable {
    event MintSignerUpdated(address _mintSigner);

    event MintConsumed(address _minter, uint256 _mintId);
    event BlacklistUpdated(address _blacklist);

    error MINTS_EXCEEDED();
    error ADDRESS_BLACKLISTED();
    error ONLY_MINT_SIGNER();

    address public mintSigner;
    /// @notice Tracker for minted signatures
    mapping(bytes signature => bool hasMinted) public minted;
    /// @notice Blackist address
    IMinimalBlacklist public blacklist;
    /// @notice Gap for upgrade safety
    uint256[47] private __gap;

    modifier onlyMintSigner() {
        if(msg.sender != mintSigner) revert ONLY_MINT_SIGNER();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Update the blacklist address
    /// @param _blacklist The new blacklist address
    function updateBlacklist(IMinimalBlacklist _blacklist) external onlyOwner {
        blacklist = _blacklist;
        emit BlacklistUpdated(address(_blacklist));
    }

    function initialize(
        address _owner,
        address _mintSigner,
        IMinimalBlacklist _blacklist
    )
        external
        initializer
    {
        __ECDSAWhitelist_init(_owner, _mintSigner, _blacklist);
    }

    function getHash(address _minter, uint256 _mintId) public pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(_minter, _mintId))));
    }

    function _isSignatureValid(
        bytes memory _signature,
        address _minter,
        uint256 _mintId
    )
        internal
        view
        returns (bool)
    {
        bytes32 _hash = getHash(_minter, _mintId);
        (address _recovered, ECDSA.RecoverError _error, bytes32 _signatureLength) = ECDSA.tryRecover(_hash, _signature);
        return _recovered == mintSigner;
    }

    function canMint(
        bytes memory _signature,
        address _minter,
        uint256 _mintId
    )
        public
        view
        returns (bool)
    {
        if (blacklist.isBlacklisted(_minter)) revert ADDRESS_BLACKLISTED();
        if (minted[_signature]) return false;
        return _isSignatureValid(_signature, _minter, _mintId);
    }

    function caMint(

    )

    function __ECDSAWhitelist_init(
        address _owner,
        address _mintSigner,
        IMinimalBlacklist _blacklist
    )
        internal
        initializer
    {
        _transferOwnership(_owner == address(0) ? msg.sender : _owner);
        __Context_init();
        mintSigner = _mintSigner;
        blacklist = _blacklist;
    }

    function _updateMintSigner(address _mintSigner) internal {
        mintSigner = _mintSigner;
        emit MintSignerUpdated(_mintSigner);
    }

    function _consumeMint(bytes memory _signature, address _minter, uint256 _mintId) internal {
        if (!canMint(_signature, _minter, _mintId)) revert MINTS_EXCEEDED();
        minted[_signature] = true;
        emit MintConsumed(_minter, _mintId);
    }

    /// @notice Internal method to authorize an upgrade
    function _authorizeUpgrade(address) internal virtual override onlyOwner { }
}
