// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../test/DeployCapability.sol";
import { ERC20Airdrop } from "../contracts/team/airdrop/ERC20Airdrop.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// @KorbinianK , @2manslkh
// As written also in the tests the workflow shall be the following (checklist):
// 1. Is Vault - which will store the tokens - deployed ?
// 2. Is (bridged) TKO token existing ?
// 3. Is ERC20Airdrop contract is 'approved operator' on the TKO token ?
// 4. Proof (merkle root) and minting window related variables (start, end) set ?
// If YES the answer to all above, we can go live with airdrop, which is like:
// 1. User go to website. -> For sake of simplicity he is eligible
// 2. User wants to mint, but first site established the delegateHash (user sets a delegatee) which
// the user signs
// 3. Backend retrieves the proof and together with signature in the input params, user fires away
// the claimAndDelegate() transaction.

import { MockERC20 } from "../test/mocks/MockERC20.sol";

/// @title Deployment script for ERC20 Airdrop
/// @notice This contract is designed to deploy an ERC20 Airdrop contract
/// @dev The contract uses environment variables to configure the deployment and sets up necessary
/// permissions.

contract DeployERC20Airdrop is DeployCapability {
    /// @notice Private key of the deployer used for transactions
    /// @dev This private key must be set in the environment variables and is critical for contract
    /// deployment
    uint256 public deployerPrivKey = vm.envUint("PRIVATE_KEY");

    /// @notice Address of the bridged TKO token
    /// @dev The address must be valid and the TKO token must already exist for the deployment to
    /// proceed
    address public bridgedTko = vm.envAddress("BRIDGED_TKO_ADDRESS");

    uint256 public airdropStartTime = vm.envUint("AIRDROP_START_TIME");

    uint256 public airdropEndTime = vm.envUint("AIRDROP_END_TIME");

    /// @notice Private key of the deployer used for transactions
    /// @dev This private key must be set in the environment variables and is critical for contract
    /// deployment
    bytes32 public merkleRoot = vm.envBytes32("AIRDROP_MERKLE_ROOT");
    ERC20Airdrop airdropContract;

    /// @notice Prepares the contract setup for deployment
    /// @dev This function checks for the presence of the bridgedTko and vaultAddress.
    /// If absent in a testnet environment, it deploys new instances.
    function setUp() external { }

    function testEnvOnly() internal {
        // Testnet Environment
        if (block.chainid != 167_000) {
            console.log("=== Testnet Environment ===");
            // Deploy a mock ERC20 token
            console.log("[TEST] Deploying mock TKO token");
            MockERC20 mockERC20 = new MockERC20();
            // Replace bridgedTko with the mock ERC20 token
            console.log("[TEST] TKO token set as", address(mockERC20));
            bridgedTko = address(mockERC20);
        }
    }

    function postDeployment() internal {
        console.log("=== Post deployment ===");

        if (block.chainid != 167_000) {
            // If testnet, mint 50 Million tokens to the vault
            console.log("[TEST] Minting 50 Million tokens to the airdrop contract");
            MockERC20(bridgedTko).mint(address(airdropContract), 50_000_000_000e18);
            console.log("[INFO] Setting Airdrop Config");
            console.log(" - Airdrop Start Time:", airdropStartTime);
            console.log(" - Airdrop End Time:", airdropEndTime);
            console.log(" - Merkle Root:");
            console.logBytes32(merkleRoot);

            // Set Merkle Proof, Start Time and End Time
            airdropContract.setConfig(uint64(airdropStartTime), uint64(airdropEndTime), merkleRoot);
        } else {
            // Transfer ownership to 0xf8ff2AF0DC1D5BA4811f22aCb02936A1529fd2Be
            // This address will have ownership of the airdrop contract which will have the ability
            // to set the airdrop start and end time, and the merkle root with
            // setConfig(_claimStart, _claimEnd, _merkleRoot).
            console.log(
                "[INFO] Transferring Ownership of Airdrop Contract to 0xf8ff2AF0DC1D5BA4811f22aCb02936A1529fd2Be"
            );
            airdropContract.transferOwnership(0xf8ff2AF0DC1D5BA4811f22aCb02936A1529fd2Be);
        }

        // Print Deployment Addresses
        console.log("[INFO] Deployment Addresses");
        console.log("[INFO] Airdrop Contract:", address(airdropContract));
        console.log("[INFO] TKO:", bridgedTko);
    }

    /// @notice Runs the deployment script to deploy the ERC20 Airdrop contract
    /// @dev Requires the deployer private key and addresses for the vault and bridged TKO token to
    /// be valid
    /// The function deploys the ERC20Airdrop contract and sets up necessary approvals.
    function run() external {
        // Start transaction broadcasting using the deployer's private key
        vm.startBroadcast(deployerPrivKey);

        // Deploys Mock TKO
        testEnvOnly();

        require(deployerPrivKey != 0, "invalid deployer priv key");
        console.log("[INFO] Deploying from", vm.addr(deployerPrivKey));

        require(bridgedTko != address(0), "invalid bridged tko address");

        // Deploy the ERC20Airdrop contract with initial parameters
        airdropContract = ERC20Airdrop(
            deployProxy({
                name: "ERC20Airdrop",
                impl: address(new ERC20Airdrop()),
                data: abi.encodeCall(
                    ERC20Airdrop.init,
                    (
                        address(0), // Owner
                        uint64(airdropStartTime), // Airdrop Start Time
                        uint64(airdropEndTime), // Airdrop End Time
                        merkleRoot, // Merkle Root
                        IERC20(bridgedTko) // TKO Token
                    )
                )
            })
        );

        postDeployment();
        vm.stopBroadcast();
    }
}
