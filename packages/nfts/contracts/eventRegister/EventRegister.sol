// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24.0;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract EventRegister is AccessControl {
    // Define a role identifier for event managers
    bytes32 public constant EVENT_MANAGER_ROLE = keccak256("EVENT_MANAGER_ROLE");

    // Struct to represent an event or season
    struct Event {
        uint256 id;
        string name;
        bool exists;
        bool registrationOpen;
    }

    // Mapping from event ID to Event details
    mapping(uint256 => Event) public events;

    // Mapping from event ID to a mapping of user addresses to registration status
    mapping(uint256 => mapping(address => bool)) public registrations;

    // Event emitted when a new event is created
    event EventCreated(uint256 id, string name);

    // Event emitted when a user registers for an event
    event Registered(address indexed registrant, uint256 eventId);

    // Event emitted when registrations are opened for an event
    event RegistrationOpened(uint256 eventId);

    // Event emitted when registrations are closed for an event
    event RegistrationClosed(uint256 eventId);

    // Counter for event IDs
    uint256 private nextEventId;

    /**
     * @dev Constructor that sets up the default admin role.
     * The deployer of the contract is granted the default admin role.
     */
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    /**
     * @dev Grants EVENT_MANAGER_ROLE to a specified account.
     * Can only be called by an account with DEFAULT_ADMIN_ROLE.
     * @param account The address to grant the role to.
     */
    function grantEventManagerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(EVENT_MANAGER_ROLE, account);
    }

    /**
     * @dev Revokes EVENT_MANAGER_ROLE from a specified account.
     * Can only be called by an account with DEFAULT_ADMIN_ROLE.
     * @param account The address to revoke the role from.
     */
    function revokeEventManagerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(EVENT_MANAGER_ROLE, account);
    }

    /**
     * @dev Creates a new event.
     * Only accounts with EVENT_MANAGER_ROLE can call this function.
     * @param _name The name of the event.
     */
    function createEvent(string memory _name) external onlyRole(EVENT_MANAGER_ROLE) {
        uint256 eventId = nextEventId;
        events[eventId] = Event({ id: eventId, name: _name, exists: true, registrationOpen: true });
        emit EventCreated(eventId, _name);
        emit RegistrationOpened(eventId); // Emit event indicating registrations are open
        nextEventId++;
    }

    /**
     * @dev Opens registrations for a specific event.
     * Only accounts with EVENT_MANAGER_ROLE can call this function.
     * @param _eventId The ID of the event to open registrations for.
     */
    function openRegistration(uint256 _eventId) external onlyRole(EVENT_MANAGER_ROLE) {
        require(events[_eventId].exists, "Event does not exist");
        require(!events[_eventId].registrationOpen, "Registrations are already open for this event");

        events[_eventId].registrationOpen = true;
        emit RegistrationOpened(_eventId);
    }

    /**
     * @dev Closes registrations for a specific event.
     * Only accounts with EVENT_MANAGER_ROLE can call this function.
     * @param _eventId The ID of the event to close registrations for.
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
     * @dev Allows a user to register for a specific event.
     * @param _eventId The ID of the event to register for.
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
     * @dev Retrieves all registered event IDs for a user.
     * @param _user The address of the user.
     * @return An array of event IDs the user has registered for.
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
     * @dev Retrieves details of a specific event.
     * @param _eventId The ID of the event.
     * @return id The event ID.
     * @return name The name of the event.
     * @return registrationOpen_ Indicates if registrations are open for this event.
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
