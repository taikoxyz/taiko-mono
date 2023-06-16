// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../common/AddressResolver.sol";
import { EssentialContract } from "../common/EssentialContract.sol";
import { TaikoToken } from "./TaikoToken.sol";

contract TaikoProverPool is EssentialContract {

    struct Prover {
        address proverAddress;
        // Number of staked TKO - the higher amount the higher chance to picked up as a prover but
        // also the higher proportion
        uint256 stakedTokens;
        // Number of rewards given
        uint256 rewards;
        // Health score shows how many times a prover was slashed. (10_000 means 100%)
        uint256 healthScore;
        // Basically this is the 'exit criteria'
        uint256 lastBlockTsToBeProven; // -> equals to 'MAX_EXIT_COOLDOWN'
        // Entering with capacity 0 means 'unlimited'
        uint32 capacity;
        // Actual 'ongoing-proving' blocks
        uint32 numAssignedBlocks;
        // Prover sets it. The smaller it is, the higher the odds of selection.
        // 0.5 till 2 in basis points. So 200 means 2, 50 means 0.5
        uint8 feeMultiplier;
    }

    // Might worth to consider a CrudKeySet ? Because we need to query them to always maintain the top32 ?
    mapping(address => Prover) public provers;
    // The biggest challenge is keeping track of the top 32 provers. Problem is we cannot only allow
    // 32 provers to enter into our pool because bots might fill it up very quickly with garbage. So we need
    // a pool where everybody (or kind of everbody) could be there as a 'waiting room' and then selecting the top 32
    // which list need to be refreshed in 5 scenarios:
        // 1. When somebody entered into the pool
        // 2. When somebody adjusted their fee multiplier
        // 3. When somebody adjusted their staked TKOs
        // 4. When someone exiting the pool
        // 5. When someone is slashed
    // Maintain the top 32 provers
    address[32] public topProvers;

    // Block to prover
    mapping(uint256 blockId => address prover) public blockIdToProver;

    // How many TKO needed at least to start entering the pool. Prevent flood.
    uint256 public constant MIN_TKO_AMOUNT = 100_000 * 1e8; // 100K TKO

    // How many provers all in all we have, together with the 'waiting room'
    uint16 public proversInPool;

    // How many unique provers can enter into the pool (does not mean they are the top32, but all in all with waiting room)
    uint16 public maxPoolSize;

    uint8 public constant MIN_MULTIPLIER = 49; // Cheaper check if >49
    uint8 public constant MAX_MULTIPLIER = 201; // Cheaper check if < 201

    uint256[100] private __gap;
    
    event ProverEntered(address prover, uint256 amount, uint256 feeMultiplier, uint64 capacity);
    event ProverExited(address prover);
    
    modifier onlyProver() {
        require(provers[msg.sender].proverAddress != address(0), "Only provers can call this function");
        _;
    }

    modifier onlyProtocol() {
        require(AddressResolver(this).resolve("taiko", false) != msg.sender, "Only provers can call this function");
        _;
    }
    
    /**
     * Initialize the rollup.
     *
     * @param _addressManager The AddressManager address.
     */
    function init(
        address _addressManager,
        uint16 _maxPoolSize
    )
        external
        initializer
    {
        EssentialContract._init(_addressManager);
        maxPoolSize = _maxPoolSize;
    }

    // Provers can enter the pool but a big challenge is not to allow people entering into the pool below X TKO
    // because it could flood the protocol. Allow e.g.: 300 provers to enter, and maintain a list of best 32 (?)
    function enterProverPool(uint256 amount, uint256 feeMultiplier, uint32 capacity) external nonReentrant {
        if (amount > MIN_TKO_AMOUNT) {
            if(proversInPool == maxPoolSize) revert("Pool is full");

            if(provers[msg.sender].proverAddress != address(0)) revert("Prover already exist");

            if (feeMultiplier > MAX_MULTIPLIER || feeMultiplier < MIN_MULTIPLIER) revert("Multiplier invalid");

            TaikoToken(AddressResolver(this).resolve("taiko_token", false)).burn(
                msg.sender, amount
            );

            provers[msg.sender] = Prover(
                msg.sender,
                amount,
                0,
                10_000,
                feeMultiplier,
                0,
                capacity,
                0
            );
        }
        else {
            revert("Cannot enter below minimum");
        }
        // Might affect top32
        rearrangeTop32();
        emit ProverEntered(msg.sender, amount, feeMultiplier, capacity);
    }

    function stakeMoreTokens(uint256 amount) external {
        require(amount > 0, "Must stake a positive amount of tokens");
        require(provers[msg.sender].proverAddress != address(0), "Prover should exist");
        
        provers[msg.sender].stakedTokens += amount;
        
        // Might affect top32
        rearrangeTop32();
    }

    function adjustFeeMultiplier(uint8 newFeeMultiplier) external onlyProver {
        require(newFeeMultiplier > MAX_MULTIPLIER || newFeeMultiplier < MIN_MULTIPLIER, "Fee multiplier must be between 1/2 and 2");
        
        provers[msg.sender].feeMultiplier = newFeeMultiplier;
        // Might affect top32
        rearrangeTop32();
    }

    function adjustCapacity(uint32 newCapacity) external onlyProver {
        provers[msg.sender].capacity = newCapacity;
        // Might affect top32
        rearrangeTop32();
    }

    function withdrawRewards(uint64 amount) external nonReentrant {
        uint256 balance = provers[msg.sender].rewards;

        if (balance < amount) revert("Insufficient tokens");

        unchecked {
            provers[msg.sender].rewards -= amount;
        }

        TaikoToken(AddressResolver(this).resolve("taiko_token", false)).mint(
            msg.sender, amount
        );
    }
    
    function exit() external onlyProver {
        address proverAddress = msg.sender;
        Prover storage prover = provers[proverAddress];
        
        require(prover.proverAddress != address(0), "Prover does not exist");
        
        uint256 lastBlockTsToBeProven = prover.lastBlockTsToBeProven;
        // + 100 is needed, because the lastBlockTsToBeProven block might not be verified yet so do not
        // yet know if we need to slash the prover or not
        require(block.timestamp >= lastBlockTsToBeProven + 100, "Prover needs to still submit proof(s)");

        // Reimburse rewards and staked TKO
        TaikoToken(AddressResolver(this).resolve("taiko_token", false)).mint(
            msg.sender, prover.rewards + prover.stakedTokens
        );
        
        delete provers[proverAddress];

        // Also delete from topProvers something like:
        uint256 idx = getTopProverArrayId(msg.sender);

        topProvers[idx] = address(0); 
        
        // Might affect top32
        rearrangeTop32();

        emit ProverExited(proverAddress);
    }

    function pickRandomProver(uint256 randomNumber, uint256 blockId) external returns (address) {
        // Obviously exchange it with some more logic, taking weight into consideration, etc.
        address winner = topProvers[randomNumber % 32];
        return blockIdToProver[blockId] = winner;
    }

    function getProver(uint256 blockId) external view returns (address) {
        return blockIdToProver[blockId];
    }

    function slash(address prover) external onlyProtocol {
        // Call comes from protocol - prover missed the deadline
        Prover memory slashedProver = provers[prover];

        // Decrease health score by 5%
        slashedProver.healthScore -= (slashedProver.healthScore * 500) / 10_000;
        // Decrease deposit by 5%
        slashedProver.stakedTokens -= (slashedProver.stakedTokens * 500) / 10_000;
        // Might affect top32
        rearrangeTop32();
    }
    
    function rearrangeTop32() internal {
        // We need to call this in 5 scenarios:
        // 1. When somebody entered into the pool
        // 2. When somebody adjusted their fee multiplier
        // 3. When somebody adjusted their staked TKOs
        // 4. When someone exiting the pool
        // 5. When someone is slashed
    }

    function getTopProverArrayId(address prover) internal view returns (uint256) {
        for (uint256 i = 0; i < topProvers.length; i++) {
            if (topProvers[i] == prover) {
                return i;
            }
        }
        revert("Address not found");
    }
}