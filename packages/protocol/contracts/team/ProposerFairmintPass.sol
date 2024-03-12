// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ProposerFairmintPass is ERC20 {
    uint256 public constant LAST_MINT_BLOCK = 50_000_000;
    uint64 public lastMintBlock;
    uint192 public minDifficulty;

    error UNABLE_TO_MINT();
    error UNSUPPORTED();
    error INVALID_SALT();

    constructor() ERC20("Taiko Proposer Fairmint Pass", "TPFP") {
        minDifficulty = type(uint192).max;
    }

    function mint(uint256 _salt) public {
        uint256 value = uint256(keccak256(abi.encode("MINT", _salt)));
        if (value >= minDifficulty) revert INVALID_SALT();

        uint256 amount = nextMintAmount();
        if (amount == 0 || block.number <= lastMintBlock) {
            revert UNABLE_TO_MINT();
        }

        lastMintBlock = uint64(block.number);
        _mint(block.coinbase, amount);
    }

    function _calcDifficulty(uint256 _oldDifficulty, uint256 _actualMiningTime, uint256 _expectedMiningTime)
        private
        pure
        returns (uint256 newDifficulty)
    {
        // To avoid floating point operations, we use multiplication before division
        return (oldDifficulty * actualMiningTime) / expectedMiningTime;
    }

    function nextMintAmount() public view returns (uint256) {
        if (block.number >= LAST_MINT_BLOCK) return 0;
        return (4 ether) * (LAST_MINT_BLOCK - block.number) / LAST_MINT_BLOCK;
    }
}
