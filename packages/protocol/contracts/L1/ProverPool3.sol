//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

// author: Brecht
contract ProverPool3 {
    uint256 public constant NUM_SLOTS = 128;
    uint256 public constant EXIT_PERIOD = 1 weeks;

    uint256 public totalStaked;

    struct Staker {
        uint256 amount;
        uint256 numSlots;
        uint256 unstakedAt;
    }

    mapping(uint256 slot => address) slots;
    mapping(address staker => Staker) stakers;

    function assignProver(
        uint64 blockId,
        uint32 feePerGas
    )
        external
        view
        returns (address prover, uint32 rewardPerGas)
    {
        bytes32 rand = keccak256(abi.encode(blockId));
        uint256 slot_idx = uint256(rand) % NUM_SLOTS;
        return (slots[slot_idx], feePerGas);
    }

    function stake(address staker, uint256 amount) external {
        if (stakers[staker].unstakedAt > 0) {
            totalStaked += stakers[staker].amount;
        }
        totalStaked += amount;
        stakers[staker].amount += amount;
        stakers[staker].unstakedAt = 0;
    }

    function unstake(address staker) external {
        stakers[staker].unstakedAt = block.timestamp;
        totalStaked -= stakers[staker].amount;
    }

    function claimSlot(address staker, uint256 slotIdx) external {
        require(staker != address(0));
        // We only allow claiming slots from other stakers if they have more
        // than their minimum amount
        // of slots claimed. We allow anyone to claim slots to take into
        // rounding errors.
        // TODO: currently this would allow people to battle over these slot, so
        // just let the top staker claim these
        require(isSlotClaimable(slotIdx));
        if (stakers[slots[slotIdx]].numSlots > 0) {
            stakers[slots[slotIdx]].numSlots -= 1;
        }
        slots[slotIdx] = staker;
        stakers[staker].numSlots += 1;
    }

    function slashProver(address staker) external {
        uint256 amountToSlash = 123_456;
        amountToSlash = stakers[staker].amount > amountToSlash
            ? amountToSlash
            : stakers[staker].amount;
        stakers[staker].amount -= amountToSlash;
    }

    function withdraw(address staker) public {
        require(stakers[staker].unstakedAt + EXIT_PERIOD >= block.timestamp);
        stakers[staker].amount = 0;
        stakers[staker].unstakedAt = 0;
    }

    function getNumClaimableSlots(address staker)
        public
        view
        returns (uint256)
    {
        if (stakers[staker].unstakedAt == 0) {
            return (stakers[staker].amount * NUM_SLOTS) / totalStaked;
        } else {
            return 0;
        }
    }

    function isSlotClaimable(uint256 slotIdx) public view returns (bool) {
        address currentStaker = slots[slotIdx];
        if (currentStaker == address(0)) {
            return true;
        } else {
            return stakers[currentStaker].numSlots
                > getNumClaimableSlots(currentStaker);
        }
    }

    // HELPER FUNCTION ONLY!!!
    // ONLY HERE SO STAKERS CAN JUST GO TO ETHERSCAN AND FIND ALL SLOTS THEY
    // COULD CLAIM!!!
    // NOT USED IN THE SMART CONTRACT ITSELF!!!
    function getClaimableSlots() public view returns (uint256[] memory) {
        uint256[] memory claimableSlots = new uint[](NUM_SLOTS);
        uint256 numClaimableSlots = 0;
        for (uint256 i; i < NUM_SLOTS; i++) {
            if (isSlotClaimable(i)) {
                claimableSlots[numClaimableSlots] = i;
                numClaimableSlots += 1;
            }
        }
        // Overwrite the length
        assembly {
            mstore(claimableSlots, numClaimableSlots)
        }
        return claimableSlots;
    }
}
