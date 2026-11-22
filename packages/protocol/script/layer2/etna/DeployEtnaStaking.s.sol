// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { LibEtnaStakingEnv } from "./LibEtnaStakingEnv.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";
import { EtnaStaking } from "src/layer2/etna/EtnaStaking.sol";
import { EtnaStakingDeployer } from "src/layer2/etna/EtnaStakingDeployer.sol";
import { IEtnaStaking } from "src/layer2/etna/iface/IEtnaStaking.sol";

/// @title DeployEtnaStaking
/// @notice Deploys `EtnaStaking` on the L2 of a network that switches from Unzen, before
/// `ETNA_FORK_TIME` (spec section 10, step 1): one transaction to the CREATE2 factory creates an
/// `EtnaStakingDeployer`, whose constructor creates the implementation and the proxy and
/// initializes the proxy with its owner. The deployer's address follows from the factory, the
/// salt, the deployer's init code and the configuration and owner; the implementation's and the
/// proxy's follow from the deployer's. `predict` computes all three, so they are known before
/// deployment. The EL, the nodes and both guests build in the proxy and the implementation address
/// for the L2 chain id, so the build that fixes them must be the released one: any change to the
/// bytecode of `EtnaStakingDeployer`, `EtnaStaking` or `ERC1967Proxy` moves both.
///
/// Run it against the L2 with the `layer2` profile and any funded sender (`--private-key`,
/// `--account` or a hardware wallet), which pays for the transaction and gains no role. Without
/// `--broadcast` it simulates the deployment and logs the addresses.
///
/// Environment variables:
/// - L2_CHAIN_ID: the L2 chain id, which must be the chain's own
/// - CONTRACT_OWNER: the proxy's owner, the DAO's execution address on L2; nonzero
/// - EVIDENCE_WINDOW_BLOCKS: the double-sign evidence window, in L2 blocks; nonzero
/// - ETNA_UNSETTLED_LIMIT (optional): U, the Inbox's maximum number of unsettled L2 blocks, in
///   [1, 262,144]; `DEFAULT_UNSETTLED_LIMIT` (151,200) when unset or empty
/// - DEPLOYMENT_SALT (optional): the factory salt, a 32-byte hex value; zero when unset or empty
/// - the `EtnaStaking` configuration, which `LibEtnaStakingEnv` reads
/// `withdrawalDelay` must be at least U + 2 + EVIDENCE_WINDOW_BLOCKS. U is an Inbox value, so no
/// contract sees both and this script checks the bound; U must be the one the Inbox's
/// configuration fixes. An optional variable that is set but malformed reverts instead of falling
/// back to its default.
/// @custom:security-contact security@taiko.xyz
contract DeployEtnaStaking is Script {
    /// @notice U when ETNA_UNSETTLED_LIMIT is unset or empty: 151,200, about seven days of
    /// 4-second blocks.
    uint256 public constant DEFAULT_UNSETTLED_LIMIT = 151_200;

    // ---------------------------------------------------------------
    // External & Public Functions
    // ---------------------------------------------------------------

    /// @notice Deploys `EtnaStaking` from the environment and logs the three addresses.
    /// @return impl_ The `EtnaStaking` implementation.
    /// @return proxy_ The `EtnaStaking` proxy, initialized with CONTRACT_OWNER.
    function run() external returns (address impl_, address proxy_) {
        require(vm.envUint("L2_CHAIN_ID") == block.chainid, L2ChainIdMismatch());
        IEtnaStaking.Config memory config = LibEtnaStakingEnv.readConfig();
        address owner = vm.envAddress("CONTRACT_OWNER");
        bytes32 salt = _isSet("DEPLOYMENT_SALT") ? vm.envBytes32("DEPLOYMENT_SALT") : bytes32(0);
        uint256 unsettledLimit = _isSet("ETNA_UNSETTLED_LIMIT")
            ? vm.envUint("ETNA_UNSETTLED_LIMIT")
            : DEFAULT_UNSETTLED_LIMIT;

        (impl_, proxy_) =
            deploy(config, owner, salt, unsettledLimit, vm.envUint("EVIDENCE_WINDOW_BLOCKS"));

        (address deployer,,) = predict(config, owner, salt);
        console2.log("EtnaStakingDeployer:", deployer);
        console2.log("EtnaStaking implementation:", impl_);
        console2.log("EtnaStaking proxy:", proxy_);
        console2.log("  owner:", owner);
        console2.log(
            "The EL, the nodes and both guests build in the proxy and the implementation address."
        );
        console2.log("Export the proxy as ETNA_STAKING for the Etna Inbox configuration.");
    }

    /// @notice Returns the addresses a deployment of `_config` owned by `_owner` with factory salt
    /// `_salt` creates, whether or not it has happened.
    /// @param _config The `EtnaStaking` configuration.
    /// @param _owner The proxy's owner.
    /// @param _salt The factory salt.
    /// @return deployer_ The `EtnaStakingDeployer`, created by the CREATE2 factory.
    /// @return impl_ The implementation, created by the deployer with salt zero.
    /// @return proxy_ The proxy, created by the deployer with salt zero.
    function predict(
        IEtnaStaking.Config memory _config,
        address _owner,
        bytes32 _salt
    )
        public
        pure
        returns (address deployer_, address impl_, address proxy_)
    {
        deployer_ = vm.computeCreate2Address(
            _salt, keccak256(_deployerInitCode(_config, _owner)), CREATE2_FACTORY
        );
        impl_ = vm.computeCreate2Address(
            bytes32(0),
            keccak256(abi.encodePacked(type(EtnaStaking).creationCode, abi.encode(_config))),
            deployer_
        );
        proxy_ = vm.computeCreate2Address(
            bytes32(0),
            keccak256(
                abi.encodePacked(
                    type(ERC1967Proxy).creationCode,
                    abi.encode(impl_, abi.encodeCall(EtnaStaking.init, (_owner)))
                )
            ),
            deployer_
        );
    }

    /// @notice Deploys `EtnaStaking` in one broadcast call to the CREATE2 factory.
    /// @dev Reverts before broadcasting if `_owner` is zero, `_unsettledLimit` is outside
    /// [1, `LibEtnaStakingEnv.MAX_UNSETTLED_LIMIT`], `_evidenceWindowBlocks` is zero,
    /// `withdrawalDelay` is below U + 2 + `_evidenceWindowBlocks` (these three are
    /// `LibEtnaStakingEnv.checkWithdrawalDelay`'s) or the deployer already exists. The factory
    /// reverts without data when a constructor reverts, so `DeploymentFailed` also covers a
    /// configuration that `EtnaStaking`'s constructor refuses with `InvalidConfig`, and a missing
    /// factory.
    /// @param _config The `EtnaStaking` configuration.
    /// @param _owner The proxy's owner, the DAO's execution address on L2.
    /// @param _salt The factory salt.
    /// @param _unsettledLimit U, the Inbox's maximum number of unsettled L2 blocks.
    /// @param _evidenceWindowBlocks The double-sign evidence window, in L2 blocks.
    /// @return impl_ The implementation, at `predict`'s address.
    /// @return proxy_ The proxy, at `predict`'s address and initialized with `_owner`.
    function deploy(
        IEtnaStaking.Config memory _config,
        address _owner,
        bytes32 _salt,
        uint256 _unsettledLimit,
        uint256 _evidenceWindowBlocks
    )
        public
        returns (address impl_, address proxy_)
    {
        require(_owner != address(0), ZeroOwner());
        LibEtnaStakingEnv.checkWithdrawalDelay(
            _config.withdrawalDelay, _unsettledLimit, _evidenceWindowBlocks
        );
        address deployer;
        (deployer, impl_, proxy_) = predict(_config, _owner, _salt);
        require(deployer.code.length == 0, AlreadyDeployed());

        vm.broadcast();
        (bool ok, bytes memory created) =
            CREATE2_FACTORY.call(abi.encodePacked(_salt, _deployerInitCode(_config, _owner)));
        // The factory returns the created address as 20 bytes.
        require(
            ok && created.length == 20 && address(bytes20(created)) == deployer, DeploymentFailed()
        );
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Returns the `EtnaStakingDeployer` init code for `_config` and `_owner`.
    /// @param _config The `EtnaStaking` configuration.
    /// @param _owner The proxy's owner.
    /// @return The creation code followed by the ABI-encoded constructor arguments.
    function _deployerInitCode(
        IEtnaStaking.Config memory _config,
        address _owner
    )
        private
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(type(EtnaStakingDeployer).creationCode, abi.encode(_config, _owner));
    }

    /// @dev Returns whether an optional variable holds a non-empty value, which the caller then
    /// parses strictly. `vm.envOr` would also return its default for a malformed value.
    /// @param _name The variable name.
    /// @return Whether the variable is set and non-empty.
    function _isSet(string memory _name) private view returns (bool) {
        return vm.envExists(_name) && bytes(vm.envString(_name)).length != 0;
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error AlreadyDeployed();
    error DeploymentFailed();
    error L2ChainIdMismatch();
    error ZeroOwner();
}
