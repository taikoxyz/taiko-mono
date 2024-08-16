// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/src/Test.sol";

import { TaikoPartyTicket } from "../../contracts/party-ticket/TaikoPartyTicket.sol";
import { Merkle } from "murky/Merkle.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { MockBlacklist } from "../util/Blacklist.sol";
import { IMinimalBlacklist } from "@taiko/blacklist/IMinimalBlacklist.sol";

contract TaikoPartyTicketV2 is TaikoPartyTicket {
    function testV2() public pure returns (bool) {
        return true;
    }
}

contract TaikoPartyTicketTest is Test {
    TaikoPartyTicket public token;

    address public payoutWallet = vm.addr(0x5);
    address public admin = vm.addr(0x6);

    address[3] public minters = [vm.addr(0x1), vm.addr(0x2), vm.addr(0x3)];

    uint256 constant MINT_FEE = 1.1 ether;
    uint256 constant INITIAL_BALANCE = 2 ether;

    MockBlacklist public blacklist;

    function setUp() public {
        blacklist = new MockBlacklist();
        // create whitelist merkle tree
        vm.startPrank(admin);

        address impl = address(new TaikoPartyTicket());
        address proxy = address(
            new ERC1967Proxy(
                impl,
                abi.encodeCall(
                    TaikoPartyTicket.initialize,
                    (payoutWallet, MINT_FEE, "ipfs://baseURI", blacklist)
                )
            )
        );

        token = TaikoPartyTicket(proxy);

        // assign initial balance to all minters
        for (uint256 i = 0; i < minters.length; i++) {
            vm.deal(minters[i], INITIAL_BALANCE);
        }

        vm.stopPrank();
    }

    function test_metadata() public view {
        assertEq(token.name(), "TaikoPartyTicket");
        assertEq(token.symbol(), "TPT");
        assertEq(token.totalSupply(), 0);
    }

    function test_mint() public {
        vm.prank(minters[0]);
        token.mint{ value: MINT_FEE }();
        assertEq(token.totalSupply(), 1);
        assertEq(token.ownerOf(0), minters[0]);
        assertEq(minters[0].balance, INITIAL_BALANCE - MINT_FEE);
    }

    function test_mint_admin() public {
        vm.prank(admin);
        token.mint(minters[1]);
        assertEq(token.totalSupply(), 1);
        assertEq(token.ownerOf(0), minters[1]);
    }

    function test_winnerFlow() public {
        // have all minters mint
        vm.prank(minters[0]);
        token.mint{ value: MINT_FEE }();
        vm.prank(minters[1]);
        token.mint{ value: MINT_FEE }();
        vm.prank(minters[2]);
        token.mint{ value: MINT_FEE }();

        // arbitrarily, minters[0] wins
        uint256 winnerTokenId = 0;

        // set minters[0] as winner
        vm.startPrank(admin);
        uint256[] memory winners = new uint256[](1);
        winners[0] = winnerTokenId;
        // ability to pause the minting and set the winners later
        token.pause();
        token.setWinners(winners);
        vm.stopPrank();
        // check winner with both tokenId and address
        assertTrue(token.isWinner(winnerTokenId));
        assertTrue(token.isWinner(minters[0]));
        // and the contract is paused
        assertTrue(token.paused());
        // ensure the contract's balance
        assertEq(address(token).balance, MINT_FEE * minters.length);
    }

    function test_payout() public {
        test_winnerFlow();
        uint256 collectedEth = address(token).balance;
        vm.prank(admin);
        token.payout();
        assertEq(payoutWallet.balance, collectedEth);
        assertEq(address(token).balance, 0);
    }

    function test_ipfs_metadata() public {
        // ensure URIs are "ticket" before setting winners
        assertEq(token.baseURI(), "ipfs://baseURI");
        assertEq(token.tokenURI(0), "ipfs://baseURI/raffle.json");
        assertEq(token.tokenURI(1), "ipfs://baseURI/raffle.json");
        // run winner flow
        test_winnerFlow();
        // ensure URIs are "winner" and "loser" after setting winners
        assertEq(token.tokenURI(0), "ipfs://baseURI/winner.json");
        assertEq(token.tokenURI(1), "ipfs://baseURI/loser.json");
    }

    function test_upgrade() public {
        // create the v1 instance of the token
        vm.startPrank(admin);

        address impl = address(new TaikoPartyTicket());
        address proxy = address(
            new ERC1967Proxy(
                impl,
                abi.encodeCall(
                    TaikoPartyTicket.initialize,
                    (payoutWallet, MINT_FEE, "ipfs://baseURI", blacklist)
                )
            )
        );

        TaikoPartyTicket tokenV1 = TaikoPartyTicket(proxy);
        vm.stopPrank();

        // mint some tokens
        vm.prank(minters[0]);
        tokenV1.mint{ value: MINT_FEE }();
        vm.prank(minters[1]);
        tokenV1.mint{ value: MINT_FEE }();
        vm.prank(minters[2]);
        tokenV1.mint{ value: MINT_FEE }();

        // upgrade to v2
        vm.startPrank(admin);

        tokenV1.upgradeToAndCall(
            address(new TaikoPartyTicketV2()), abi.encodeCall(TaikoPartyTicketV2.testV2, ())
        );

        TaikoPartyTicketV2 tokenV2 = TaikoPartyTicketV2(address(tokenV1));

        // ensure balances from v1 are still relevant
        assertEq(tokenV2.totalSupply(), 3);
        assertEq(tokenV2.ownerOf(0), minters[0]);
        assertEq(tokenV2.ownerOf(1), minters[1]);
        assertEq(tokenV2.ownerOf(2), minters[2]);

        // test the v2 mock method
        assertTrue(tokenV2.testV2());

        vm.stopPrank();
    }

    function test_upgrade_throw() public {
        // create the v1 instance of the token
        vm.startPrank(admin);

        address impl = address(new TaikoPartyTicket());
        address proxy = address(
            new ERC1967Proxy(
                impl,
                abi.encodeCall(
                    TaikoPartyTicket.initialize,
                    (payoutWallet, MINT_FEE, "ipfs://baseURI", blacklist)
                )
            )
        );

        TaikoPartyTicket tokenV1 = TaikoPartyTicket(proxy);
        vm.stopPrank();

        // mint some tokens
        vm.prank(minters[0]);
        tokenV1.mint{ value: MINT_FEE }();
        vm.prank(minters[1]);
        tokenV1.mint{ value: MINT_FEE }();
        vm.prank(minters[2]);
        tokenV1.mint{ value: MINT_FEE }();

        // attempt to upgrade as non-admin
        vm.startPrank(minters[0]);

        TaikoPartyTicketV2 v2 = new TaikoPartyTicketV2();
        vm.expectRevert();
        tokenV1.upgradeToAndCall(address(v2), abi.encodeCall(TaikoPartyTicketV2.testV2, ()));

        vm.stopPrank();

        // upgrade to v2 properly after the failed attempt
        vm.startPrank(admin);

        tokenV1.upgradeToAndCall(
            address(new TaikoPartyTicketV2()), abi.encodeCall(TaikoPartyTicketV2.testV2, ())
        );

        TaikoPartyTicketV2 tokenV2 = TaikoPartyTicketV2(address(tokenV1));

        // ensure balances from v1 are still relevant
        assertEq(tokenV2.totalSupply(), 3);
        assertEq(tokenV2.ownerOf(0), minters[0]);
        assertEq(tokenV2.ownerOf(1), minters[1]);
        assertEq(tokenV2.ownerOf(2), minters[2]);

        // test the v2 mock method
        assertTrue(tokenV2.testV2());

        vm.stopPrank();
    }

    function test_revokeWinner() public {
        test_winnerFlow();
        // ensure the contract is paused
        assertTrue(token.paused());
        // ensure wallet0 is winner
        assertTrue(token.isWinner(minters[0]));

        uint256[] memory winnerIds = token.getWinnerTokenIds();
        assertEq(winnerIds.length, 1);
        address[] memory winners = token.getWinners();
        assertEq(winners.length, 1);

        // revoke the winner
        vm.prank(admin);
        token.revokeWinner(winnerIds[0]);

        winnerIds = token.getWinnerTokenIds();
        assertEq(winnerIds.length, 0);
        winners = token.getWinners();
        assertEq(winners.length, 0);
    }

    function test_revokeAndReplaceWinner() public {
        test_winnerFlow();
        // ensure the contract is paused
        assertTrue(token.paused());

        // ensure wallet0 is winner

        assertTrue(token.isWinner(minters[0]));
        assertFalse(token.isWinner(minters[1]));
        assertFalse(token.isWinner(minters[2]));

        uint256[] memory winnerIds = token.getWinnerTokenIds();
        assertEq(winnerIds.length, 1);
        address[] memory winners = token.getWinners();
        assertEq(winners.length, 1);

        // revoke and replace with token id 2
        vm.prank(admin);
        token.revokeAndReplaceWinner(winnerIds[0], 2);

        assertFalse(token.isWinner(minters[0]));
        assertFalse(token.isWinner(minters[1]));
        assertTrue(token.isWinner(minters[2]));

        winnerIds = token.getWinnerTokenIds();
        assertEq(winnerIds.length, 1);

        winners = token.getWinners();
        assertEq(winners.length, 1);
        assertEq(winnerIds[0], 2);
        assertEq(winners[0], minters[2]);
    }
}
