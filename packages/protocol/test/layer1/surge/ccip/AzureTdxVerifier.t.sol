// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AzureTDXTestData } from "./helpers/AzureTDXTestData.sol";
import { AzureTDXTestUtils } from "./helpers/AzureTDXTestUtils.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { AzureTDX } from "azure-tdx-verifier/AzureTDX.sol";
import { Test } from "forge-std/src/Test.sol";
import { AzureTDXVerifier } from "src/layer1/surge/ccip/AzureTDXVerifier.sol";

contract AzureTDXVerifierTest is Test {
    using AzureTDXTestData for *;
    using AzureTDXTestUtils for *;

    /// @notice Automata DCAP Attestation contract on mainnet
    address internal constant AUTOMATA_DCAP_ATTESTATION =
        0x95175096a9B74165BE0ac84260cc14Fc1c0EF5FF;

    /// @notice Mainnet fork block number
    uint256 internal constant FORK_BLOCK = 24_152_600;

    AzureTDXVerifier public verifier;
    address public owner = address(this);

    function setUp() public {
        // Fork mainnet
        string memory defaultRpc = "https://ethereum-rpc.publicnode.com";
        vm.createSelectFork(vm.envOr("MAINNET_FORK_URL", defaultRpc), FORK_BLOCK);

        // Set up Automata mainnet collaterals
        AzureTDXTestUtils.setUpAutomataMainnetCollaterals();

        // Deploy implementation
        AzureTDXVerifier impl = new AzureTDXVerifier(AUTOMATA_DCAP_ATTESTATION);

        // Deploy proxy
        ERC1967Proxy proxy =
            new ERC1967Proxy(address(impl), abi.encodeCall(AzureTDXVerifier.init, (owner)));

        verifier = AzureTDXVerifier(address(proxy));
    }

    /// @notice Tests registering a TDX instance
    function test_registerInstance_succeeds() external {
        // Get test data
        (
            AzureTDX.VerifyParams memory verifyParams,
            AzureTDXVerifier.TrustedParams memory trustedParams
        ) = AzureTDXTestData.getTestData();

        // Set trusted params
        vm.prank(owner);
        verifier.setTrustedParams(0, trustedParams);

        // Get the expected instance address from userData
        address expectedInstanceAddr = address(bytes20(verifyParams.attestationDocument.userData));

        // Register instance
        verifier.registerInstance(0, verifyParams);

        // Verify instance was registered (instances mapping returns bool)
        assertTrue(verifier.instances(expectedInstanceAddr), "instance should be registered");

        // Verify using the isInstanceRegistered helper
        assertTrue(
            verifier.isInstanceRegistered(expectedInstanceAddr),
            "isInstanceRegistered should return true"
        );
    }
}
