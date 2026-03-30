// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EmptyImpl } from "./common/EmptyImpl.sol";
import {
    Ownable2StepUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {
    UUPSUpgradeable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { console2 } from "forge-std/src/console2.sol";
import { IRealTimeInbox } from "src/layer1/core/iface/IRealTimeInbox.sol";
import { RealTimeInbox } from "src/layer1/core/impl/RealTimeInbox.sol";
import { SurgeVerifier } from "src/layer1/surge/SurgeVerifier.sol";
import { LibProofBitmap } from "src/layer1/surge/libs/LibProofBitmap.sol";
import { ZiskVerifier } from "src/layer1/verifiers/ZiskVerifier.sol";
import { ZiskVerifierImpl } from "src/layer1/verifiers/zisk-vendor/ZiskVerifierImpl.sol";
import { Bridge } from "src/shared/bridge/Bridge.sol";
import { DefaultResolver } from "src/shared/common/DefaultResolver.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";
import { BridgedERC1155 } from "src/shared/vault/BridgedERC1155.sol";
import { BridgedERC20 } from "src/shared/vault/BridgedERC20.sol";
import { BridgedERC721 } from "src/shared/vault/BridgedERC721.sol";
import { ERC1155Vault } from "src/shared/vault/ERC1155Vault.sol";
import { ERC20Vault } from "src/shared/vault/ERC20Vault.sol";
import { ERC721Vault } from "src/shared/vault/ERC721Vault.sol";
import { DeployCapability } from "test/shared/DeployCapability.sol";

/// @title DeployRealTimeSurgeL1
/// @notice Deploys the Surge protocol with real-time proving inbox on L1.
/// @custom:security-contact security@nethermind.io
contract DeployRealTimeSurgeL1 is DeployCapability {
    uint256 internal constant ADDRESS_LENGTH = 40;

    // Signer configuration
    // ---------------------------------------------------------------
    uint256 internal immutable privateKey = vm.envUint("PRIVATE_KEY");

    // Owner configuration
    // ---------------------------------------------------------------
    address internal immutable contractOwner = vm.envAddress("CONTRACT_OWNER");

    // L2 configuration
    // ---------------------------------------------------------------
    uint64 internal immutable l2ChainId = uint64(vm.envUint("L2_CHAIN_ID"));

    // Zisk Verifier Configuration
    // ---------------------------------------------------------------
    bytes32 internal immutable ziskProgramVKey = vm.envOr("ZISK_PROGRAM_VKEY", bytes32(0));

    // SurgeVerifier configuration
    // ---------------------------------------------------------------
    uint8 internal immutable numProofsThreshold = uint8(vm.envUint("NUM_PROOFS_THRESHOLD"));

    // Inbox configuration
    // ---------------------------------------------------------------
    uint8 internal immutable basefeeSharingPctg = uint8(vm.envUint("BASEFEE_SHARING_PCTG"));

    // Genesis configuration
    // ---------------------------------------------------------------
    bytes32 internal immutable genesisBlockHash = vm.envBytes32("GENESIS_BLOCK_HASH");

    struct SharedContracts {
        address sharedResolver;
        address signalService;
        address bridge;
        address erc20Vault;
        address erc721Vault;
        address erc1155Vault;
    }

    struct RollupContracts {
        address proofVerifier;
        address inbox;
    }

    struct VerifierContracts {
        address ziskRethVerifier;
    }

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        require(l2ChainId != block.chainid && l2ChainId != 0, "config: L2_CHAIN_ID");
        require(contractOwner != address(0), "config: CONTRACT_OWNER");

        console2.log("** Contract owner: ", contractOwner);

        // Empty implementation for temporary use
        address emptyImpl = address(new EmptyImpl());
        writeJson("empty_impl", emptyImpl);

        // Deploy rollup contracts (inbox proxy and proof verifier)
        // ---------------------------------------------------------------
        RollupContracts memory rollupContracts = deployRollupContracts(emptyImpl);

        // Deploy internal verifiers (needed for SurgeVerifier)
        // ---------------------------------------------------------------
        VerifierContracts memory verifierContracts = deployInternalVerifiers(contractOwner);

        // Deploy shared contracts
        // ---------------------------------------------------------------
        SharedContracts memory sharedContracts =
            deploySharedContracts(contractOwner, rollupContracts);

        // Register L2 addresses in the resolver
        setupSharedResolver(sharedContracts, contractOwner);

        // Setup proof verifier with internal verifiers
        // ---------------------------------------------------------------
        setupProofVerifier(rollupContracts, verifierContracts, contractOwner);

        // Deploy inbox implementation and activate
        // ---------------------------------------------------------------
        setupInbox(rollupContracts, sharedContracts, contractOwner);

        // Verify deployment
        // ---------------------------------------------------------------
        verifyDeployment(sharedContracts, rollupContracts, verifierContracts, contractOwner);

        console2.log("=====================================");
        console2.log("Real-Time Surge L1 Deployment Complete");
        console2.log("=====================================");
    }

    function deploySharedContracts(
        address _owner,
        RollupContracts memory _rollupContracts
    )
        internal
        returns (SharedContracts memory sharedContracts)
    {
        // Deploy shared resolver
        // ---------------------------------------------------------------
        sharedContracts.sharedResolver = deployProxy({
            name: "shared_resolver",
            impl: address(new DefaultResolver()),
            // Owner is initially the deployer contract because we need to register the contracts
            data: abi.encodeCall(DefaultResolver.init, (address(0)))
        });

        // Deploy signal service
        // ---------------------------------------------------------------
        sharedContracts.signalService = deployProxy({
            name: "signal_service",
            impl: address(new SignalService(_rollupContracts.inbox, getL2SignalServiceAddress())),
            data: abi.encodeCall(SignalService.init, (_owner)),
            registerTo: sharedContracts.sharedResolver
        });

        // Deploy bridge
        // ---------------------------------------------------------------
        sharedContracts.bridge = deployProxy({
            name: "bridge",
            impl: address(
                new Bridge(address(sharedContracts.sharedResolver), sharedContracts.signalService)
            ),
            data: abi.encodeCall(Bridge.init, (_owner)),
            registerTo: sharedContracts.sharedResolver
        });

        // Deploy Vaults
        // ---------------------------------------------------------------
        sharedContracts.erc20Vault = deployProxy({
            name: "erc20_vault",
            impl: address(new ERC20Vault(address(sharedContracts.sharedResolver))),
            data: abi.encodeCall(ERC20Vault.init, (_owner)),
            registerTo: sharedContracts.sharedResolver
        });

        sharedContracts.erc721Vault = deployProxy({
            name: "erc721_vault",
            impl: address(new ERC721Vault(address(sharedContracts.sharedResolver))),
            data: abi.encodeCall(ERC721Vault.init, (_owner)),
            registerTo: sharedContracts.sharedResolver
        });

        sharedContracts.erc1155Vault = deployProxy({
            name: "erc1155_vault",
            impl: address(new ERC1155Vault(address(sharedContracts.sharedResolver))),
            data: abi.encodeCall(ERC1155Vault.init, (_owner)),
            registerTo: sharedContracts.sharedResolver
        });

        // Deploy Bridged token implementations (clone pattern)
        // ---------------------------------------------------------------
        address bridgedErc20 = address(new BridgedERC20(sharedContracts.erc20Vault));
        register(sharedContracts.sharedResolver, "bridged_erc20", bridgedErc20);
        writeJson("bridged_erc20", bridgedErc20);

        address bridgedErc721 = address(new BridgedERC721(address(sharedContracts.erc721Vault)));
        register(sharedContracts.sharedResolver, "bridged_erc721", bridgedErc721);
        writeJson("bridged_erc721", bridgedErc721);

        address bridgedErc1155 = address(new BridgedERC1155(address(sharedContracts.erc1155Vault)));
        register(sharedContracts.sharedResolver, "bridged_erc1155", bridgedErc1155);
        writeJson("bridged_erc1155", bridgedErc1155);
    }

    function deployRollupContracts(address _emptyImpl)
        internal
        returns (RollupContracts memory rollupContracts)
    {
        // Deploy inbox proxy
        // ---------------------------------------------------------------
        rollupContracts.inbox =
            deployProxy({ name: "real_time_inbox", impl: _emptyImpl, data: "" });

        // Deploy proof verifier (SurgeVerifier)
        // ---------------------------------------------------------------
        rollupContracts.proofVerifier =
            address(new SurgeVerifier(rollupContracts.inbox, numProofsThreshold, msg.sender));
        console2.log("** Deployed SurgeVerifier:", rollupContracts.proofVerifier);
        writeJson("surge_verifier", rollupContracts.proofVerifier);
    }

    /// @dev The deployer is the initial owner of the Zisk verifier.
    /// Ownership is transferred to the effective owner and must be accepted.
    function deployInternalVerifiers(address _owner)
        private
        returns (VerifierContracts memory verifierContracts)
    {
        // Deploy Zisk PLONK verifier (from Polygon Hermez)
        ZiskVerifierImpl ziskPlonkVerifier = new ZiskVerifierImpl();
        writeJson("zisk_plonk_verifier", address(ziskPlonkVerifier));
        console2.log("** Deployed Zisk PLONK verifier:", address(ziskPlonkVerifier));

        // rootCVadcopFinal for Zisk v0.16.0
        uint64[4] memory rootCVadcopFinal = [
            uint64(9_211_010_158_316_595_036),
            uint64(7_055_235_338_110_277_438),
            uint64(2_391_371_252_028_311_145),
            uint64(10_691_781_997_660_262_077)
        ];

        // Deploy Zisk wrapper verifier
        ZiskVerifier ziskVerifier =
            new ZiskVerifier(l2ChainId, address(ziskPlonkVerifier), rootCVadcopFinal, msg.sender);
        verifierContracts.ziskRethVerifier = address(ziskVerifier);
        writeJson("zisk_verifier", address(ziskVerifier));
        console2.log("** Deployed Zisk verifier:", address(ziskVerifier));

        // Set trusted program VKeys
        setupZiskVerifier(ziskVerifier);

        // Transfer ownership (requires acceptance)
        ziskVerifier.transferOwnership(_owner);
        console2.log("** Zisk verifier ownership transfer initiated to:", _owner);
    }

    /// @dev Sets the trusted program VKey on the Zisk verifier (skipped if no vkey provided).
    function setupZiskVerifier(ZiskVerifier _ziskVerifier) private {
        if (ziskProgramVKey == bytes32(0)) {
            console2.log("** Skipping Zisk program VKey setup (none provided)");
            return;
        }

        _ziskVerifier.setProgramTrusted(ziskProgramVKey, true);
        console2.log("** Set trusted program VKey:");
        console2.logBytes32(ziskProgramVKey);
    }

    function setupSharedResolver(
        SharedContracts memory _sharedContracts,
        address _owner
    )
        internal
    {
        // Register L2 addresses
        // ---------------------------------------------------------------
        register(
            _sharedContracts.sharedResolver,
            "signal_service",
            getL2SignalServiceAddress(),
            l2ChainId
        );
        register(_sharedContracts.sharedResolver, "bridge", getL2BridgeAddress(), l2ChainId);
        register(
            _sharedContracts.sharedResolver, "erc20_vault", getL2Erc20VaultAddress(), l2ChainId
        );
        register(
            _sharedContracts.sharedResolver, "erc721_vault", getL2Erc721VaultAddress(), l2ChainId
        );
        register(
            _sharedContracts.sharedResolver, "erc1155_vault", getL2Erc1155VaultAddress(), l2ChainId
        );

        // Requires ownership acceptance
        DefaultResolver(_sharedContracts.sharedResolver).transferOwnership(_owner);
        console2.log("** SharedResolver ownership transfer initiated to:", _owner);
    }

    function setupProofVerifier(
        RollupContracts memory _rollupContracts,
        VerifierContracts memory _verifierContracts,
        address _owner
    )
        internal
    {
        SurgeVerifier proofVerifier = SurgeVerifier(_rollupContracts.proofVerifier);

        if (_verifierContracts.ziskRethVerifier != address(0)) {
            proofVerifier.setVerifier(
                LibProofBitmap.ProofBitmap.wrap(proofVerifier.ZISK_RETH()),
                _verifierContracts.ziskRethVerifier
            );
            console2.log("** Set ZISK verifier:", _verifierContracts.ziskRethVerifier);
        }

        // Requires ownership acceptance
        proofVerifier.transferOwnership(_owner);
        console2.log("** Proof verifier ownership transfer initiated to:", _owner);
    }

    function setupInbox(
        RollupContracts memory _rollupContracts,
        SharedContracts memory _sharedContracts,
        address _owner
    )
        internal
    {
        // Build inbox configuration
        IRealTimeInbox.Config memory config = IRealTimeInbox.Config({
            proofVerifier: _rollupContracts.proofVerifier,
            signalService: _sharedContracts.signalService,
            basefeeSharingPctg: basefeeSharingPctg
        });

        // Deploy inbox implementation
        address inboxImpl = address(new RealTimeInbox(config));
        console2.log("** Deployed RealTimeInbox implementation: ", inboxImpl);
        writeJson("real_time_inbox_impl", inboxImpl);

        // Upgrade inbox proxy to actual implementation
        UUPSUpgradeable(_rollupContracts.inbox).upgradeTo(inboxImpl);

        // Initialize inbox
        RealTimeInbox(payable(_rollupContracts.inbox)).init(msg.sender);
        console2.log("** RealTimeInbox initialized");

        // Activate inbox with genesis block hash
        RealTimeInbox(payable(_rollupContracts.inbox)).activate(genesisBlockHash);
        console2.log("** RealTimeInbox activated with genesis block hash");

        // Requires ownership acceptance
        Ownable2StepUpgradeable(_rollupContracts.inbox).transferOwnership(_owner);
        console2.log("** Inbox ownership transfer initiated to:", _owner);
    }

    function verifyDeployment(
        SharedContracts memory _sharedContracts,
        RollupContracts memory _rollupContracts,
        VerifierContracts memory _verifierContracts,
        address _expectedOwner
    )
        internal
        view
    {
        // Verify L1 registrations
        verifyL1Registrations(_sharedContracts.sharedResolver);

        // Verify L2 registrations
        verifyL2Registrations(_sharedContracts.sharedResolver);

        // Verify inbox state
        require(
            RealTimeInbox(payable(_rollupContracts.inbox)).getLastFinalizedBlockHash()
                == genesisBlockHash,
            "verifyDeployment: lastFinalizedBlockHash mismatch"
        );

        // Build list of contracts where owner is already set
        address[] memory ownerContracts = new address[](5);
        ownerContracts[0] = _sharedContracts.signalService;
        ownerContracts[1] = _sharedContracts.bridge;
        ownerContracts[2] = _sharedContracts.erc20Vault;
        ownerContracts[3] = _sharedContracts.erc721Vault;
        ownerContracts[4] = _sharedContracts.erc1155Vault;

        // Build list of contracts with pending ownership transfer
        address[] memory pendingOwnerContracts = new address[](4);
        pendingOwnerContracts[0] = _rollupContracts.proofVerifier;
        pendingOwnerContracts[1] = _rollupContracts.inbox;
        pendingOwnerContracts[2] = _sharedContracts.sharedResolver;
        pendingOwnerContracts[3] = _verifierContracts.ziskRethVerifier;

        // Verify ownership
        verifyOwnership(ownerContracts, pendingOwnerContracts, _expectedOwner);

        console2.log("** Deployment verified **");
    }

    function verifyL1Registrations(address _sharedResolver) internal view {
        bytes32[] memory sharedNames = new bytes32[](8);
        sharedNames[0] = bytes32("signal_service");
        sharedNames[1] = bytes32("bridge");
        sharedNames[2] = bytes32("erc20_vault");
        sharedNames[3] = bytes32("erc721_vault");
        sharedNames[4] = bytes32("erc1155_vault");
        sharedNames[5] = bytes32("bridged_erc20");
        sharedNames[6] = bytes32("bridged_erc721");
        sharedNames[7] = bytes32("bridged_erc1155");

        for (uint256 i = 0; i < sharedNames.length; i++) {
            try DefaultResolver(_sharedResolver).resolve(
                block.chainid, sharedNames[i], false
            ) returns (address) { } catch {
                revert(
                    string.concat(
                        "verifyL1Registrations: missing registration for ",
                        Strings.toHexString(uint256(sharedNames[i]))
                    )
                );
            }
        }
    }

    function verifyL2Registrations(address _sharedResolver) internal view {
        require(
            DefaultResolver(_sharedResolver).resolve(l2ChainId, bytes32("signal_service"), false)
                == getL2SignalServiceAddress(),
            "verifyL2Registrations: signal_service mismatch"
        );
        require(
            DefaultResolver(_sharedResolver).resolve(l2ChainId, bytes32("bridge"), false)
                == getL2BridgeAddress(),
            "verifyL2Registrations: bridge mismatch"
        );
        require(
            DefaultResolver(_sharedResolver).resolve(l2ChainId, bytes32("erc20_vault"), false)
                == getL2Erc20VaultAddress(),
            "verifyL2Registrations: erc20_vault mismatch"
        );
        require(
            DefaultResolver(_sharedResolver).resolve(l2ChainId, bytes32("erc721_vault"), false)
                == getL2Erc721VaultAddress(),
            "verifyL2Registrations: erc721_vault mismatch"
        );
        require(
            DefaultResolver(_sharedResolver).resolve(l2ChainId, bytes32("erc1155_vault"), false)
                == getL2Erc1155VaultAddress(),
            "verifyL2Registrations: erc1155_vault mismatch"
        );

        console2.log("** L2 registrations verified **");
    }

    function verifyOwnership(
        address[] memory _ownerContracts,
        address[] memory _pendingOwnerContracts,
        address _expectedOwner
    )
        internal
        view
    {
        for (uint256 i; i < _ownerContracts.length; ++i) {
            if (_ownerContracts[i] == address(0)) continue;

            address currentOwner = Ownable2StepUpgradeable(_ownerContracts[i]).owner();
            require(
                currentOwner == _expectedOwner,
                string.concat(
                    "verifyOwnership: ", Strings.toHexString(uint160(_ownerContracts[i]), 20)
                )
            );
        }

        for (uint256 i; i < _pendingOwnerContracts.length; ++i) {
            if (_pendingOwnerContracts[i] == address(0)) continue;

            address pendingOwner =
                Ownable2StepUpgradeable(_pendingOwnerContracts[i]).pendingOwner();
            require(
                pendingOwner == _expectedOwner,
                string.concat(
                    "verifyPendingOwnership: ",
                    Strings.toHexString(uint160(_pendingOwnerContracts[i]), 20)
                )
            );
        }
    }

    // ---------------------------------------------------------------
    // L2 Address Getters
    // ---------------------------------------------------------------

    function getL2BridgeAddress() internal view returns (address) {
        return getConstantAddress(vm.toString(l2ChainId), "1");
    }

    function getL2Erc20VaultAddress() internal view returns (address) {
        return getConstantAddress(vm.toString(l2ChainId), "2");
    }

    function getL2Erc721VaultAddress() internal view returns (address) {
        return getConstantAddress(vm.toString(l2ChainId), "3");
    }

    function getL2Erc1155VaultAddress() internal view returns (address) {
        return getConstantAddress(vm.toString(l2ChainId), "4");
    }

    function getL2SignalServiceAddress() internal view returns (address) {
        return getConstantAddress(vm.toString(l2ChainId), "5");
    }

    // ---------------------------------------------------------------
    // Utilities
    // ---------------------------------------------------------------

    function getConstantAddress(
        string memory prefix,
        string memory suffix
    )
        internal
        pure
        returns (address)
    {
        bytes memory prefixBytes = bytes(prefix);
        bytes memory suffixBytes = bytes(suffix);

        require(
            prefixBytes.length + suffixBytes.length <= ADDRESS_LENGTH, "Prefix + suffix too long"
        );

        uint256 paddingLength = ADDRESS_LENGTH - prefixBytes.length - suffixBytes.length;
        bytes memory padding = new bytes(paddingLength);
        for (uint256 i = 0; i < paddingLength; i++) {
            padding[i] = "0";
        }

        string memory hexString = string(abi.encodePacked("0x", prefix, string(padding), suffix));

        return vm.parseAddress(hexString);
    }

    /// @dev Writes an address to the deployment JSON file
    function writeJson(string memory name, address addr) internal {
        vm.writeJson(
            vm.serializeAddress("deployment", name, addr),
            string.concat(vm.projectRoot(), "/deployments/deploy_real_time_l1.json")
        );
    }
}
