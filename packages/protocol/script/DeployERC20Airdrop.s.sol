// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../test/DeployCapability.sol";
import { ERC20Airdrop } from "../contracts/team/airdrop/ERC20Airdrop.sol";

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

import { MockAddressManager } from "../test/mocks/MockAddressManager.sol";
import { MockERC20Vault } from "../test/mocks/MockERC20Vault.sol";
import { BridgedERC20 } from "../contracts/tokenvault/BridgedERC20.sol";

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

    /// @notice Address of the vault where tokens will be stored
    /// @dev The vault address must be valid for the deployment to proceed
    address public vaultAddress = vm.envAddress("VAULT_ADDRESS");

    address public airdropContractAddress;

    /// @notice Prepares the contract setup for deployment
    /// @dev This function checks for the presence of the bridgedTko and vaultAddress.
    /// If absent in a testnet environment, it deploys new instances.
    function setUp() external { }

    function testEnvOnly() internal {
        MockAddressManager addressManager;
        if (block.chainid != 167_001) {
            // Assuming non-mainnet chain ids indicate a testnet

            if (vaultAddress == address(0)) {
                MockERC20Vault newVault = MockERC20Vault(
                    deployProxy({
                        name: "vault",
                        impl: address(new MockERC20Vault()),
                        data: abi.encodeCall(MockERC20Vault.init, ())
                    })
                );
                vaultAddress = address(newVault);

                // This will allow the vault to mint the bridged token
                addressManager = new MockAddressManager(vaultAddress);
            }

            if (bridgedTko == address(0)) {
                // Deploy address manager

                BridgedERC20 newToken = BridgedERC20(
                    deployProxy({
                        name: "tko",
                        impl: address(new BridgedERC20()),
                        data: abi.encodeCall(
                            BridgedERC20.init,
                            (
                                address(0),
                                address(addressManager),
                                address(1), // srcToken
                                100,
                                18,
                                "TKO",
                                "Taiko Token"
                            )
                            )
                    })
                );
                bridgedTko = address(newToken);
            }
        }
    }

    function postDeployment() internal {
        console.log("=== Post deployment ===");
        if (block.chainid != 167_001) {
            // Assuming non-mainnet chain ids indicate a testnet
            // Mint (AKA transfer) to the vault. This step on mainnet will be done by Taiko Labs.
            // For testing on A6 the important thing is: HAVE tokens in this vault!
            MockERC20Vault(vaultAddress).mintToVault(bridgedTko, vaultAddress);
            MockERC20Vault(vaultAddress).approveAirdropContract(
                bridgedTko, airdropContractAddress, 50_000_000_000e18
            );
        }
    }

    /// @notice Runs the deployment script to deploy the ERC20 Airdrop contract
    /// @dev Requires the deployer private key and addresses for the vault and bridged TKO token to
    /// be valid
    /// The function deploys the ERC20Airdrop contract and sets up necessary approvals.
    function run() external {
        // Start transaction broadcasting using the deployer's private key
        vm.startBroadcast(deployerPrivKey);

        testEnvOnly();

        require(deployerPrivKey != 0, "invalid deployer priv key");
        require(vaultAddress != address(0), "invalid vault address");
        require(bridgedTko != address(0), "invalid bridged tko address");

        // Deploy the ERC20Airdrop contract with initial parameters
        ERC20Airdrop airdropContract = ERC20Airdrop(
            deployProxy({
                name: "ERC20Airdrop",
                impl: address(new ERC20Airdrop()),
                data: abi.encodeCall(
                    ERC20Airdrop.init, (address(0), 0, 0, bytes32(0), bridgedTko, vaultAddress)
                    )
            })
        );

        airdropContractAddress = address(airdropContract);

        postDeployment();
        vm.stopBroadcast();
    }
}
