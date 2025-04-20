// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "urc/src/ISlasher.sol";
import "src/shared/common/EssentialContract.sol";
import "../iface/IPreconfCommitment.sol";

contract PreconfSlasher is EssentialContract, ISlasher {
    uint256[50] private __gap;

    constructor() EssentialContract(address(0)) { }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @inheritdoc ISlasher
    function slash(
        Delegation calldata delegation,
        Commitment calldata commitment,
        bytes calldata evidence,
        address challenger
    )
        external
        returns (uint256 slashAmountWei)
    { // TODO
    }

    /// @inheritdoc ISlasher
    function slashFromOptIn(
        Commitment calldata commitment,
        bytes calldata evidence,
        address challenger
    )
        external
        returns (uint256 slashAmountWei)
    {
        // TODO
    }
}
