// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface ITaikoL2 {
    function parentTimestamp() external view returns (uint64);
}

/// @title ProposerFairmintPass
/// @dev A token that can be fair-minted by block proposers (block.coinbase) if this block is
/// proposed no early than 12 seconds after its parent block.
/// This token then can be used for rewarding block proposers for Taiko L2's liveness.
/// @custom:security-contact security@taiko.xyz
/// TODO (dnaiel): we probably want to mint NFTs rather than ERC20 tokens.
contract ProposerFairmintPass is ERC20 {
    address public constant TAIKO_L2 = 0x1670080000000000000000000000000000010001;
    uint256 public constant LAST_MINT_BLOCK = 50_000_000;
    uint256 public constant MIN_BLOCK_TIME = 12 seconds;

    uint64 public lastMintBlock;

    error MINT_DISALLOWED();

    constructor() ERC20("Taiko Proposer Fairmint Pass", "TPFP") { }

    function mint() public {
        uint256 amount = nextMintAmount();

        if (
            amount == 0 || block.number <= lastMintBlock
                || block.timestamp < ITaikoL2(TAIKO_L2).parentTimestamp() + MIN_BLOCK_TIME
        ) {
            revert MINT_DISALLOWED();
        }

        lastMintBlock = uint64(block.number);
        _mint(block.coinbase, amount);
    }

    function nextMintAmount() public view returns (uint256) {
        if (block.number >= LAST_MINT_BLOCK) return 0;
        return (4 ether) * (LAST_MINT_BLOCK - block.number) / LAST_MINT_BLOCK;
    }
}
