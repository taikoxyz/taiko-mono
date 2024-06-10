// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title BasedOrBoosted
 * @dev This contract allows users to choose between two movements: Based or Boosted.
 */
contract BasedOrBoosted {
    /**
     * @dev Enum representing the possible movements.
     */
    enum Movement {
        NEUTRAL,
        BASED,
        BOOSTED
    }

    /**
     * @dev Mapping from user addresses to their chosen movement.
     */
    mapping(address => Movement) public isBasedOrBoosted;

    /**
     * @dev Event emitted when a user chooses the Based movement.
     * @param user The address of the user who chose Based.
     */
    event ChoseBased(address indexed user);

    /**
     * @dev Event emitted when a user chooses the Boosted movement.
     * @param user The address of the user who chose Boosted.
     */
    event ChoseBoosted(address indexed user);

    /**
     * @dev Allows a user to choose the Based movement. Can only be called if the user is Neutral.
     * Emits a ChoseBased event.
     */
    function chooseBased() public {
        require(isBasedOrBoosted[msg.sender] == Movement.NEUTRAL, "Movement already chosen");
        isBasedOrBoosted[msg.sender] = Movement.BASED;
        emit ChoseBased(msg.sender);
    }

    /**
     * @dev Allows a user to choose the Boosted movement. Can only be called if the user is Neutral.
     * Emits a ChoseBoosted event.
     */
    function chooseBoosted() public {
        require(isBasedOrBoosted[msg.sender] == Movement.NEUTRAL, "Movement already chosen");
        isBasedOrBoosted[msg.sender] = Movement.BOOSTED;
        emit ChoseBoosted(msg.sender);
    }
}
