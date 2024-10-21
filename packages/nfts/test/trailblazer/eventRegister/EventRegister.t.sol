// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import "../../../contracts/eventRegister/EventRegister.sol";

contract EventRegisterTest is Test {
    EventRegister public eventRegister;

    // Define test accounts
    address public owner = address(0x1);
    address public manager = address(0x2);
    address public user1 = address(0x3);
    address public user2 = address(0x4);

    // Define event details
    string public eventName1 = "Spring Season";
    string public eventName2 = "Summer Season";

    function setUp() public {
        // Deploy the contract as the owner
        vm.startPrank(owner);
        eventRegister = new EventRegister();
        vm.stopPrank();

        // Grant EVENT_MANAGER_ROLE to the manager
        vm.startPrank(owner);
        eventRegister.grantEventManagerRole(manager);
        vm.stopPrank();
    }

    /**
     * @notice Test that the deployer has the DEFAULT_ADMIN_ROLE.
     */
    function testDeployerHasAdminRole() public view {
        assertTrue(
            eventRegister.hasRole(eventRegister.DEFAULT_ADMIN_ROLE(), owner),
            "Owner should have DEFAULT_ADMIN_ROLE"
        );
    }

    /**
     * @notice Test that the manager has the EVENT_MANAGER_ROLE.
     */
    function testManagerHasEventManagerRole() public view {
        assertTrue(
            eventRegister.hasRole(eventRegister.EVENT_MANAGER_ROLE(), manager),
            "Manager should have EVENT_MANAGER_ROLE"
        );
    }

    /**
     * @notice Test that admin can grant EVENT_MANAGER_ROLE.
     */
    function testAdminCanGrantEventManagerRole() public {
        vm.startPrank(owner);
        eventRegister.grantEventManagerRole(user1);
        vm.stopPrank();

        assertTrue(
            eventRegister.hasRole(eventRegister.EVENT_MANAGER_ROLE(), user1),
            "User1 should have EVENT_MANAGER_ROLE"
        );
    }

    /**
     * @notice Test that admin can revoke EVENT_MANAGER_ROLE.
     */
    function testAdminCanRevokeEventManagerRole() public {
        vm.startPrank(owner);
        eventRegister.grantEventManagerRole(user1);
        assertTrue(
            eventRegister.hasRole(eventRegister.EVENT_MANAGER_ROLE(), user1),
            "User1 should have EVENT_MANAGER_ROLE"
        );

        eventRegister.revokeEventManagerRole(user1);
        vm.stopPrank();

        assertFalse(
            eventRegister.hasRole(eventRegister.EVENT_MANAGER_ROLE(), user1),
            "User1 should not have EVENT_MANAGER_ROLE"
        );
    }

    /**
     * @notice Test that only event managers can create events.
     */
    function testOnlyEventManagersCanCreateEvents() public {
        // Attempt to create event as non-manager
        vm.startPrank(user1);
        vm.expectRevert();
        eventRegister.createEvent(eventName1);
        vm.stopPrank();

        // Create event as manager
        vm.startPrank(manager);
        vm.expectEmit(true, false, false, true);
        emit EventRegister.EventCreated(0, eventName1);
        vm.expectEmit(false, false, false, true);
        emit EventRegister.RegistrationOpened(0);
        eventRegister.createEvent(eventName1);
        vm.stopPrank();

        // Verify event creation
        (uint256 id, string memory name, bool registrationOpen) = eventRegister.getEvent(0);
        assertEq(id, 0, "Event ID should be 0");
        assertEq(name, eventName1, "Event name should match");
        assertTrue(registrationOpen, "Registration should be open");
    }

    /**
     * @notice Test opening and closing registrations.
     */
    function testOpenAndCloseRegistrations() public {
        // Create an event first
        vm.startPrank(manager);
        eventRegister.createEvent(eventName1);
        vm.stopPrank();

        // Close registration
        vm.startPrank(manager);
        vm.expectEmit(false, false, false, true);
        emit EventRegister.RegistrationClosed(0);
        eventRegister.closeRegistration(0);
        vm.stopPrank();

        // Verify registration is closed
        (,, bool registrationOpen) = eventRegister.getEvent(0);
        assertFalse(registrationOpen, "Registration should be closed");

        // Attempt to register when closed
        vm.startPrank(user1);
        vm.expectRevert("Registrations for this event are closed");
        eventRegister.register(0);
        vm.stopPrank();

        // Re-open registration
        vm.startPrank(manager);
        vm.expectEmit(false, false, false, true);
        emit EventRegister.RegistrationOpened(0);
        eventRegister.openRegistration(0);
        vm.stopPrank();

        // Verify registration is open
        (,, bool regOpen) = eventRegister.getEvent(0);
        assertTrue(regOpen, "Registration should be open");
    }

    /**
     * @notice Test that only event managers can open/close registrations.
     */
    function testOnlyEventManagersCanOpenCloseRegistrations() public {
        // Create an event first
        vm.startPrank(manager);
        eventRegister.createEvent(eventName1);
        vm.stopPrank();

        // Attempt to close registration as non-manager
        vm.startPrank(user1);
        vm.expectRevert();
        eventRegister.closeRegistration(0);
        vm.stopPrank();

        // Attempt to open registration as non-manager
        vm.startPrank(user1);
        vm.expectRevert();
        eventRegister.openRegistration(0);
        vm.stopPrank();
    }

    /**
     * @notice Test user registration for an open event.
     */
    function testUserCanRegisterForOpenEvent() public {
        // Create an event
        vm.startPrank(manager);
        eventRegister.createEvent(eventName1);
        vm.stopPrank();

        // User1 registers
        vm.startPrank(user1);
        vm.expectEmit(true, false, false, true);
        emit EventRegister.Registered(user1, 0);
        eventRegister.register(0);
        vm.stopPrank();

        // Verify registration
        bool isRegistered = eventRegister.registrations(0, user1);
        assertTrue(isRegistered, "User1 should be registered for event 0");
    }

    /**
     * @notice Test that user cannot register twice for the same event.
     */
    function testUserCannotRegisterTwice() public {
        // Create an event
        vm.startPrank(manager);
        eventRegister.createEvent(eventName1);
        vm.stopPrank();

        // User1 registers first time
        vm.startPrank(user1);
        eventRegister.register(0);
        vm.stopPrank();

        // User1 attempts to register again
        vm.startPrank(user1);
        vm.expectRevert("Already registered for this event");
        eventRegister.register(0);
        vm.stopPrank();
    }

    /**
     * @notice Test that user cannot register for a non-existent event.
     */
    function testUserCannotRegisterForNonExistentEvent() public {
        vm.startPrank(user1);
        vm.expectRevert("Event does not exist");
        eventRegister.register(999);
        vm.stopPrank();
    }

    /**
     * @notice Test retrieving registered events for a user.
     */
    function testGetRegisteredEvents() public {
        // Create two events
        vm.startPrank(manager);
        eventRegister.createEvent(eventName1); // ID 0
        eventRegister.createEvent(eventName2); // ID 1
        vm.stopPrank();

        // User1 registers for both events
        vm.startPrank(user1);
        eventRegister.register(0);
        eventRegister.register(1);
        vm.stopPrank();

        // Retrieve registered events
        uint256[] memory registeredEvents = eventRegister.getRegisteredEvents(user1);
        assertEq(registeredEvents.length, 2, "User1 should have registered for 2 events");
        assertEq(registeredEvents[0], 0, "First event ID should be 0");
        assertEq(registeredEvents[1], 1, "Second event ID should be 1");
    }

    /**
     * @notice Test retrieving event details.
     */
    function testGetEventDetails() public {
        // Create an event
        vm.startPrank(manager);
        eventRegister.createEvent(eventName1); // ID 0
        vm.stopPrank();

        // Retrieve event details
        (uint256 id, string memory name, bool registrationOpen) = eventRegister.getEvent(0);

        assertEq(id, 0, "Event ID should be 0");
        assertEq(name, eventName1, "Event name should match");
        assertTrue(registrationOpen, "Registration should be open");
    }

    /**
     * @notice Test that only event managers can create events.
     */
    function testCannotCreateEventAsNonManager() public {
        vm.startPrank(user1);
        vm.expectRevert();
        eventRegister.createEvent("Autumn Season");
        vm.stopPrank();
    }

    /**
     * @notice Test that only event managers can open registrations.
     */
    function testCannotOpenRegistrationAsNonManager() public {
        // Create an event
        vm.startPrank(manager);
        eventRegister.createEvent(eventName1);
        vm.stopPrank();

        // Attempt to open registration as non-manager (already open)
        vm.startPrank(user1);
        vm.expectRevert();

        eventRegister.openRegistration(0);
        vm.stopPrank();
    }

    /**
     * @notice Test that only event managers can close registrations.
     */
    function testCannotCloseRegistrationAsNonManager() public {
        // Create an event
        vm.startPrank(manager);
        eventRegister.createEvent(eventName1);
        vm.stopPrank();

        // Attempt to close registration as non-manager
        vm.startPrank(user1);
        vm.expectRevert();
        eventRegister.closeRegistration(0);
        vm.stopPrank();
    }

    /**
     * @notice Test that creating multiple events increments event IDs correctly.
     */
    function testMultipleEventCreation() public {
        vm.startPrank(manager);
        eventRegister.createEvent(eventName1);
        eventRegister.createEvent(eventName2);
        vm.stopPrank();

        // Verify first event
        (uint256 id1, string memory name1, bool regOpen1) = eventRegister.getEvent(0);
        assertEq(id1, 0, "First event ID should be 0");
        assertEq(name1, eventName1, "First event name should match");
        assertTrue(regOpen1, "First event registration should be open");

        // Verify second event
        (uint256 id2, string memory name2, bool regOpen2) = eventRegister.getEvent(1);
        assertEq(id2, 1, "Second event ID should be 1");
        assertEq(name2, eventName2, "Second event name should match");
        assertTrue(regOpen2, "Second event registration should be open");
    }

    /**
     * @notice Test that closing an already closed registration reverts.
     */
    function testCannotCloseAlreadyClosedRegistration() public {
        // Create an event
        vm.startPrank(manager);
        eventRegister.createEvent(eventName1);
        vm.stopPrank();

        // Close registration
        vm.startPrank(manager);
        eventRegister.closeRegistration(0);
        vm.stopPrank();

        // Attempt to close again
        vm.startPrank(manager);
        vm.expectRevert("Registrations are already closed for this event");
        eventRegister.closeRegistration(0);
        vm.stopPrank();
    }

    /**
     * @notice Test that opening an already open registration reverts.
     */
    function testCannotOpenAlreadyOpenRegistration() public {
        // Create an event
        vm.startPrank(manager);
        eventRegister.createEvent(eventName1); // ID 0
        vm.stopPrank();

        // Attempt to open registration again (already open)
        vm.startPrank(manager);
        vm.expectRevert("Registrations are already open for this event");
        eventRegister.openRegistration(0);
        vm.stopPrank();
    }

    /**
     * @notice Test that registering after closing registration is not allowed.
     */
    function testCannotRegisterAfterClosingRegistration() public {
        // Create an event
        vm.startPrank(manager);
        eventRegister.createEvent(eventName1); // ID 0
        eventRegister.closeRegistration(0);
        vm.stopPrank();

        // Attempt to register after closing
        vm.startPrank(user1);
        vm.expectRevert("Registrations for this event are closed");
        eventRegister.register(0);
        vm.stopPrank();
    }

    /**
     * @notice Test that multiple users can register
     */
    function testMultipleUsersRegistration() public {
        // Create an event
        vm.startPrank(manager);
        eventRegister.createEvent(eventName1); // ID 0
        vm.stopPrank();

        // User1 registers
        vm.startPrank(user1);
        eventRegister.register(0);
        vm.stopPrank();

        // User2 registers
        vm.startPrank(user2);
        eventRegister.register(0);
        vm.stopPrank();

        // Verify registrations
        assertTrue(eventRegister.registrations(0, user1), "User1 should be registered");
        assertTrue(eventRegister.registrations(0, user2), "User2 should be registered");
    }
}
