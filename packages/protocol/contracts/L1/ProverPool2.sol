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
    uint32 public constant SLASH_POINTS = 9500; // basis points

    uint256 public totalStaked;
    uint256 public totalWeight;

    error CAPACITY_INCORRECT();
    error NOT_ENOUGH_BALANCE();
    error CANNOT_BE_PREFERRED();

    struct Staker {
        uint256 amount;
        uint256 numSlots;
        // If type(uint256).max = signals prover can prove all of the blocks
        // Then gets into the preferredProver (if he is also the max prover)
        uint256 maxNumSlots; // Max capacity if someone else's unstake would
            // increase a prover's slot count
        uint256 unstakedAt;
        uint16 rewardPerGas;
    }

    // Temporary staker who could jump in as a new prover
    // when someone unstakes and we need to fill their slots
    // - until the 'weight-based-owner' claims them (!)
    // So we basically don't increase anyone's slots unintentionally
    address preferredProver;

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
        if (maxCapacity > NUM_SLOTS && (maxCapacity != type(uint256).max)) {
            revert CAPACITY_INCORRECT();
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

    function unstake() external {
        address staker = msg.sender;

        totalWeight -= getWeight(staker);
        stakers[staker].unstakedAt = block.timestamp;
        totalStaked -= stakers[staker].amount;

        // Exchange unstaked slots with the preferredProver
        // Auto-claim adjustment
        uint256 replacedSlots;
        for (uint256 slotIdx = 0; slotIdx < NUM_SLOTS; slotIdx++) {
            address current = slots[slotIdx];
            if (current == staker) {
                slots[slotIdx] = preferredProver;
                replacedSlots++;
            }
        }
        // Someone (later) who's weight allows to actually claim
        // the slots will do that later from preferredProver.
        stakers[preferredProver].numSlots += replacedSlots;
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

    // preferredProver is the one who can (theoretically) prove all
    // the blocks and also the most staked TKO. He will be assigned
    // with the slots which will have no 'owner' (until claimed)
    // when someone unstakes
    function claimPreferredProverStatus(address staker) external {
        if (
            stakers[staker].maxNumSlots != type(uint256).max
                || stakers[preferredProver].amount >= stakers[staker].amount
                || stakers[staker].unstakedAt != 0
        ) {
            revert CANNOT_BE_PREFERRED();
        }
        preferredProver = staker;
    }

    function slashProver(address slashed) external {
        stakers[slashed].amount =
            stakers[slashed].amount * SLASH_POINTS / 10_000;
    }

    function withdraw(address staker) public {
        require(stakers[staker].unstakedAt + EXIT_PERIOD >= block.timestamp);
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
