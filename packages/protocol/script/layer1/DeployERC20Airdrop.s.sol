// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "script/BaseScript.sol";
import "src/layer1/team/airdrop/ERC20Airdrop.sol";

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
contract DeployERC20Airdrop is BaseScript {
    address public bridgedTaikoToken = vm.envAddress("BRIDGED_TAIKO_TOKEN");
    address public erc20Vault = vm.envAddress("ERC20_VAULT");

    function run() external broadcast {
        require(erc20Vault != address(0), "invalid erc20 vault address");
        require(bridgedTaikoToken != address(0), "invalid bridged tko address");

        deploy({
            name: "ERC20Airdrop",
            impl: address(new ERC20Airdrop()),
            data: abi.encodeCall(
                ERC20Airdrop.init, (address(0), 0, 0, bytes32(0), bridgedTaikoToken, erc20Vault)
            )
        });

        /// @dev Once the Vault is done, we need to have a contract in that vault through which we
        /// authorize the airdrop contract to be a spender of the vault.
        // example:
        //
        // SOME_VAULT_CONTRACT(erc20Vault).approveAirdropContractAsSpender(
        //     bridgedTaikoToken, address(ERC20Airdrop), 50_000_000_000e18
        // );
    }
}
