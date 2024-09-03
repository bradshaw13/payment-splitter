// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "forge-std/src/Test.sol";
import { FriendPayments } from "../src/FriendPayments.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

contract FriendPaymentsTest is Test {
    FriendPayments public friendPayments;

    function setUp() public virtual {
        friendPayments = new FriendPayments();
    }

    function test_sendFriendRequest() public {
        address alice = address(0x1);
        address bob = address(0x2);

        vm.prank(alice);
        friendPayments.sendFriendRequest(bob);

        vm.prank(bob);
        friendPayments.sendFriendRequest(alice);

        assertEq(friendPayments.getFriendshipStatus(bob, alice), uint256(3));
    }

    // test request payment
    function test_requestPayment() public {
        address alice = address(0x1);
        address bob = address(0x2);

        vm.prank(alice);
        friendPayments.sendFriendRequest(bob);

        vm.prank(bob);
        friendPayments.acceptFriendRequest(alice);

        address[] memory debtors = new address[](1);
        debtors[0] = bob;

        vm.prank(alice);
        friendPayments.requestPayment(debtors, "Test Payment", 1 ether, block.timestamp + 100);
    }

    function test_isFriendsWithMe() public {
        address alice = address(0x1);
        address bob = address(0x2);

        vm.prank(alice);
        friendPayments.sendFriendRequest(bob);

        vm.prank(bob);
        friendPayments.sendFriendRequest(alice);

        vm.prank(alice);
        assertTrue(friendPayments.isFriendsWithMe(bob));
    }
}
