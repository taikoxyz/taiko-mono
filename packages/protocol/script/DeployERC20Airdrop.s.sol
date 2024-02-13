// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/
//
//   Email: security@taiko.xyz
//   Website: https://taiko.xyz
//   GitHub: https://github.com/taikoxyz
//   Discord: https://discord.gg/taikoxyz
//   Twitter: https://twitter.com/taikoxyz
//   Blog: https://mirror.xyz/labs.taiko.eth
//   Youtube: https://www.youtube.com/@taikoxyz

pragma solidity 0.8.24;

import "../test/DeployCapability.sol";
import "forge-std/console2.sol";

import "../contracts/team/airdrop/ERC20Airdrop.sol";

// @KorbinianK , @2manslkh
// As written also in the tests the workflow shall be the following (checklist):
// 1. Is Vault - which will store the tokens - deployed ?
// 2. Is (bridged) TKO token existing ?
// 3. Is ERC20Airdrop contract is 'approved operator' on the TKO token ?
// 4. Proof (merkle root) and minting window related variabes (start, end) set ?
// If YES the answer to all above, we can go live with airdrop, which is like:
// 1. User go to website. -> For sake of simplicity he is eligible
// 2. User wants to mint, but first site established the delegateHash (user sets a delegatee) which
// the user signs
// 3. Backend retrieves the proof and together with signature in the input params, user fires away
// the claimAndDelegate() transaction.
contract DeployERC20Airdrop is DeployCapability {
    uint256 public deployerPrivKey = vm.envUint("PRIVATE_KEY"); // Owner of the ERC20 airdrop
    // contract
    address public bridgedTko = vm.envAddress("BRIDGED_TKO_ADDRESS");
    address public vaultAddress = vm.envAddress("VAULT_ADDRESS");

    function setUp() external { }

    function run() external {
        require(deployerPrivKey != 0, "invalid deployer priv key");
        require(vaultAddress != address(0), "invalid vault address");
        require(bridgedTko != address(0), "invalid bridged tko address");

        vm.startBroadcast(deployerPrivKey);

        ERC20Airdrop(
            deployProxy({
                name: "ERC20Airdrop",
                impl: address(new ERC20Airdrop()),
                data: abi.encodeCall(ERC20Airdrop.init, (0, 0, bytes32(0), bridgedTko, vaultAddress))
            })
        );

        /// @dev Once the Vault is done, we need to have a contract in that vault through which we
        /// authorize the airdrop contract to be a spender of the vault.
        // example:
        //
        // SOME_VAULT_CONTRACT(vaultAddress).approveAirdropContractAsSpender(
        //     bridgedTko, address(ERC20Airdrop), 50_000_000_000e18
        // );

        vm.stopBroadcast();
    }
}
