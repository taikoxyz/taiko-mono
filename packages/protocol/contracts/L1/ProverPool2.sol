//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../common/AddressResolver.sol";
import { EssentialContract } from "../common/EssentialContract.sol";
import { IProverPool } from "./IProverPool.sol";
import { TaikoToken } from "./TaikoToken.sol";
import { Proxied } from "../common/Proxied.sol";

// author: Brecht
contract ProverPool2 is EssentialContract {
    uint256 public constant NUM_SLOTS = 128;
    uint256 public constant EXIT_PERIOD = 1 weeks;
    uint32 public constant SLASH_POINTS = 500; // basis points

    uint256 public totalStaked;
    uint256 public totalWeight;

    error CAPACITY_TOO_HIGH();
    error NOT_ENOUGH_BALANCE();

    struct Staker {
        uint256 amount;
        uint256 numSlots;
        uint256 maxNumSlots; //Max capacity if someone else's unstake would
            // increase a prover's slot count
        uint256 unstakedAt;
        uint256 unstakedAmount;
        uint16 rewardPerGas;
    }

    mapping(uint256 slot => address) slots;
    mapping(address staker => Staker) stakers;

    uint256[100] private __gap;

    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    function assignProver(
        uint64 blockId,
        uint32 feePerGas
    )
        external
        view
        returns (address prover, uint32 rewardPerGas)
    {
        if (totalStaked == 0) {
            return (address(0), 0);
        }

        bytes32 rand = keccak256(abi.encode(blockId));
        uint256 slot_idx = uint256(rand) % NUM_SLOTS;
        // If the rewardPerGas changes infrequently, just also store it in the
        // slot
        // so we can keep doing 1 SLOAD.
        prover = slots[slot_idx];
        feePerGas = stakers[prover].rewardPerGas;
    }

    function stake(
        uint256 amount,
        uint16 rewardPerGas,
        uint16 maxCapacity
    )
        external
    {
        if (maxCapacity > NUM_SLOTS) {
            revert CAPACITY_TOO_HIGH();
        }
        address staker = msg.sender;
        // If the staker was unstaking, first revert the unstaking
        if (stakers[staker].unstakedAt > 0) {
            totalStaked += stakers[staker].amount;
        }

        totalWeight -= getWeight(staker);
        totalStaked += amount;
        stakers[staker].amount += amount;
        stakers[staker].unstakedAt = 0;
        stakers[staker].rewardPerGas = rewardPerGas;
        stakers[staker].maxNumSlots = maxCapacity;
        totalWeight += getWeight(staker);

        // Auto-claim adjustment
        for (uint256 slotIdx = 0; slotIdx < NUM_SLOTS; slotIdx++) {
            address current = slots[slotIdx];
            if (stakers[current].numSlots > getNumClaimableSlots(current)) {
                claimSlot(staker, slotIdx);
            }
        }
    }

    function unstake(uint256 unstakedAmount) external {
        if (stakers[msg.sender].amount < unstakedAmount) {
            revert NOT_ENOUGH_BALANCE();
        }
        address staker = msg.sender;

        totalWeight -= getWeight(staker);
        stakers[staker].unstakedAt = block.timestamp;
        stakers[staker].unstakedAmount += unstakedAmount;
        stakers[staker].amount -= unstakedAmount;
        totalStaked -= unstakedAmount;
        totalWeight += getWeight(staker);
    }

    function setRewardPerGas(uint16 rewardPerGas) external {
        address staker = msg.sender;
        totalWeight -= getWeight(staker);
        stakers[staker].rewardPerGas = rewardPerGas;
        totalWeight += getWeight(staker);
    }

    function setMaxNumSlots(address staker, uint16 maxNumSlots) external {
        // This is basically equal to set 'how much percent' maximum
        // a prover is capable to process.
        // Since the GasPerSecond of the chain is known, the prover can know
        // this number off-chain. This is what ir represents.

        require(stakers[staker].numSlots <= maxNumSlots);
        stakers[staker].maxNumSlots = maxNumSlots;
    }

    function claimSlot(address staker, uint256 slotIdx) public {
        // We only allow claiming slots from other stakers if they have more
        // than their number of claimable slots.
        // We allow anyone to claim slots to take into rounding errors.
        // We allow setting the staker to 0x0 to make the proving open.
        // TODO: currently this would allow people to battle over these slot, so
        // just let the top staker claim these
        require(isSlotClaimable(slotIdx));
        if (stakers[slots[slotIdx]].numSlots > 0) {
            stakers[slots[slotIdx]].numSlots -= 1;
        }
        slots[slotIdx] = staker;
        if (staker != address(0)) {
            stakers[staker].numSlots += 1;
            require(stakers[staker].numSlots <= stakers[staker].maxNumSlots);
        }
    }

    function slashProver(address slashed) external {
        Staker memory staker = stakers[slashed];

        uint256 slashableAmount = staker.unstakedAt > 0
            && block.timestamp <= staker.unstakedAt + EXIT_PERIOD
            ? staker.amount + staker.unstakedAmount
            : staker.amount;

        uint256 amountToSlash;

        if (slashableAmount > 0) {
            amountToSlash = slashableAmount * SLASH_POINTS / 10_000;
            // make sure we can slash even if  totalAmount is as small as 1
            if (amountToSlash == 0) amountToSlash = 1;
        }

        if (amountToSlash == 0) {
            // do nothing
        } else if (amountToSlash <= staker.unstakedAmount) {
            staker.unstakedAmount -= amountToSlash;
        } else {
            uint256 _additional = amountToSlash - staker.unstakedAmount;
            staker.unstakedAmount = 0;

            if (staker.amount > _additional) {
                staker.amount -= _additional;
            } else {
                staker.amount = 0;
            }
        }
        //Write back memory var to storage
        stakers[slashed] = staker;
    }

    function withdraw(address staker) public {
        require(stakers[staker].unstakedAt + EXIT_PERIOD >= block.timestamp);
        stakers[staker].unstakedAmount = 0;
        stakers[staker].unstakedAt = 0;
    }

    function getWeight(address staker) public view returns (uint256) {
        if (
            stakers[staker].unstakedAt == 0 && stakers[staker].amount != 0
                && stakers[staker].rewardPerGas != 0
        ) {
            return stakers[staker].amount / stakers[staker].rewardPerGas
                / stakers[staker].rewardPerGas;
        } else {
            return 0;
        }
    }

    function getNumClaimableSlots(address staker)
        public
        view
        returns (uint256)
    {
        // Cap the number of slots to maxNumSlots
        uint256 numSlotsFromWeight = getWeight(staker) * NUM_SLOTS / totalWeight;
        if (numSlotsFromWeight > stakers[staker].maxNumSlots) {
            return stakers[staker].maxNumSlots;
        } else {
            return numSlotsFromWeight;
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

contract ProxiedProverPool2 is Proxied, ProverPool2 { }
