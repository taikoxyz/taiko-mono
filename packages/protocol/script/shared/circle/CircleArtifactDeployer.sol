// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, stdJson } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";

import { ICircleFiatToken, ICircleFiatTokenProxy } from "src/shared/thirdparty/ICircleFiatToken.sol";

/// @title CircleProxyAdminBootstrapper
/// @notice Temporarily owns a Circle proxy admin slot during initialization handoff.
/// @custom:security-contact security@taiko.xyz
contract CircleProxyAdminBootstrapper {
    address private immutable OWNER;

    /// @dev Sets the caller allowed to release proxy admin ownership.
    constructor(address _owner) {
        OWNER = _owner;
    }

    /// @notice Releases proxy admin ownership to the final admin.
    /// @param _proxy The Circle proxy whose admin should be transferred.
    /// @param _newAdmin The final proxy admin.
    function release(address _proxy, address _newAdmin) external {
        require(msg.sender == OWNER, "CIRCLE_BOOTSTRAP_NOT_OWNER");
        ICircleFiatTokenProxy(_proxy).changeAdmin(_newAdmin);
    }
}

/// @title CircleArtifactDeployer
/// @notice Deploys the vendored Circle contracts from the dedicated `out/circle` artifacts.
/// @custom:security-contact security@taiko.xyz
abstract contract CircleArtifactDeployer is Script {
    using stdJson for string;

    string internal constant FIAT_TOKEN_PROXY_ARTIFACT =
        "/out/circle/FiatTokenProxy.sol/FiatTokenProxy.json";
    string internal constant FIAT_TOKEN_IMPL_ARTIFACT =
        "/out/circle/FiatTokenV2_2.sol/FiatTokenV2_2.json";
    string internal constant SIGNATURE_CHECKER_ARTIFACT =
        "/out/circle/SignatureChecker.sol/SignatureChecker.json";
    string internal constant SIGNATURE_CHECKER_PLACEHOLDER =
        "__$0c117820338e8c464be62be058786cbf55$__";

    bytes32 internal constant PROXY_IMPLEMENTATION_SLOT =
        keccak256("org.zeppelinos.proxy.implementation");
    bytes32 internal constant PROXY_ADMIN_SLOT = keccak256("org.zeppelinos.proxy.admin");

    uint256 private _circleDeployNonce;
    address internal _lastSignatureCheckerLibrary;
    bytes private _cachedFiatTokenProxyCreationCode;

    struct FiatTokenDeploymentConfig {
        string tokenName;
        string tokenSymbol;
        string tokenCurrency;
        uint8 tokenDecimals;
        address proxyAdmin;
        address masterMinter;
        address pauser;
        address blacklister;
        address owner;
    }

    /// @dev Builds an absolute artifact path from the repo root.
    function _artifactPath(string memory _relativePath)
        internal
        view
        returns (string memory path_)
    {
        path_ = string.concat(vm.projectRoot(), _relativePath);
    }

    /// @dev Loads the creation code from a Foundry JSON artifact.
    function _creationCode(string memory _relativeArtifactPath)
        internal
        view
        returns (bytes memory creationCode_)
    {
        creationCode_ = _hexStringToBytes(_rawCreationCode(_relativeArtifactPath));
    }

    /// @dev Returns the Circle proxy creation code, caching it after the first artifact read.
    function _fiatTokenProxyCreationCode() internal returns (bytes memory creationCode_) {
        if (_cachedFiatTokenProxyCreationCode.length == 0) {
            _cachedFiatTokenProxyCreationCode = _creationCode(FIAT_TOKEN_PROXY_ARTIFACT);
        }
        creationCode_ = _cachedFiatTokenProxyCreationCode;
    }

    /// @dev Deploys arbitrary creation code with CREATE2 to avoid nonce coupling across tests.
    function _deployCreationCode(bytes memory _code) internal returns (address deployed_) {
        bytes32 salt =
            keccak256(abi.encodePacked(block.chainid, _circleDeployNonce++, keccak256(_code)));
        assembly {
            deployed_ := create2(0, add(_code, 0x20), mload(_code), salt)
        }
        require(deployed_ != address(0), "CIRCLE_DEPLOY_FAILED");
    }

    /// @dev Deploys a linked FiatTokenV2_2 implementation.
    function _deployFiatTokenImplementation() internal returns (address impl_) {
        address signatureChecker = _deployCreationCode(_creationCode(SIGNATURE_CHECKER_ARTIFACT));
        _lastSignatureCheckerLibrary = signatureChecker;
        console2.log("Circle SignatureChecker library:", signatureChecker);
        impl_ = _deployCreationCode(
            _hexStringToBytes(
                _linkLibrary(
                    _rawCreationCode(FIAT_TOKEN_IMPL_ARTIFACT),
                    SIGNATURE_CHECKER_PLACEHOLDER,
                    signatureChecker
                )
            )
        );

        console2.log("Circle FiatTokenV2_2 implementation:", impl_);
    }

    /// @dev Deploys and initializes a FiatToken proxy against an existing implementation.
    function _deployFiatTokenProxy(
        address _implementation,
        FiatTokenDeploymentConfig memory _config
    )
        internal
        returns (address proxy_)
    {
        proxy_ = _deployCreationCode(
            abi.encodePacked(_fiatTokenProxyCreationCode(), abi.encode(_implementation))
        );

        address initialAdmin = _proxyAdmin(proxy_);
        address bootstrapAdmin = _config.proxyAdmin;

        // Circle blocks proxy admins from reaching fallback, so if the current admin is also the
        // intended final admin we first hand admin rights to a temporary helper.
        if (_config.proxyAdmin == initialAdmin) {
            bootstrapAdmin = address(new CircleProxyAdminBootstrapper(initialAdmin));
        }

        // The proxy constructor sets the initial admin directly. Move that role away before
        // calling initialize through the proxy, otherwise fallback delegation is blocked.
        ICircleFiatTokenProxy(proxy_).changeAdmin(bootstrapAdmin);

        ICircleFiatToken fiatToken = ICircleFiatToken(proxy_);
        fiatToken.initialize(
            _config.tokenName,
            _config.tokenSymbol,
            _config.tokenCurrency,
            _config.tokenDecimals,
            _config.masterMinter,
            _config.pauser,
            _config.blacklister,
            _config.owner
        );
        fiatToken.initializeV2(_config.tokenName);
        fiatToken.initializeV2_1(_config.owner);
        fiatToken.initializeV2_2(new address[](0), _config.tokenSymbol);

        if (bootstrapAdmin != _config.proxyAdmin) {
            CircleProxyAdminBootstrapper(bootstrapAdmin).release(proxy_, _config.proxyAdmin);
        }

        console2.log("Circle FiatTokenProxy:", proxy_);
    }

    /// @dev Deploys and initializes a FiatToken implementation + proxy pair.
    function _deployFiatToken(FiatTokenDeploymentConfig memory _config)
        internal
        returns (address impl_, address proxy_)
    {
        impl_ = _deployFiatTokenImplementation();
        proxy_ = _deployFiatTokenProxy(impl_, _config);
    }

    /// @dev Loads the raw creation code hex string from a Foundry JSON artifact.
    function _rawCreationCode(string memory _relativeArtifactPath)
        internal
        view
        returns (string memory creationCode_)
    {
        string memory artifact = vm.readFile(_artifactPath(_relativeArtifactPath));
        creationCode_ = artifact.readString(".bytecode.object");
    }

    /// @dev Reads the proxy admin slot directly. The proxy's admin() function is only callable by
    /// the admin and otherwise falls back into the implementation.
    function _proxyAdmin(address _proxy) internal view returns (address admin_) {
        admin_ = address(uint160(uint256(vm.load(_proxy, PROXY_ADMIN_SLOT))));
    }

    /// @dev Reads the proxy implementation slot directly.
    function _proxyImplementation(address _proxy) internal view returns (address implementation_) {
        implementation_ = address(uint160(uint256(vm.load(_proxy, PROXY_IMPLEMENTATION_SLOT))));
    }

    /// @dev Replaces every occurrence of a solc library placeholder with the deployed library
    /// address encoded as 40 hex characters.
    function _linkLibrary(
        string memory _rawHex,
        string memory _placeholder,
        address _library
    )
        internal
        pure
        returns (string memory linkedHex_)
    {
        bytes memory rawHex = bytes(_rawHex);
        bytes memory placeholder = bytes(_placeholder);
        bytes memory libraryHex = bytes(_addressToHexString(_library));

        require(placeholder.length == libraryHex.length, "CIRCLE_LINK_LENGTH");
        for (uint256 i; i + placeholder.length <= rawHex.length; ++i) {
            bool matches = true;
            for (uint256 j; j < placeholder.length; ++j) {
                if (rawHex[i + j] != placeholder[j]) {
                    matches = false;
                    break;
                }
            }

            if (!matches) continue;

            for (uint256 j; j < libraryHex.length; ++j) {
                rawHex[i + j] = libraryHex[j];
            }
            i += placeholder.length - 1;
        }

        linkedHex_ = string(rawHex);
    }

    /// @dev Converts an address to a 40-character lowercase hex string without a `0x` prefix.
    function _addressToHexString(address _addr) internal pure returns (string memory hexString_) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory value = abi.encodePacked(_addr);
        bytes memory str = new bytes(40);

        for (uint256 i; i < value.length; ++i) {
            str[i * 2] = alphabet[uint8(value[i] >> 4)];
            str[(i * 2) + 1] = alphabet[uint8(value[i] & 0x0f)];
        }

        hexString_ = string(str);
    }

    /// @dev Converts a `0x`-prefixed hex string into bytes without relying on `vm.parseBytes`.
    function _hexStringToBytes(string memory _rawHex)
        internal
        pure
        returns (bytes memory decoded_)
    {
        bytes memory rawHex = bytes(_rawHex);
        require(rawHex.length >= 2, "CIRCLE_INVALID_HEX");
        require(rawHex[0] == "0" && (rawHex[1] == "x" || rawHex[1] == "X"), "CIRCLE_INVALID_HEX");
        require((rawHex.length - 2) % 2 == 0, "CIRCLE_INVALID_HEX_LENGTH");

        decoded_ = new bytes((rawHex.length - 2) / 2);
        for (uint256 i; i < decoded_.length; ++i) {
            decoded_[i] = bytes1(
                (_fromHexChar(uint8(rawHex[2 + (i * 2)])) << 4)
                    | _fromHexChar(uint8(rawHex[3 + (i * 2)]))
            );
        }
    }

    /// @dev Converts a single ASCII hex character into its numeric value.
    function _fromHexChar(uint8 _char) internal pure returns (uint8 value_) {
        if (_char >= uint8(bytes1("0")) && _char <= uint8(bytes1("9"))) {
            return _char - uint8(bytes1("0"));
        }
        if (_char >= uint8(bytes1("a")) && _char <= uint8(bytes1("f"))) {
            return 10 + _char - uint8(bytes1("a"));
        }
        if (_char >= uint8(bytes1("A")) && _char <= uint8(bytes1("F"))) {
            return 10 + _char - uint8(bytes1("A"));
        }
        revert("CIRCLE_INVALID_HEX_CHAR");
    }
}
