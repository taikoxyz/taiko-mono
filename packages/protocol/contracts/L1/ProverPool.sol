//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../common/AddressResolver.sol";
import { EssentialContract } from "../common/EssentialContract.sol";
import { TaikoToken } from "./TaikoToken.sol";
import { Proxied } from "../common/Proxied.sol";

interface IProverPool {
    function assignProver(
        uint64 blockId,
        uint32 feePerGas
    )
        external
        returns (address prover, uint32 rewardPerGas);

    function releaseProver(address prover) external;
    function slashProver(address prover) external;

    // TODO: we need to add this as well.
    function getAvailableCapacity() external returns (uint256);
}

contract ProverPool is EssentialContract, IProverPool {
    // TODO: Dani, this data structure shall be read only in assignProvers and
    // only
    // be modified by the stake() function. (+ setter/adjustment/exit functions)
    // TODO: remove this
    struct Staker {
        uint8 id; // [0-31]
        address prover;
    }
    // TODO:
    // // I think it is redundand here and not needed because it is used in
    // ProverExitRequest
    // uint64 exitTs;
    // // I think it is redundent here, not needed because Prover struct keeps
    // track of it
    // uint32 amount; // unit is 10^8, this means a max of
    // // 429496729500000000 tokens, 2.3283%  of total supply
    // // I think it is redundent here, not needed because Prover struct keeps
    // track of it
    // uint16 rewardPerGas; // expected rewardPerGas
    // // I think it is redundent here, not needed because Prover struct keeps
    // track of it
    // uint16 capacity; // maximum capacity (parallel blocks)

    // Then we use a fixed size byte array to represnet the top 32 provers.
    // For each prover, we only need to keep its amount, and rewardPerGas,
    // together they takes 32+32=64 bits, or 8 bytes.

    // This is 1/4 slot
    // TODO: Dani, this structure should hold all information required to
    // dynamically calculate the weight of the top 32 provers and select one
    // based on a random number.
    struct Prover {
        uint32 amount; // this value will change when we slash the prover
        uint16 rewardPerGas;
        uint16 currentCapacity;
    }

    struct Exit {
        uint64 requestedAt;
        uint32 amount;
    }

    // TODO: change to id => address mapping
    mapping(uint8 id => Staker) public stakers;
    // This way we can keep track of a 'queue' who is currently exiting
    // or exited already.exits
    mapping(address prover => Exit) public exits;
    mapping(address prover => uint8 id) public proverToId;

    // Keeping track of the 'lowest barrier to entry' by checking who is on the
    // bottom of the top32 list.
    // Top32: Pure staked TKO based !

    // TODO: the minimum stake is dynamic, it should be smallest `amount`
    // value
    // in the `provers` list. No need to keep track of this as state variables.
    // To @Daniel: Agreed, commenting out for now only to see changes
    // properly.exits
    // uint256 public minimumStake;
    // uint8 minimumStakerId;

    // TODO: what is this?
    // If we dont keep track outomatically on state level the minimumStake and
    // id
    // it is not needed at all.
    //uint8 currentIdIdx;

    // uint16 capacity; // if we add this, we should use a bytes array
    // instead of Prover array below. The capacity must be greater than a
    // threshold.

    // TODO: this wont work
    Prover[32] public provers; // 32/4 = 8 slots

    uint256 public constant EXIT_PERIOD = 1 weeks;
    uint256 public constant SLASH_AMOUNT_IN_BP = 500; // means 5% if 10_000 is
        // 100%

    uint256[100] private __gap;

    event ProverEntered(
        address prover, uint32 amount, uint16 rewardPerGas, uint16 capacity
    );

    event ProverStakedMoreTokens(
        address prover, uint32 amount, uint32 totalStaked
    );

    event ProverChangedExpectedReward(address prover, uint16 newReward);

    event ProverAdjustedCapacity(address prover, uint16 newCapacity);

    event ProverExitRequested(address prover, uint64 timestamp);

    event ProverExitRequestReverted(address prover, uint64 timestamp);

    event ProverExited(address prover, uint64 timestamp);

    event ProverSlashed(address prover, uint32 newBalance);

    modifier onlyProtocol() {
        require(
            AddressResolver(this).resolve("taiko", false) != msg.sender,
            "Only Taiko L1 can call this function"
        );
        _;
    }

    // TODO: rename to onlyValidProver?
    modifier onlyProver(address prover) {
        require(
            stakers[proverToId[prover]].prover != address(0),
            "Only provers can call this function" // TODO: incorrect
        );
        _;
    }

    /**
     * Initialize the rollup.
     *
     * @param _addressManager The AddressManager address.
     */
    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    // A demo how to optimize the assignProver by using only 8 slots. It's still
    // a lot of slots tough.
    function assignProver(
        uint64 blockId,
        uint32 feePerGas
    )
        external
        returns (address prover, uint32 rewardPerGas)
    {
        // readjust each prover's rate
        uint256[32] memory weights;
        uint256 totalWeight;

        for (uint8 i; i < provers.length; ++i) {
            // TODO: if a prover's current capacity is 0, the weight shall be 0.
            // DONE.
            weights[i] = _calcWeight(i, provers[i], feePerGas);
            if (weights[i] == 0) break;
            totalWeight += weights[i];
        }

        if (totalWeight == 0) {
            // QUESTION: shall we reward open proofs more?
            // Do not think so, because most efficient provers might try to
            // create such situations (time / off-chain calc) where this is
            // the case and then they could get 2x more.
            return (address(0), 0);
        }

        // Determine prover idx
        bytes32 rand =
            keccak256(abi.encode(blockhash(block.number - 1), blockId));
        uint8 id = _pickProver({
            weights: weights,
            totalWeight: totalWeight,
            rand: rand
        });

        Staker memory data = stakers[id];

        provers[id].currentCapacity--;
        return (data.prover, provers[id].rewardPerGas);
    }

    // Increases the capacity of the prover
    function releaseProver(address prover) external onlyProtocol {
        if (
            stakers[proverToId[prover]].prover != address(0)
                && provers[proverToId[prover]].currentCapacity < type(uint16).max
        ) {
            provers[proverToId[prover]].currentCapacity++;
        }
    }

    function slashProver(address prover)
        external
        onlyProtocol
        onlyProver(prover) // TODO: should also allow slash exiting provers
    {
        // We need to determine if the prover is an exiting prover or not
        uint32 afterSlash;
        if (
            exits[prover].requestedAt != 0
                && exits[prover].requestedAt + EXIT_PERIOD < block.timestamp
        ) {
            // Exiting prover get's slashed
            uint32 currentStaked = exits[prover].amount;

            afterSlash = uint32(
                currentStaked * uint256(10_000 - SLASH_AMOUNT_IN_BP) / 10_000
            );

            exits[prover].amount = afterSlash;
        } else {
            uint32 currentStaked = provers[proverToId[_msgSender()]].amount;

            afterSlash = uint32(
                currentStaked * uint256(10_000 - SLASH_AMOUNT_IN_BP) / 10_000
            );

            provers[proverToId[_msgSender()]].amount = afterSlash;
            //stakers[proverToId[_msgSender()]].amount = afterSlash;
        }

        emit ProverSlashed(prover, afterSlash);
    }

    // @Daniel's comment: Adjust the staking. Users can use this funciton to
    // stake, re-stake, exit,
    // and change parameters.
    // @Dani: Most prob. not for exit and modify, because it would require extra
    // logic and cases. Let handle
    // modification in a separate function
    function stake(
        uint32 totalAmount,
        uint16 rewardPerGas,
        uint16 capacity
    )
        external
        nonReentrant
    {
        // TODO(daniel): assuming we have 1 block per second, and each proof
        // takes
        // 1 hour to generate, then we need a total capacity of 3600 at least
        // across
        // 32 provers, that means each prover's minimul capacity is 3600/32=112.
        // We shall
        // Yep, make sense !
        require(capacity >= 100, "too small");

        (uint8 id, uint32 minimumStake) = _determineLowestStaker();

        // Cannot enter the pool below the minimum
        require(minimumStake < totalAmount, "Cannot enter below minimum");
        require(rewardPerGas > 0, "Cannot be less than 1");
        // Prover shall always be sender and in case of
        // lending/cooperation/delegate
        // it shall be done off-chain or at least outside of this pool contract.
        address prover = _msgSender();
        // The list of 32 is not full yet so kind of everybody can enter into
        // the pool

        // TODO: the logics should look like this:
        // 1. Find the smallest staker in the top staker list, using its current
        // amount
        //    value, not the original amount value, say this is Alice.
        // 2. Compare if the new staker, Bob's amount is bigger than
        // Alice's. We may even compare
        //    capacity (not sure how the math work), note that if Bob is already
        // on the exiting list, we shall reuse its tokens locked there.
        // Yes, we comply with this 1st and 2nd checks with:
        // require(minimumStake < totalAmount, "Cannot enter below minimum");
        // 3. If Bob is perferred, we change Alice's status to `exiting` (as if
        // Alice herself requested to exit)
        // 4. We replace Alice with Bob in the `provers` list.

        Staker memory replacedProver = stakers[id];
        if (replacedProver.prover != address(0)) {
            // The list is full so we need to kick someone out

            // 1. So we put Alice into the exit queue:
            // QUESTION: what if the prover has requested to exit already?
            exits[replacedProver.prover] =
                Exit(uint64(block.timestamp), provers[id].amount);

            // 2. Rewrite it's place with the new one
            stakers[id] =
                Staker(id, prover /*, 0, totalAmount, rewardPerGas, capacity*/ );
            provers[id] = Prover(totalAmount, rewardPerGas, capacity);
            proverToId[prover] = id;
        } else {
            // Not all the 32 spots are filled up so we can easily assign
            stakers[id] =
                Staker(id, prover /*, 0, totalAmount, rewardPerGas, capacity*/ );
            provers[id] = Prover(totalAmount, rewardPerGas, capacity);
            proverToId[prover] = id;
        }

        TaikoToken(AddressResolver(this).resolve("taiko_token", false)).burn(
            prover, totalAmount * 10e8
        );

        emit ProverEntered(prover, totalAmount, rewardPerGas, capacity);
    }

    function getAvailableCapacity()
        external
        view
        returns (uint256 totalCapacity)
    {
        Prover[32] memory mProvers = provers;

        // Find the index to insert the new staker based on their balance
        for (uint8 i = 0; i < mProvers.length; i++) {
            totalCapacity += mProvers[i].currentCapacity;
        }
    }

    // TODO: Dani, most of the following methods can be implemented in the
    // `stake` function. We do not need one tx per staking parameter.
    // The `stake` function shall serve the purpose of specifying a final
    // staking plan.
    // Well i dont think i agree here. It would be much more gas intensive and
    // confusing on the client side as well.
    // https://github.com/taikoxyz/taiko-mono/pull/14010#discussion_r1234568661

    // Increases the staked amount (decrease will be with exit())
    function stakeMoreTokens(uint32 amount) external onlyProver(_msgSender()) {
        require(amount > 0, "Must stake a positive amount of tokens");

        provers[proverToId[_msgSender()]].amount += amount;
        //stakers[proverToId[_msgSender()]].amount += amount; -> removed as seen
        // redundant

        emit ProverStakedMoreTokens(
            _msgSender(), amount, provers[proverToId[_msgSender()]].amount
        );
    }

    // Adjusts the expected reward per gas
    function adjustExpectedRewardPerGas(uint16 newRewardPerGas)
        external
        onlyProver(_msgSender()) // TODO: do not use `_msgSender()` here or use
            // it everywhere
    {
        require(newRewardPerGas > 0, "Must be above 0");

        provers[proverToId[_msgSender()]].rewardPerGas = newRewardPerGas;
        //stakers[proverToId[_msgSender()]].rewardPerGas = newRewardPerGas; ->
        // removed as seen redundant

        emit ProverChangedExpectedReward(_msgSender(), newRewardPerGas);
    }

    // Sets new capacity
    function adjustCapacity(uint16 newCapacity)
        external
        onlyProver(_msgSender())
    {
        require(newCapacity > 0, "Must be above 0");

        provers[proverToId[_msgSender()]].currentCapacity = newCapacity;
        // stakers[proverToId[_msgSender()]].capacity = newCapacity; -> removed
        // as seen redundant

        emit ProverAdjustedCapacity(_msgSender(), newCapacity);
    }

    // Can 'toggle' exit status
    function requestExit() external onlyProver(_msgSender()) {
        uint64 timestamp = uint64(block.timestamp);

        uint8 idToZero = proverToId[_msgSender()];
        // Same happens as when Bob replaces Alice except it's place is filled
        // with 0s
        exits[_msgSender()] = Exit(timestamp, provers[idToZero].amount);

        // 2. Rewrite it's place with empty place
        delete stakers[idToZero];
        provers[idToZero] = Prover(0, 0, 0);
        delete proverToId[_msgSender()];

        emit ProverExitRequested(_msgSender(), timestamp);
    }

    function exit() external {
        // We need to have this prover 'flagged' as an exiting prover
        require(
            exits[_msgSender()].requestedAt != 0
                && exits[_msgSender()].requestedAt + EXIT_PERIOD < block.timestamp,
            "Cannot yet exit"
        );

        // Reimburse rewards and staked TKO
        // TODO: we should mint (amount * 2^32) as each unit is a 2^32
        // tokens, not 1 wei
        // QUESTION: Not 10^8 ?

        TaikoToken(AddressResolver(this).resolve("taiko_token", false)).mint(
            msg.sender, exits[_msgSender()].amount * 10e8
        );

        // Delete mapping
        delete exits[_msgSender()];

        emit ProverExited(_msgSender(), uint64(block.timestamp));
    }

    // Determine the minimum required TKO to be in the pool
    function lowestStakedAmountToEnter()
        external
        view
        returns (uint32 minStakeRequired)
    {
        (, minStakeRequired) = _determineLowestStaker();

        return (minStakeRequired + 1);
    }

    // The weight is dynamic based on fee per gas.
    function _calcWeight(
        uint8 id,
        Prover memory prover,
        uint32 feePerGas
    )
        private
        view
        returns (uint256)
    {
        // If prover's capacity is 0
        // set his/her weight to 0
        if (provers[id].currentCapacity == 0) {
            return 0;
        }
        // Just a demo that the weight depends on the current fee per gas,
        // the prover's expected fee per gas, as well as the staking amount
        return (uint256(prover.amount) * feePerGas * feePerGas)
            / prover.rewardPerGas / prover.rewardPerGas;
    }

    // Determine staker with the least amount of token staked
    function _determineLowestStaker()
        private
        view
        returns (uint8 stakerId, uint32 minStake)
    {
        Prover[32] memory mProvers = provers;
        stakerId = 0;
        minStake = mProvers[0].amount;

        // Find the index to insert the new staker based on their balance
        for (uint8 i = 1; i < mProvers.length; i++) {
            if (mProvers[i].amount < minStake) {
                stakerId = i;
                minStake = mProvers[i].amount;

                if (minStake == 0) {
                    // This is an 'empty spot'
                    return (stakerId, minStake);
                }
            }
        }
    }

    // Pick a random prover
    function _pickProver(
        uint256[32] memory weights,
        uint256 totalWeight,
        bytes32 rand
    )
        private
        pure
        returns (uint8 i)
    {
        uint256 r = uint256(rand) % totalWeight;
        uint256 z;
        while (z < r && i < 32) {
            z += weights[++i];
        }
    }
}

contract ProxiedProverPool is Proxied, ProverPool { }
