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

    event Withdrawn(address indexed addr, uint256 amount);
    event Exited(address indexed addr, uint256 amount);
    event Slashed(address indexed addr, uint256 amount);
    event Staked(
        address indexed addr,
        uint256 amount,
        uint16 rewardPerGas,
        uint16 currentCapacity
    );

    error PP_CAPACITY_INCORRECT();
    error PP_CANNOT_BE_PREFERRED();
    error PP_STAKE_AMOUNT_TOO_LOW();

    struct Staker {
        uint256 amount;
        uint256 numSlots;
        // If type(uint256).max = signals prover can prove all of the blocks
        // Then gets into the preferredProver (if he is also the max prover)
        uint256 maxNumSlots; // Max capacity if someone else's unstake would
            // increase a prover's slot count
            // This is basically a theoretical edge of capacity
        uint256 unstakedAt;
        uint16 rewardPerGas;
    }

    // Temporary staker who could jump in as a new prover
    // when someone unstakes and we need to fill their slots
    // - until the 'weight-based-owner' claims them (!)
    // So we basically don't increase anyone's slots unintentionally
    address preferredProver;

    mapping(uint256 slot => address) public slots;
    mapping(address staker => Staker) public stakers;

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
        bytes32 rand =
            keccak256(abi.encode(blockhash(block.number - 1), blockId));
        uint256 slot_idx = uint256(rand) % NUM_SLOTS;
        // If the rewardPerGas changes infrequently, just also store it in the
        // slot
        // so we can keep doing 2 SLOAD.
        prover = slots[slot_idx];
        rewardPerGas = stakers[prover].rewardPerGas;
    }

    function stake(
        uint256 amount,
        uint16 rewardPerGas,
        uint16 maxCapacity
    )
        external
    {
        if (maxCapacity > NUM_SLOTS && (maxCapacity != type(uint256).max)) {
            revert PP_CAPACITY_INCORRECT();
        }
        address staker = msg.sender;

        TaikoToken(resolve("taiko_token", false)).burn(staker, amount);

        // If the staker was unstaking, first revert the unstaking
        if (stakers[staker].unstakedAt > 0) {
            totalStaked += stakers[staker].amount;
        }

        if (staker == preferredProver && maxCapacity != type(uint256).max) {
            preferredProver = address(0);
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
            if (
                (
                    current == address(0)
                        && stakers[staker].numSlots < getNumClaimableSlots(staker)
                ) || stakers[current].numSlots > getNumClaimableSlots(current)
            ) {
                claimSlot(staker, slotIdx);
            }
        }

        emit Staked(staker, amount, rewardPerGas, maxCapacity);
    }

    function unstake() external {
        address staker = msg.sender;

        if (staker == preferredProver) {
            preferredProver = address(0);
        }

        totalWeight -= getWeight(staker);
        stakers[staker].unstakedAt = block.timestamp;
        totalStaked -= stakers[staker].amount;

        // Exchange unstaked slots with the preferredProver
        // Auto-claim adjustment
        for (uint256 slotIdx = 0; slotIdx < NUM_SLOTS; slotIdx++) {
            address current = slots[slotIdx];
            if (current == staker) {
                slots[slotIdx] = preferredProver;
                // Someone (later) who's weight allows to actually claim
                // the slots will do that later from preferredProver.
                stakers[preferredProver].numSlots++;
            }
        }

        emit Exited(staker, stakers[staker].amount);
    }

    // For now leave as is to not breaking interfaces
    function releaseProver(address addr) external pure {
        return;
    }

    function setMaxNumSlots(address staker, uint16 maxNumSlots) external {
        // This is basically equal to set 'how much percent' maximum
        // a prover is capable to process.
        // Since the GasPerSecond of the chain is known, the prover can know
        // this number off-chain. This is what ir represents.

        if (stakers[staker].numSlots > maxNumSlots) {
            revert PP_CAPACITY_INCORRECT();
        }
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
            revert PP_CANNOT_BE_PREFERRED();
        }
        preferredProver = staker;
    }

    function slashProver(address slashed) external {
        uint256 newBalance = stakers[slashed].amount * SLASH_POINTS / 10_000;

        emit Slashed(slashed, (stakers[slashed].amount - newBalance));

        stakers[slashed].amount = newBalance;
    }

    function withdraw(address staker) public {
        require(stakers[staker].unstakedAt + EXIT_PERIOD >= block.timestamp);
        stakers[staker].unstakedAt = 0;
        TaikoToken(resolve("taiko_token", false)).mint(
            staker, stakers[staker].amount
        );

        emit Withdrawn(staker, stakers[staker].amount);
        stakers[staker].amount = 0;
    }

    function getWeight(address staker) public view returns (uint256) {
        // It shall never be the case that it reverts - only in tests
        // because rewardPerGas is much lower amount than the staked amount
        // but in such case happens, just to avoid divisioin by zero
        if (
            stakers[staker].amount
                < (stakers[staker].rewardPerGas * stakers[staker].rewardPerGas)
        ) {
            revert PP_STAKE_AMOUNT_TOO_LOW();
        }

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
        if (staker == address(0)) {
            return 0;
        }
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
