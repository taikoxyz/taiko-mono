// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { UUPSUpgradeable } from
    "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Ownable2StepUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { ContextUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import { IMinimalBlacklist } from "@taiko/blacklist/IMinimalBlacklist.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/// @title ECDSAWhitelist
/// @dev Signature-driven mint whitelist
/// @custom:security-contact security@taiko.xyz
contract ECDSAWhitelist is ContextUpgradeable, UUPSUpgradeable, Ownable2StepUpgradeable {
    event MintSignerUpdated(address _mintSigner);
    event MintConsumed(address _minter, uint256 _tokenId);
    event BlacklistUpdated(address _blacklist);

    error MINTS_EXCEEDED();
    error ADDRESS_BLACKLISTED();
    error ONLY_MINT_SIGNER();

    /// @notice Mint signer address
    address public mintSigner;
    /// @notice Tracker for minted signatures
    mapping(bytes32 signatureHash => bool hasMinted) public minted;
    /// @notice Blackist address
    IMinimalBlacklist public blacklist;
    /// @notice Gap for upgrade safety
    uint256[47] private __gap;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Modifier to restrict access to the mint signer
    modifier onlyMintSigner() {
        if (msg.sender != mintSigner) revert ONLY_MINT_SIGNER();
        _;
    }

    /// @notice Update the blacklist address
    /// @param _blacklist The new blacklist address
    function updateBlacklist(IMinimalBlacklist _blacklist) external onlyOwner {
        blacklist = _blacklist;
        emit BlacklistUpdated(address(_blacklist));
    }

    /// @notice Update the mint signer address
    /// @param _mintSigner The new mint signer address
    function updateMintSigner(address _mintSigner) public onlyOwner {
        mintSigner = _mintSigner;
        emit MintSignerUpdated(_mintSigner);
    }

    /// @notice Contract initializer
    /// @param _owner Contract owner
    /// @param _mintSigner Mint signer address
    /// @param _blacklist Blacklist address
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

    /// @notice Generate a standardized hash for externally signing
    /// @param _minter Address of the minter
    /// @param _tokenId ID for the token to mint
    function getHash(address _minter, uint256 _tokenId) public pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(_minter, _tokenId))));
    }

    /// @notice Internal method to verify valid signatures
    /// @param _signature Signature to verify
    /// @param _minter Address of the minter
    /// @param _tokenId ID for the token to mint
    /// @return Whether the signature is valid
    function _isSignatureValid(
        bytes memory _signature,
        address _minter,
        uint256 _tokenId
    )
        internal
        view
        returns (bool)
    {
        bytes32 _hash = getHash(_minter, _tokenId);
        (address _recovered,,) = ECDSA.tryRecover(_hash, _signature);

        return _recovered == mintSigner;
    }

    /// @notice Check if a wallet can mint
    /// @param _signature Signature to verify
    /// @param _minter Address of the minter
    /// @param _tokenId ID for the token to mint
    /// @return Whether the wallet can mint
    function canMint(
        bytes memory _signature,
        address _minter,
        uint256 _tokenId
    )
        public
        view
        returns (bool)
    {
        if (blacklist.isBlacklisted(_minter)) revert ADDRESS_BLACKLISTED();
        if (minted[keccak256(_signature)]) return false;
        return _isSignatureValid(_signature, _minter, _tokenId);
    }

    /// @notice Internal initializer
    /// @param _owner Contract owner
    /// @param _mintSigner Mint signer address
    /// @param _blacklist Blacklist address
    function __ECDSAWhitelist_init(
        address _owner,
        address _mintSigner,
        IMinimalBlacklist _blacklist
    )
        internal
    {
        _transferOwnership(_owner == address(0) ? msg.sender : _owner);
        __Context_init();
        mintSigner = _mintSigner;
        blacklist = _blacklist;
    }

    /// @notice Internal method to consume a mint
    /// @param _signature Signature to verify
    /// @param _minter Address of the minter
    /// @param _tokenId ID for the token to mint
    function _consumeMint(bytes memory _signature, address _minter, uint256 _tokenId) internal {
        if (!canMint(_signature, _minter, _tokenId)) revert MINTS_EXCEEDED();
        minted[keccak256(_signature)] = true;
        emit MintConsumed(_minter, _tokenId);
    }

    /// @notice Internal method to authorize an upgrade
    function _authorizeUpgrade(address) internal virtual override onlyOwner { }
}
