// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface BadgeMigration {
    /// @notice Start a migration for a badge
    /// @param _badgeTokenId The badge token ID (s1)
    /// @dev Not all badges are eligible for migration at the same time
    /// @dev Defines a cooldown for the migration to be complete
    /// @dev the cooldown is lesser the higher the Pass Tier
    function startMigration(uint256 _badgeTokenId) external;

    /// @notice Tamper (alter) the chances during a migration
    /// @param _pinkOrPurple true for pink, false for purple
    /// @dev Can be called only during an active migration
    /// @dev Implements a cooldown before allowing to re-tamper
    /// @dev The max tamper amount is determined by Pass Tier
    function tamperMigration(bool _pinkOrPurple) external;

    /// @notice End a migration
    /// @dev Can be called only during an active migration, after the cooldown is over
    /// @dev The final color is determined randomly, and affected by the tamper amounts
    function endMigration() external;

    /// @notice Get the max tamper amount for the calling user and their Trail tier
    /// @return The maximum tamper amount
    function getMaximumTampers() external view returns (uint256);
}

interface TrailRewardVault {
    /// @notice Claim rewards
    /// @param _experience The experience amount
    /// @param _signature The signature to verify
    /// @dev The user is the _msgSender()
    function claimRewards(uint256 _experience, bytes memory _signature) external;

    /// @notice Internal method to mint s2 badges from claimRewards
    /// @param _account The account to mint the badge to
    /// @param _tokenId The badge token ID
    /// @param _experience The experience amount
    /// @param _signature The signature to verify
    function _mintBadge(
        address _account,
        uint256 _tokenId,
        uint256 _experience,
        bytes memory _signature
    )
        external;

    /// @notice Check if an account can claim rewards
    /// @param _account The account to check
    function canClaim(address _account) external view returns (bool);
}

interface TrailRaffle {
    /// @notice Create a new raffle
    /// @param _startTime The start time of the raffle
    /// @param _endTime The end time of the raffle
    /// @param _erc20TokenRewards array of erc20 addresses for rewards
    /// @param _erc20TokenAmounts array of erc20 amounts for rewards
    /// @param _erc721TokenRewards array of erc721 addresses for rewards
    /// @param _erc721TokenIds array of erc721 token ids for rewards
    /// @param _erc1155TokenRewards array of erc1155 addresses for rewards
    /// @param _erc1155TokenIds array of erc1155 token ids for rewards
    /// @param _erc1155TokenAmounts array of erc1155 token amounts for rewards
    /// @dev The raffle will be settled after the end time
    /// @dev Each Pass Tier multiplies the raffle chances
    function createRaffle(
        uint256 _startTime,
        uint256 _endTime,
        address[] calldata _erc20TokenRewards,
        uint256[] calldata _erc20TokenAmounts,
        address[] calldata _erc721TokenRewards,
        uint256[] calldata _erc721TokenIds,
        address[] calldata _erc1155TokenRewards,
        uint256[] calldata _erc1155TokenIds,
        uint256[] calldata _erc1155TokenAmounts
    )
        external
        returns (uint256 _raffleId);

    /// @notice Check if a raffle is settled
    /// @param _raffleId The raffle ID
    /// @return Whether the raffle is settled
    function isRaffleSettled(uint256 _raffleId) external view returns (bool);

    /// @notice Settle a raffle
    /// @param _raffleId The raffle ID
    /// @dev Can be called only after the end time of the raffle
    function settleRaffle(uint256 _raffleId) external;

    /// @notice Check if an account is a winner in a raffle
    /// @param _account The account to check
    /// @param _raffleId The raffle ID
    /// @return Whether the account is a winner
    function isWinner(address _account, uint256 _raffleId) external view returns (bool);

    /// @notice Claim the rewards of a raffle
    /// @param _raffleId The raffle ID
    /// @dev Can be called once, only after the raffle is settled, and only by the winner
    function claimRaffleRewards(uint256 _raffleId) external;

    /// @notice Get the amount of participations in raffles for an account
    /// @param _account The account to check
    /// @dev Determined by a user's TrailPass Tier
    function getRaffleParticipations(address _account) external view returns (uint256);
}

interface TrailPass {
    /// @notice Purchase a Trail Pass
    /// @param _tier The tier of the Trail Pass
    /// @dev The price is determined by the tier
    /// @dev The tier is determined by the amount of participations in raffles
    /// @dev The tier also increases the max amount of tampering during a migration
    function purchaseTrailPass(uint256 _tier) external payable;

    /// @notice Upgrade a Trail Pass
    /// @param _tier The tier of the Trail Pass
    /// @dev The price is determined by the tier, and substracted from the existing trail pass price
    function upgradeTrailPass(uint256 _tier) external payable;

    /// @notice Check if an account has a Trail Pass, any
    /// @param _account The account to check
    function hasTrailPass(address _account) external view returns (bool);

    /// @notice Check if an account has a Trail Pass, specific tier
    /// @param _account The account to check
    function hasTrailPass(address _account, uint256 _tier) external view returns (bool);

    /// @notice Check if an account has one of the Trail Passes (OR)
    /// @param _account The account to check
    /// @param _tiers The tiers to check, OR
    function hasTrailPass(
        address _account,
        uint256[] calldata _tiers
    )
        external
        view
        returns (bool);

    /// @notice Get the tier of a Trail Pass
    /// @param _account The account to check
    function getTrailPass(address _account) external view returns (uint256 _tier);
}
