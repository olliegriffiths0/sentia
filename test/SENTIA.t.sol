// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {SENTIA} from "../src/SENTIA.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract SENTIATest is Test {
    SENTIA public sentia;
    address public owner;
    address public user1;
    address public user2;
    address public user3;
    address public user4;
    uint256 public minBidIncrement = 0.005 ether;

    event AuctionStarted(uint256 indexed tokenId, uint256 startTime, uint256 endTime);
    event BidPlaced(address indexed bidder, uint256 amount);
    event AuctionSettled(address indexed winner, uint256 tokenId, uint256 amount);
    event Withdrawal(address indexed recipient, uint256 amount);

    function setUp() public {
        owner = address(0x1);
        user1 = address(0x2);
        user2 = address(0x3);
        user3 = address(0x4);
        user4 = address(0x5);

        vm.prank(owner);
        sentia = new SENTIA(owner);

        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
    }

    function testInitialAuctionNotActive() public {
        (,, uint256 endTime,,,) = sentia.getCurrentAuction();
        assertEq(endTime, 0, "Auction should not be active initially");
    }

    function testAuctionRollover() public {
        vm.prank(owner);
        sentia.setAuctionManager(owner);
        vm.prank(owner);
        sentia.rollover();

        (uint256 tokenId, uint256 startTime, uint256 endTime,,,) = sentia.getCurrentAuction();
        assertGt(tokenId, 0, "Token ID should be greater than zero");
        assertGt(startTime, 0, "Auction start time should be greater than zero");
        assertGt(endTime, startTime, "Auction end time should be after start time");
    }

    function testBid() public {
        vm.prank(owner);
        sentia.setAuctionManager(owner);
        vm.prank(owner);
        sentia.rollover();

        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit BidPlaced(user1, minBidIncrement);
        sentia.bid{value: minBidIncrement}();

        (,,, address highestBidder, uint256 highestBid,) = sentia.getCurrentAuction();
        assertEq(highestBidder, user1, "Highest bidder should be user1");
        assertEq(highestBid, minBidIncrement, "Highest bid should be the bid amount");
    }

    function testWithdraw() public {
        vm.prank(owner);
        sentia.setAuctionManager(owner);
        vm.prank(owner);
        sentia.rollover();

        vm.prank(user1);
        sentia.bid{value: minBidIncrement}();

        vm.prank(user2);
        sentia.bid{value: minBidIncrement * 2}();

        uint256 user1BalanceBefore = user1.balance;
        vm.prank(user1);
        sentia.withdraw();

        assertEq(user1.balance, user1BalanceBefore + minBidIncrement, "User1 should be refunded their previous bid");
    }

    function testBiddingAndRollover() public {
        vm.prank(owner);
        sentia.setAuctionManager(owner);
        vm.prank(owner);
        sentia.rollover();

        uint256 auctionEndTime = block.timestamp + 1 days;

        // User1 bids 0.01 ETH
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        sentia.bid{value: 0.01 ether}();

        // User2 bids 0.015 ETH
        vm.deal(user2, 1 ether);
        vm.prank(user2);
        sentia.bid{value: 0.015 ether}();

        // Fast forward time to auction end
        vm.warp(auctionEndTime + 1);

        vm.prank(owner);
        sentia.rollover();

        // Ensure User2 won the NFT
        assertEq(sentia.ownerOf(1), user2, "User2 should own the NFT");
    }

    function testSetAuctionManager() public {
        vm.prank(owner);
        sentia.setAuctionManager(user1);
        assertEq(sentia.auctionManager(), user1, "Auction manager should be updated");
    }
}
