// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/src/Test.sol";

import { TaikoPartyTicket } from "../../contracts/party-ticket/TaikoPartyTicket.sol";
import { Merkle } from "murky/Merkle.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { MockBlacklist } from "../util/Blacklist.sol";

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
        vm.startBroadcast(admin);

        // deploy token with empty root
        address impl = address(new TaikoPartyTicket());
        address proxy = address(
            new ERC1967Proxy(
                impl,
                abi.encodeCall(
                    TaikoPartyTicket.initialize,
                    (payoutWallet, MINT_FEE, "ipfs://participant", blacklist)
                )
            )
        );

        token = TaikoPartyTicket(proxy);

        // assign initial balance to all minters
        for (uint256 i = 0; i < minters.length; i++) {
            vm.deal(minters[i], INITIAL_BALANCE);
        }

        vm.stopBroadcast();
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
        vm.prank(admin);
        uint256[] memory winners = new uint256[](1);
        winners[0] = winnerTokenId;
        token.setWinners(winners, "ipfs://winnerURI", "ipfs://loserURI");
        // check winner with both tokenId and address
        assertTrue(token.isWinner(winnerTokenId));
        assertTrue(token.isWinner(minters[0]));
        // and the contract is paused
        assertTrue(token.paused());
        // ensure the contract's balance
        assertEq(address(token).balance, MINT_FEE * minters.length);
    }

    function test_withdraw() public {
        test_winnerFlow();
        uint256 collectedEth = address(token).balance;
        vm.prank(admin);
        token.withdraw();
        assertEq(payoutWallet.balance, collectedEth);
        assertEq(address(token).balance, 0);
    }
}
