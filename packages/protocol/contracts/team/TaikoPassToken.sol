// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TaikoPassToken is ERC20 {
    uint256 public constant LAST_MINT_BLOCK = 50_000_000;
    uint256 public lastMintBlock;

    error UNABLE_TO_MINT();
    error UNSUPPORTED();

    constructor() ERC20("Taiko Proposer Fairmint Pass", "TPFP") { }

    function mint() public {
        uint256 amount = nextMintAmount();
        if (amount == 0 || block.number <= lastMintBlock) {
            revert UNABLE_TO_MINT();
        }

        lastMintBlock = block.number;
        _mint(block.coinbase, amount);
    }

    function nextMintAmount() public view returns (uint256) {
        if (block.number >= LAST_MINT_BLOCK) return 0;
        return (4 ether) * (LAST_MINT_BLOCK - block.number) / LAST_MINT_BLOCK;
    }
}
