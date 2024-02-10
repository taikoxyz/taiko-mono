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

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/governance/utils/IVotesUpgradeable.sol";
import "./MerkleClaimable.sol";

/// @title ERC20Airdrop
/// Contract for managing Taiko token airdrop for eligible users
contract ERC20Airdrop is MerkleClaimable {
    address public token;
    address public vault;
    uint256[48] private __gap;

    function init(
        uint64 _claimStarts,
        uint64 _claimEnds,
        bytes32 _merkleRoot,
        address _token,
        address _vault
    )
        external
        initializer
    {
        __Essential_init();
        _setConfig(_claimStarts, _claimEnds, _merkleRoot);

        token = _token;
        vault = _vault;
    }

    function _claimWithData(bytes calldata data, bytes memory extraData) internal override {
        (address user, uint256 amount) = abi.decode(data, (address, uint256));

        // Transfer the token first
        IERC20(token).transferFrom(vault, user, amount);

        if (extraData.length > 0) {
            // Delegate the voting power to delegatee.
            // Note that the signature (v,r,s) may not correspond to the user address,
            // but since the data is provided by Taiko backend, it's not an issue even if
            // client can change the data to call delegateBySig for another user.
            (address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) =
                abi.decode(extraData, (address, uint256, uint256, uint8, bytes32, bytes32));
            IVotesUpgradeable(token).delegateBySig(delegatee, nonce, expiry, v, r, s);
        }
    }
}
