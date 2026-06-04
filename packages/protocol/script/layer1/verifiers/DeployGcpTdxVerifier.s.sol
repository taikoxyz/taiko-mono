// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {
    Ownable2StepUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";
import "solady/src/utils/Base64.sol";
import { GcpTdxVerifier } from "src/layer1/verifiers/GcpTdxVerifier.sol";

/// @title DeployGcpTdxVerifier
/// @notice Deploys GcpTdxVerifier (proxy + impl) for native Intel TDX DCAP-attested
/// provers (GCP Confidential VMs, bare-metal TDX), optionally seeds trusted params,
/// and hands ownership to a final owner.
///
/// This is the native-DCAP counterpart of `DeployAzureTdxVerifier`. Instance
/// registration is handled by `cargo run -p xtask -- register-tdx` against a running
/// prover (it auto-detects the native issuer); this script only deploys and, if the
/// trusted-param env vars are present, seeds an initial trusted-params slot so the
/// registry can be bootstrapped before the prover VM is live.
///
/// Required env:
///   PRIVATE_KEY                  — deployer key
///   CONTRACT_OWNER               — final owner address (Ownable2Step pendingOwner)
///   AUTOMATA_DCAP_ATTESTATION    — already-deployed Automata DCAP attestation contract
///   TAIKO_CHAIN_ID               — uint64 L2 chain id bound to proof signatures
///
/// Optional env (set together to seed trusted params inline):
///   TRUSTED_PARAMS_INDEX         — slot to write trusted params into
///   TEE_TCB_SVN                  — bytes32 (top 16 bytes used)
///   RTMR_MASK                    — uint (4-bit mask: which of RTMR0..3 to enforce)
///   MR_SEAM_BASE64               — base64 of the 48-byte mrSeam
///   MR_TD_BASE64                 — base64 of the 48-byte mrTd
///   RTMRS_BASE64                 — comma-separated base64 RTMR digests (48 bytes each),
///                                  one per set bit in RTMR_MASK, in ascending index order
contract DeployGcpTdxVerifier is Script {
    uint256 internal immutable privateKey = vm.envUint("PRIVATE_KEY");
    address internal immutable contractOwner = vm.envAddress("CONTRACT_OWNER");
    address internal immutable automataDcapAttestation = vm.envAddress("AUTOMATA_DCAP_ATTESTATION");
    uint64 internal immutable taikoChainId = uint64(vm.envUint("TAIKO_CHAIN_ID"));

    modifier broadcast() {
        require(privateKey != 0, "config: invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        require(contractOwner != address(0), "config: CONTRACT_OWNER");
        require(automataDcapAttestation != address(0), "config: AUTOMATA_DCAP_ATTESTATION");
        require(taikoChainId != 0, "config: TAIKO_CHAIN_ID");

        console2.log("=====================================");
        console2.log("Deploying GcpTdxVerifier");
        console2.log("=====================================");
        console2.log("** Contract owner:", contractOwner);
        console2.log("** Automata DCAP Attestation:", automataDcapAttestation);
        console2.log("** Taiko chain id:", taikoChainId);

        address tdxVerifier = deployGcpTdxVerifier();

        if (bytes(vm.envOr("MR_SEAM_BASE64", string(""))).length != 0) {
            setupTrustedParams(tdxVerifier);
        } else {
            console2.log("** MR_SEAM_BASE64 not set, skipping trusted params seeding");
            console2.log(
                "**   (use `cargo run -p xtask -- register-tdx --trust ...` after the prover"
                " VM is live)"
            );
        }

        transferOwnership(tdxVerifier);
        verifyDeployment(tdxVerifier);

        console2.log("=====================================");
        console2.log("GcpTdxVerifier deployment complete");
        console2.log("=====================================");
    }

    /// @dev Deploys the GcpTdxVerifier behind an ERC1967 proxy.
    function deployGcpTdxVerifier() internal returns (address proxy) {
        GcpTdxVerifier impl = new GcpTdxVerifier(taikoChainId, automataDcapAttestation);
        console2.log("** Deployed GcpTdxVerifier implementation:", address(impl));

        proxy = address(
            new ERC1967Proxy(
                address(impl), abi.encodeCall(GcpTdxVerifier.init, (vm.addr(privateKey)))
            )
        );
        console2.log("** Deployed GcpTdxVerifier proxy:", proxy);

        writeJson("gcp_tdx_verifier", proxy);
        writeJson("gcp_tdx_verifier_impl", address(impl));
    }

    /// @dev Seeds an initial trusted-params slot (teeTcbSvn, mrSeam, mrTd, RTMRs).
    function setupTrustedParams(address _tdxVerifier) internal {
        uint256 trustedParamsIndex = vm.envUint("TRUSTED_PARAMS_INDEX");
        bytes16 teeTcbSvn = bytes16(vm.envBytes32("TEE_TCB_SVN"));
        uint8 rtmrMask = uint8(vm.envUint("RTMR_MASK"));

        console2.log("** Setting up trusted params at index:", trustedParamsIndex);

        bytes memory mrSeam = Base64.decode(vm.envString("MR_SEAM_BASE64"));
        bytes memory mrTd = Base64.decode(vm.envString("MR_TD_BASE64"));
        require(mrSeam.length == 48, "mrSeam must be 48 bytes");
        require(mrTd.length == 48, "mrTd must be 48 bytes");

        bytes[] memory rtmrs = getRtmrsFromEnv();
        console2.log("** RTMR mask:", rtmrMask);
        console2.log("** RTMRs count:", rtmrs.length);

        GcpTdxVerifier.TrustedParams memory params = GcpTdxVerifier.TrustedParams({
            teeTcbSvn: teeTcbSvn, rtmrMask: rtmrMask, mrSeam: mrSeam, mrTd: mrTd, rtmrs: rtmrs
        });

        GcpTdxVerifier(_tdxVerifier).setTrustedParams(trustedParamsIndex, params);
        console2.log("** Trusted params set");
    }

    function getRtmrsFromEnv() internal view returns (bytes[] memory) {
        string memory rtmrsEnv = vm.envString("RTMRS_BASE64");
        string[] memory rtmrsBase64 = vm.split(rtmrsEnv, ",");
        bytes[] memory rtmrs = new bytes[](rtmrsBase64.length);

        for (uint256 i = 0; i < rtmrsBase64.length; ++i) {
            bytes memory decoded = Base64.decode(rtmrsBase64[i]);
            require(decoded.length == 48, "RTMR must be 48 bytes");
            rtmrs[i] = decoded;
        }
        return rtmrs;
    }

    function transferOwnership(address _tdxVerifier) internal {
        console2.log("** Transferring ownership to:", contractOwner);
        Ownable2StepUpgradeable(_tdxVerifier).transferOwnership(contractOwner);
        console2.log("** Ownership transfer initiated (requires acceptance)");
    }

    function verifyDeployment(address _tdxVerifier) internal view {
        GcpTdxVerifier v = GcpTdxVerifier(_tdxVerifier);

        require(
            v.automataDcapAttestation() == automataDcapAttestation,
            "verify: automataDcapAttestation mismatch"
        );
        require(v.taikoChainId() == taikoChainId, "verify: taikoChainId mismatch");

        address pendingOwner = Ownable2StepUpgradeable(_tdxVerifier).pendingOwner();
        require(pendingOwner == contractOwner, "verify: pending owner mismatch");

        console2.log("** Deployment verified");
    }

    function writeJson(string memory name, address addr) internal {
        vm.writeJson(
            vm.serializeAddress("deployment", name, addr),
            string.concat(vm.projectRoot(), "/deployments/deploy_gcp_tdx_verifier.json")
        );
    }
}
