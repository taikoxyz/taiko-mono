// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/src/Test.sol";

import { TaikoPartyTicket } from "../../contracts/party-ticket/TaikoPartyTicket.sol";
import { Merkle } from "murky/Merkle.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { MockBlacklist } from "../util/Blacklist.sol";
import { IMinimalBlacklist } from "@taiko/blacklist/IMinimalBlacklist.sol";
import { TaikoPartyTicketV2 } from "../../contracts/party-ticket/TaikoPartyTicketV2.sol";

contract TaikoPartyTicketTest is Test {
    TaikoPartyTicket public tokenV1;
    TaikoPartyTicketV2 public tokenV2;

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

        tokenV1 = TaikoPartyTicket(proxy);

        // deploy v2 upgrade

        tokenV1.upgradeToAndCall(
            address(new TaikoPartyTicketV2()), abi.encodeCall(TaikoPartyTicketV2.version, ())
        );

        tokenV2 = TaikoPartyTicketV2(address(tokenV1));

        // assign initial balance to all minters
        for (uint256 i = 0; i < minters.length; i++) {
            vm.deal(minters[i], INITIAL_BALANCE);
        }

        vm.stopPrank();
    }

    function test_metadata() public view {
        assertEq(tokenV2.name(), "TaikoPartyTicket");
        assertEq(tokenV2.symbol(), "TPT");
        assertEq(tokenV2.totalSupply(), 0);
    }

    function test_mint() public {
        vm.prank(minters[0]);
        tokenV2.mint{ value: MINT_FEE }();
        assertEq(tokenV2.totalSupply(), 1);
        assertEq(tokenV2.ownerOf(0), minters[0]);
        assertEq(minters[0].balance, INITIAL_BALANCE - MINT_FEE);
    }

    function test_mint_admin() public {
        vm.prank(admin);
        tokenV2.mint(minters[1]);
        assertEq(tokenV2.totalSupply(), 1);
        assertEq(tokenV2.ownerOf(0), minters[1]);
    }

    function test_winnerFlow() public {
        // have all minters mint
        vm.prank(minters[0]);
        tokenV2.mint{ value: MINT_FEE }();
        vm.prank(minters[1]);
        tokenV2.mint{ value: MINT_FEE }();
        vm.prank(minters[2]);
        tokenV2.mint{ value: MINT_FEE }();

        // set minters[0] as winner
        vm.startPrank(admin);
        uint256[] memory winners = new uint256[](2);
        // assign the winners
        winners[0] = 0;
        winners[1] = 1;
        // ability to pause the minting and set the winners later
        tokenV2.pause();
        tokenV2.setWinners(winners);
        vm.stopPrank();
        // check winner with both tokenId and address
        assertTrue(tokenV2.isWinner(0));
        assertTrue(tokenV2.isWinner(minters[0]));
        assertTrue(tokenV2.isWinner(minters[1]));
        assertFalse(tokenV2.isWinner(minters[2]));
        // check golden winner
        assertTrue(tokenV2.isGoldenWinner(0));
        assertTrue(tokenV2.isGoldenWinner(minters[0]));
        assertFalse(tokenV2.isGoldenWinner(1));
        assertFalse(tokenV2.isGoldenWinner(minters[1]));
        assertFalse(tokenV2.isGoldenWinner(2));
        assertFalse(tokenV2.isGoldenWinner(minters[2]));

        // and the contract is paused
        assertTrue(tokenV2.paused());
        // ensure the contract's balance
        assertEq(address(tokenV2).balance, MINT_FEE * minters.length);
    }

    function test_payout() public {
        test_winnerFlow();
        uint256 collectedEth = address(tokenV2).balance;
        vm.prank(admin);
        tokenV2.payout();
        assertEq(payoutWallet.balance, collectedEth);
        assertEq(address(tokenV2).balance, 0);
    }

    function test_ipfs_metadata_goldenWinner() public {
        // ensure URIs are "ticket" before setting winners
        assertEq(tokenV2.baseURI(), "ipfs://baseURI");
        assertEq(tokenV2.tokenURI(0), "ipfs://baseURI/raffle.json");
        assertEq(tokenV2.tokenURI(1), "ipfs://baseURI/raffle.json");
        // run winner flow
        test_winnerFlow();
        // ensure URIs are "winner" and "loser" after setting winners
        assertEq(tokenV2.tokenURI(0), "ipfs://baseURI/golden-winner.json");
        assertEq(tokenV2.tokenURI(1), "ipfs://baseURI/winner.json");
        assertEq(tokenV2.tokenURI(2), "ipfs://baseURI/loser.json");
    }

    function test_revokeWinner() public {
        test_winnerFlow();
        // ensure the contract is paused
        assertTrue(tokenV2.paused());
        // ensure wallet0 is winner
        assertTrue(tokenV2.isWinner(minters[0]));

        uint256[] memory winnerIds = tokenV2.getWinnerTokenIds();
        assertEq(winnerIds.length, 2);
        address[] memory winners = tokenV2.getWinners();
        assertEq(winners.length, 2);

        // revoke the winner
        vm.prank(admin);
        tokenV2.revokeWinner(winnerIds[0]);

        winnerIds = tokenV2.getWinnerTokenIds();
        assertEq(winnerIds.length, 1);
        winners = tokenV2.getWinners();
        assertEq(winners.length, 1);
    }

    function test_revokeAndReplaceWinner() public {
        test_winnerFlow();
        // ensure the contract is paused
        assertTrue(tokenV2.paused());

        // ensure wallet0 is winner
        assertTrue(tokenV2.isWinner(minters[0]));
        assertTrue(tokenV2.isWinner(minters[1]));
        assertFalse(tokenV2.isWinner(minters[2]));

        uint256[] memory winnerIds = tokenV2.getWinnerTokenIds();
        assertEq(winnerIds.length, 2);
        address[] memory winners = tokenV2.getWinners();
        assertEq(winners.length, 2);

        // revoke and replace with token id 2
        vm.prank(admin);
        tokenV2.revokeAndReplaceWinner(winnerIds[0], 2);

        assertFalse(tokenV2.isWinner(minters[0]));
        assertTrue(tokenV2.isWinner(minters[1]));
        assertTrue(tokenV2.isWinner(minters[2]));

        winnerIds = tokenV2.getWinnerTokenIds();
        assertEq(winnerIds.length, 2);

        winners = tokenV2.getWinners();
        assertEq(winners.length, 2);

        assertFalse(tokenV2.isWinner(minters[0]));
        assertTrue(tokenV2.isWinner(minters[1]));
        assertTrue(tokenV2.isWinner(minters[2]));
    }
}
