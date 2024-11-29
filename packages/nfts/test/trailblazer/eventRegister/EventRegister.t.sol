// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import "../../../contracts/eventRegister/EventRegister.sol";

contract EventRegisterTest is Test {
    EventRegister public eventRegister;

    address public owner = address(0x1);
    address public manager = address(0x2);
    address public user1 = address(0x3);
    address public user2 = address(0x4);

    string public eventName1 = "Spring Season";
    string public eventName2 = "Summer Season";

    function setUp() public {
        vm.startPrank(owner);
        eventRegister = new EventRegister();
        vm.stopPrank();

        vm.startPrank(owner);
        eventRegister.grantEventManagerRole(manager);
        vm.stopPrank();
    }

    function testDeployerHasAdminRole() public view {
        assertTrue(
            eventRegister.hasRole(eventRegister.DEFAULT_ADMIN_ROLE(), owner),
            "Owner should have DEFAULT_ADMIN_ROLE"
        );
    }

    function testManagerHasEventManagerRole() public view {
        assertTrue(
            eventRegister.hasRole(eventRegister.EVENT_MANAGER_ROLE(), manager),
            "Manager should have EVENT_MANAGER_ROLE"
        );
    }

    function testAdminCanGrantEventManagerRole() public {
        vm.startPrank(owner);
        eventRegister.grantEventManagerRole(user1);
        vm.stopPrank();

        assertTrue(
            eventRegister.hasRole(eventRegister.EVENT_MANAGER_ROLE(), user1),
            "User1 should have EVENT_MANAGER_ROLE"
        );
    }

    function testAdminCanRevokeEventManagerRole() public {
        vm.startPrank(owner);
        eventRegister.grantEventManagerRole(user1);
        eventRegister.revokeEventManagerRole(user1);
        vm.stopPrank();

        assertFalse(
            eventRegister.hasRole(eventRegister.EVENT_MANAGER_ROLE(), user1),
            "User1 should not have EVENT_MANAGER_ROLE"
        );
    }

    function testOnlyEventManagersCanCreateEvents() public {
        vm.startPrank(user1);
        vm.expectRevert();
        eventRegister.createEvent(eventName1);
        vm.stopPrank();

        vm.startPrank(manager);
        eventRegister.createEvent(eventName1);
        vm.stopPrank();

        (uint256 id, string memory name, bool registrationOpen) = eventRegister.getEvent(0);
        assertEq(id, 0, "Event ID should be 0");
        assertEq(name, eventName1, "Event name should match");
        assertTrue(registrationOpen, "Registration should be open");
    }

    function testOpenAndCloseRegistrations() public {
        vm.startPrank(manager);
        eventRegister.createEvent(eventName1);
        eventRegister.closeRegistration(0);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert("Registrations closed");
        eventRegister.register(0);
        vm.stopPrank();

        vm.startPrank(manager);
        eventRegister.openRegistration(0);
        vm.stopPrank();

        vm.startPrank(user1);
        eventRegister.register(0);
        vm.stopPrank();

        assertTrue(eventRegister.registrations(0, user1), "User1 should be registered");
    }

    function testOnlyEventManagersCanOpenCloseRegistrations() public {
        vm.startPrank(manager);
        eventRegister.createEvent(eventName1);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert();
        eventRegister.closeRegistration(0);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert();
        eventRegister.openRegistration(0);
        vm.stopPrank();
    }

    function testUserCanRegisterForOpenEvent() public {
        vm.startPrank(manager);
        eventRegister.createEvent(eventName1);
        vm.stopPrank();

        vm.startPrank(user1);
        eventRegister.register(0);
        vm.stopPrank();

        assertTrue(eventRegister.registrations(0, user1), "User1 should be registered for event 0");
    }

    function testUserCannotRegisterTwice() public {
        vm.startPrank(manager);
        eventRegister.createEvent(eventName1);
        vm.stopPrank();

        vm.startPrank(user1);
        eventRegister.register(0);
        vm.expectRevert("Already registered");
        eventRegister.register(0);
        vm.stopPrank();
    }

    function testUserCannotRegisterForNonExistentEvent() public {
        vm.startPrank(user1);
        vm.expectRevert("Event not found");
        eventRegister.register(999);
        vm.stopPrank();
    }

    function testCannotCreateEventAsNonManager() public {
        vm.startPrank(user1);
        vm.expectRevert();
        eventRegister.createEvent("Autumn Season");
        vm.stopPrank();
    }

    function testCannotOpenRegistrationAsNonManager() public {
        vm.startPrank(manager);
        eventRegister.createEvent(eventName1);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert();
        eventRegister.openRegistration(0);
        vm.stopPrank();
    }

    function testCannotCloseRegistrationAsNonManager() public {
        vm.startPrank(manager);
        eventRegister.createEvent(eventName1);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert();
        eventRegister.closeRegistration(0);
        vm.stopPrank();
    }

    function testMultipleEventCreation() public {
        vm.startPrank(manager);
        eventRegister.createEvent(eventName1);
        eventRegister.createEvent(eventName2);
        vm.stopPrank();

        (uint256 id1, string memory name1, bool regOpen1) = eventRegister.getEvent(0);
        assertEq(id1, 0, "First event ID should be 0");
        assertEq(name1, eventName1, "First event name should match");
        assertTrue(regOpen1, "First event registration should be open");

        (uint256 id2, string memory name2, bool regOpen2) = eventRegister.getEvent(1);
        assertEq(id2, 1, "Second event ID should be 1");
        assertEq(name2, eventName2, "Second event name should match");
        assertTrue(regOpen2, "Second event registration should be open");
    }

    function testCannotCloseAlreadyClosedRegistration() public {
        vm.startPrank(manager);
        eventRegister.createEvent(eventName1);
        eventRegister.closeRegistration(0);
        vm.expectRevert("Already closed");
        eventRegister.closeRegistration(0);
        vm.stopPrank();
    }

    function testCannotOpenAlreadyOpenRegistration() public {
        vm.startPrank(manager);
        eventRegister.createEvent(eventName1);
        vm.expectRevert("Already open");
        eventRegister.openRegistration(0);
        vm.stopPrank();
    }

    function testCannotRegisterAfterClosingRegistration() public {
        vm.startPrank(manager);
        eventRegister.createEvent(eventName1);
        eventRegister.closeRegistration(0);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert("Registrations closed");
        eventRegister.register(0);
        vm.stopPrank();
    }

    function testMultipleUsersRegistration() public {
        vm.startPrank(manager);
        eventRegister.createEvent(eventName1);
        vm.stopPrank();

        vm.startPrank(user1);
        eventRegister.register(0);
        vm.stopPrank();

        vm.startPrank(user2);
        eventRegister.register(0);
        vm.stopPrank();

        assertTrue(eventRegister.registrations(0, user1), "User1 should be registered");
        assertTrue(eventRegister.registrations(0, user2), "User2 should be registered");
    }

    function testGetRegisteredEvents() public {
        vm.startPrank(manager);
        eventRegister.createEvent(eventName1);
        eventRegister.createEvent(eventName2);
        vm.stopPrank();

        vm.startPrank(user1);
        eventRegister.register(0);
        eventRegister.register(1);
        vm.stopPrank();

        uint256[] memory registeredEvents = eventRegister.getRegisteredEvents(user1);
        assertEq(registeredEvents.length, 2, "User1 should have registered for 2 events");
        assertEq(registeredEvents[0], 0, "First event ID should be 0");
        assertEq(registeredEvents[1], 1, "Second event ID should be 1");
    }

    function testGetEventDetails() public {
        vm.startPrank(manager);
        eventRegister.createEvent(eventName1);
        vm.stopPrank();

        (uint256 id, string memory name, bool registrationOpen) = eventRegister.getEvent(0);
        assertEq(id, 0, "Event ID should be 0");
        assertEq(name, eventName1, "Event name should match");
        assertTrue(registrationOpen, "Registration should be open");
    }
}
