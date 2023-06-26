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

    uint256 public totalStaked;
    uint256 public totalWeight;

    struct Staker {
        uint256 amount;
        uint256 numSlots;
        uint256 maxNumSlots; //Max capacity if someone else's unstake would
            // increase a prover's slot count
        uint256 unstakedAt;
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

    function stake(uint256 amount, uint16 rewardPerGas) external {
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
        totalWeight += getWeight(staker);
    }

    function unstake() external {
        address staker = msg.sender;

        totalWeight -= getWeight(staker);
        stakers[staker].unstakedAt = block.timestamp;
        totalStaked -= stakers[staker].amount;
    }

    function setRewardPerGas(uint16 rewardPerGas) external {
        address staker = msg.sender;
        totalWeight -= getWeight(staker);
        stakers[staker].rewardPerGas = rewardPerGas;
        totalWeight += getWeight(staker);
    }

    function setMaxNumSlots(address staker, uint16 maxNumSlots) external {
        // This is basically equal to set 'how many blocks' maximum
        // a prover is capable to process if weighting would allow him/her
        // theoretically to prove more (if pool changes e.g.: by unstaking)

        require(stakers[staker].numSlots <= maxNumSlots);
        stakers[staker].maxNumSlots = maxNumSlots;
    }

    function claimSlot(address staker, uint256 slotIdx) external {
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

contract ProxiedProverPool3 is Proxied, ProverPool3 { }
