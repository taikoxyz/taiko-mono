// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24.0;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title EventRegister
 * @notice A contract that allows authorized managers to create events, manage user registrations,
 *         and track user participation using role-based access control.
 * @dev Utilizes OpenZeppelin's AccessControl for role management. The contract does not hold any
 * Ether.
 */
contract EventRegister is AccessControl {
    /**
     * @dev The role identifier for event managers. This role allows accounts to create events
     *      and manage registrations.
     */
    bytes32 public constant EVENT_MANAGER_ROLE = keccak256("EVENT_MANAGER_ROLE");

    /**
     * @dev Represents an event with its associated details.
     */
    struct Event {
        ///< Unique identifier for the event.
        uint256 id;
        ///< Name of the event.
        string name;
        ///< Flag indicating whether the event exists.
        bool exists;
        ///< Flag indicating whether registrations are open for the event.
        bool registrationOpen;
    }

    /**
     * @dev Mapping from event ID to Event details.
     */
    mapping(uint256 => Event) public events;

    /**
     * @dev Mapping from event ID to a mapping of user addresses to their registration status.
     *      Indicates whether a user has registered for a specific event.
     */
    mapping(uint256 => mapping(address => bool)) public registrations;

    /**
     * @dev Emitted when a new event is created.
     * @param id The unique identifier of the created event.
     * @param name The name of the created event.
     */
    event EventCreated(uint256 id, string name);

    /**
     * @dev Emitted when a user registers for an event.
     * @param registrant The address of the user who registered.
     * @param eventId The unique identifier of the event for which the user registered.
     */
    event Registered(address indexed registrant, uint256 eventId);

    /**
     * @dev Emitted when a user unregisters for an event.
     * @param registrant The address of the user who unregistered.
     * @param eventId The unique identifier of the event for which the user unregistered.
     */
    event Unregistered(address indexed registrant, uint256 eventId);

    /**
     * @dev Emitted when registrations are opened for an event.
     * @param eventId The unique identifier of the event whose registrations are opened.
     */
    event RegistrationOpened(uint256 eventId);

    /**
     * @dev Emitted when registrations are closed for an event.
     * @param eventId The unique identifier of the event whose registrations are closed.
     */
    event RegistrationClosed(uint256 eventId);

    /**
     * @dev Counter for assigning unique event IDs.
     */
    uint256 private nextEventId;

    /**
     * @notice Initializes the contract by granting the deployer the default admin role.
     * @dev The deployer of the contract is granted the DEFAULT_ADMIN_ROLE, allowing them to manage
     * roles.
     */
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(EVENT_MANAGER_ROLE, _msgSender());
    }

    /**
     * @notice Grants the EVENT_MANAGER_ROLE to a specified account.
     * @dev Only accounts with the DEFAULT_ADMIN_ROLE can call this function.
     * @param account The address to be granted the EVENT_MANAGER_ROLE.
     *
     * Requirements:
     *
     * - The caller must have the DEFAULT_ADMIN_ROLE.
     */
    function grantEventManagerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(EVENT_MANAGER_ROLE, account);
    }

    /**
     * @notice Revokes the EVENT_MANAGER_ROLE from a specified account.
     * @dev Only accounts with the DEFAULT_ADMIN_ROLE can call this function.
     * @param account The address from which the EVENT_MANAGER_ROLE will be revoked.
     *
     * Requirements:
     *
     * - The caller must have the DEFAULT_ADMIN_ROLE.
     */
    function revokeEventManagerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(EVENT_MANAGER_ROLE, account);
    }

    /**
     * @notice Creates a new event with the given name.
     * @dev Only accounts with the EVENT_MANAGER_ROLE can call this function.
     *      Emits EventCreated and RegistrationOpened events upon successful creation.
     * @param _name The name of the event to be created.
     *
     * Requirements:
     *
     * - The caller must have the EVENT_MANAGER_ROLE.
     */
    function createEvent(string memory _name) external onlyRole(EVENT_MANAGER_ROLE) {
        uint256 eventId = nextEventId;
        events[eventId] = Event({ id: eventId, name: _name, exists: true, registrationOpen: true });
        emit EventCreated(eventId, _name);
        emit RegistrationOpened(eventId); // Emit event indicating registrations are open
        nextEventId++;
    }

    /**
     * @notice Opens registrations for a specific event.
     * @dev Only accounts with the EVENT_MANAGER_ROLE can call this function.
     *      Emits a RegistrationOpened event upon successful operation.
     * @param _eventId The unique identifier of the event for which to open registrations.
     *
     * Requirements:
     *
     * - The event with `_eventId` must exist.
     * - Registrations for the event must currently be closed.
     * - The caller must have the EVENT_MANAGER_ROLE.
     */
    function openRegistration(uint256 _eventId) external onlyRole(EVENT_MANAGER_ROLE) {
        require(events[_eventId].exists, "Event does not exist");
        require(!events[_eventId].registrationOpen, "Registrations are already open for this event");

        events[_eventId].registrationOpen = true;
        emit RegistrationOpened(_eventId);
    }

    /**
     * @notice Closes registrations for a specific event.
     * @dev Only accounts with the EVENT_MANAGER_ROLE can call this function.
     *      Emits a RegistrationClosed event upon successful operation.
     * @param _eventId The unique identifier of the event for which to close registrations.
     *
     * Requirements:
     *
     * - The event with `_eventId` must exist.
     * - Registrations for the event must currently be open.
     * - The caller must have the EVENT_MANAGER_ROLE.
     */
    function closeRegistration(uint256 _eventId) external onlyRole(EVENT_MANAGER_ROLE) {
        require(events[_eventId].exists, "Event does not exist");
        require(
            events[_eventId].registrationOpen, "Registrations are already closed for this event"
        );

        events[_eventId].registrationOpen = false;
        emit RegistrationClosed(_eventId);
    }

    /**
     * @notice Allows a user to register for a specific event.
     * @dev Emits a Registered event upon successful registration.
     * @param _eventId The unique identifier of the event to register for.
     *
     * Requirements:
     *
     * - The event with `_eventId` must exist.
     * - Registrations for the event must be open.
     * - The caller must not have already registered for the event.
     */
    function register(uint256 _eventId) external {
        Event memory currentEvent = events[_eventId];
        require(currentEvent.exists, "Event does not exist");
        require(currentEvent.registrationOpen, "Registrations for this event are closed");
        require(!registrations[_eventId][msg.sender], "Already registered for this event");

        registrations[_eventId][msg.sender] = true;

        emit Registered(msg.sender, _eventId);
    }

    /**
     * @notice Allows the event manager to unregister a user from a specific event.
     * @dev Emits an Unregistered event upon successful un-registration.
     * @param _eventId The unique identifier of the event to unregister from.
     * @param _user The address of the user to unregister.
     *
     * Requirements:
     * - The event with `_eventId` must exist.
     * - Registrations for the event must be open.
     * - The user must be registered for the event.
     */
    function unregister(uint256 _eventId, address _user) external onlyRole(EVENT_MANAGER_ROLE) {
        Event memory currentEvent = events[_eventId];
        require(currentEvent.exists, "Event does not exist");
        require(currentEvent.registrationOpen, "Registrations for this event are closed");
        require(registrations[_eventId][_user], "Not registered for this event");

        registrations[_eventId][_user] = false;
        emit Unregistered(_user, _eventId);
    }

    /**
     * @notice Retrieves all event IDs for which a user has registered.
     * @dev Iterates through all existing events to compile a list of registrations.
     * @param _user The address of the user whose registrations are to be retrieved.
     * @return An array of event IDs that the user has registered for.
     *
     */
    function getRegisteredEvents(address _user) external view returns (uint256[] memory) {
        uint256[] memory temp = new uint256[](nextEventId);
        uint256 count = 0;

        for (uint256 i = 0; i < nextEventId; i++) {
            if (registrations[i][_user]) {
                temp[count] = i;
                count++;
            }
        }

        // Create a fixed-size array to return
        uint256[] memory registeredEvents = new uint256[](count);
        for (uint256 j = 0; j < count; j++) {
            registeredEvents[j] = temp[j];
        }

        return registeredEvents;
    }

    /**
     * @notice Retrieves the details of a specific event.
     * @dev Returns the event's ID, name, and registration status.
     * @param _eventId The unique identifier of the event to retrieve.
     * @return id The unique identifier of the event.
     * @return name The name of the event.
     * @return registrationOpen_ A boolean indicating whether registrations are open for the event.
     *
     * Requirements:
     *
     * - The event with `_eventId` must exist.
     */
    function getEvent(uint256 _eventId)
        external
        view
        returns (uint256 id, string memory name, bool registrationOpen_)
    {
        require(events[_eventId].exists, "Event does not exist");
        Event memory e = events[_eventId];
        return (e.id, e.name, e.registrationOpen);
    }
}
