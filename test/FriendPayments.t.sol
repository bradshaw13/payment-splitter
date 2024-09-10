// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "forge-std/src/Test.sol";
import { FriendPayments } from "../src/FriendPayments.sol";

contract FriendPaymentsTestBase is Test {
    FriendPayments public friendPayments;
    address public alice;
    address public bob;
    address public charlie;

    function setUp() public virtual {
        friendPayments = new FriendPayments();
        alice = address(0x1);
        bob = address(0x2);
        charlie = address(0x3);
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);
    }
}

contract FriendshipTests is FriendPaymentsTestBase {
    function test_sendFriendRequest() public {
        vm.prank(alice);
        friendPayments.sendFriendRequest(bob);
        assertEq(
            uint256(friendPayments.getFriendshipStatus(alice, bob)),
            uint256(FriendPayments.FriendshipStatus.RequestedByMe)
        );
        assertEq(
            uint256(friendPayments.getFriendshipStatus(bob, alice)),
            uint256(FriendPayments.FriendshipStatus.RequestedByThem)
        );
    }

    function test_acceptFriendRequest() public {
        vm.prank(alice);
        friendPayments.sendFriendRequest(bob);

        vm.prank(bob);
        friendPayments.acceptFriendRequest(alice);

        assertEq(
            uint256(friendPayments.getFriendshipStatus(alice, bob)), uint256(FriendPayments.FriendshipStatus.Friends)
        );
        assertEq(
            uint256(friendPayments.getFriendshipStatus(bob, alice)), uint256(FriendPayments.FriendshipStatus.Friends)
        );
    }

    function test_removeFriend() public {
        vm.prank(alice);
        friendPayments.sendFriendRequest(bob);

        vm.prank(bob);
        friendPayments.acceptFriendRequest(alice);

        vm.prank(alice);
        friendPayments.removeFriend(bob);

        assertEq(
            uint256(friendPayments.getFriendshipStatus(alice, bob)), uint256(FriendPayments.FriendshipStatus.NotFriends)
        );
        assertEq(
            uint256(friendPayments.getFriendshipStatus(bob, alice)), uint256(FriendPayments.FriendshipStatus.NotFriends)
        );
    }

    function test_rescindFriendRequest() public {
        vm.prank(alice);
        friendPayments.sendFriendRequest(bob);

        vm.prank(alice);
        friendPayments.rescindFriendRequest(bob);

        assertEq(
            uint256(friendPayments.getFriendshipStatus(alice, bob)), uint256(FriendPayments.FriendshipStatus.NotFriends)
        );
        assertEq(
            uint256(friendPayments.getFriendshipStatus(bob, alice)), uint256(FriendPayments.FriendshipStatus.NotFriends)
        );
    }

    function test_rejectFriendRequest() public {
        vm.prank(alice);
        friendPayments.sendFriendRequest(bob);

        vm.prank(bob);
        friendPayments.rejectFriendRequest(alice);

        assertEq(
            uint256(friendPayments.getFriendshipStatus(alice, bob)), uint256(FriendPayments.FriendshipStatus.NotFriends)
        );
        assertEq(
            uint256(friendPayments.getFriendshipStatus(bob, alice)), uint256(FriendPayments.FriendshipStatus.NotFriends)
        );
    }

    function test_isFriendsWithMe() public {
        vm.prank(alice);
        friendPayments.sendFriendRequest(bob);

        vm.prank(bob);
        friendPayments.acceptFriendRequest(alice);

        vm.prank(alice);
        assertTrue(friendPayments.isFriendsWithMe(bob));
    }

    function test_isMutualFriends() public {
        vm.prank(alice);
        friendPayments.sendFriendRequest(bob);
        vm.prank(bob);
        friendPayments.acceptFriendRequest(alice);

        vm.prank(bob);
        friendPayments.sendFriendRequest(charlie);
        vm.prank(charlie);
        friendPayments.acceptFriendRequest(bob);

        vm.prank(alice);
        assertTrue(friendPayments.isMutualFriends(bob, charlie));
    }
}

contract PaymentTests is FriendPaymentsTestBase {
    function setUp() public override {
        super.setUp();
        vm.prank(alice);
        friendPayments.sendFriendRequest(bob);
        vm.prank(bob);
        friendPayments.acceptFriendRequest(alice);
    }

    function test_requestPayment() public {
        address[] memory debtors = new address[](1);
        debtors[0] = bob;

        vm.prank(alice);
        bytes32 paymentId = friendPayments.requestPayment(debtors, "Test Payment", 1 ether, block.timestamp + 100);

        (
            uint256 id,
            address requestor,
            string memory description,
            uint256 amountPerDebtor,
            uint256 totalAmount,
            uint256 expirationTime,
            FriendPayments.PaymentStatus status
        ) = friendPayments.paymentRequests(paymentId);

        assertEq(requestor, alice);
        assertEq(amountPerDebtor, 1 ether);
    }

    function test_fulfillPayment() public {
        address[] memory debtors = new address[](1);
        debtors[0] = bob;

        vm.prank(alice);
        bytes32 paymentId = friendPayments.requestPayment(debtors, "Test Payment", 1 ether, block.timestamp + 100);

        vm.prank(bob);
        friendPayments.fulfillPayment{ value: 1 ether }(paymentId, bob);
        (,,,,,, FriendPayments.PaymentStatus status) = friendPayments.paymentRequests(paymentId);

        assertEq(uint256(status), uint256(FriendPayments.PaymentStatus.Fulfilled));
    }

    function test_sendArbitraryPayment() public {
        address[] memory recipients = new address[](2);
        recipients[0] = bob;
        recipients[1] = charlie;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 0.5 ether;
        amounts[1] = 0.5 ether;

        uint256 aliceBalanceBefore = alice.balance;
        uint256 bobBalanceBefore = bob.balance;
        uint256 charlieBalanceBefore = charlie.balance;

        vm.prank(alice);
        friendPayments.sendArbitraryPayment{ value: 1 ether }("Split Payment", recipients, amounts);

        assertEq(alice.balance, aliceBalanceBefore - 1 ether);
        assertEq(bob.balance, bobBalanceBefore + 0.5 ether);
        assertEq(charlie.balance, charlieBalanceBefore + 0.5 ether);
    }

    function test_expirePayment() public {
        address[] memory debtors = new address[](1);
        debtors[0] = bob;

        vm.prank(alice);
        bytes32 paymentId = friendPayments.requestPayment(debtors, "Test Payment", 1 ether, block.timestamp + 100);

        vm.warp(block.timestamp + 101);
        friendPayments.expirePayment(paymentId);
        (,,,,,, FriendPayments.PaymentStatus status) = friendPayments.paymentRequests(paymentId);

        assertEq(uint256(status), uint256(FriendPayments.PaymentStatus.Expired));
    }
}

contract AdminTests is FriendPaymentsTestBase {
    function test_changeActiveRequestCountMax() public {
        uint256 newMax = 30;
        vm.prank(friendPayments.owner());
        friendPayments.changeActiveRequestCountMax(newMax);
        assertEq(friendPayments.activeRequestCountMax(), newMax);
    }

    function testFail_changeActiveRequestCountMax_notOwner() public {
        uint256 newMax = 30;
        vm.prank(alice);
        friendPayments.changeActiveRequestCountMax(newMax);
    }
}
