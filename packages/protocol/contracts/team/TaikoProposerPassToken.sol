// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TaikoProposerPassToken is ERC20 {
    uint256 public constant END_BLOCK = 50_000_000;
    uint256 public minDifficulty = type(uint256).max;
    uint256 private __lastBlockMinted;

    error UNABLE_TO_MINT();
    error UNSUPPORTED();

    constructor() ERC20("Taiko Proposer Pass Token", "TKOPP") {
        _mint(msg.sender, 0); // Initial supply set to 0
    }

    function mint() public {
        if (
            block.number > END_BLOCK || block.prevrandao >= minDifficulty
                || block.number <= __lastBlockMinted
        ) {
            revert UNABLE_TO_MINT();
        }

        minDifficulty = block.prevrandao;
        __lastBlockMinted = block.number;

        _mint(block.coinbase, nextMintAmount());
    }

    function nextMintAmount() public view returns (uint256) {
        if (block.number >= END_BLOCK) return 0;
        return (32 ether) * (END_BLOCK - block.number) / END_BLOCK;
    }
}
