// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25 <0.9.0;

import { FriendPayments } from "../src/FriendPayments.sol";
import { BaseScript } from "./Base.s.sol";

contract Deploy is BaseScript {
    FriendPayments public friendPayments;

    function run() public broadcast {
        friendPayments = new FriendPayments();
    }

    // forge script script/Deploy.s.sol:Deploy --sig "requestPayment(address[],string,uint256,uint256,address)"
    // \[0x2d76eb0dbe6c2b8623cf5f1ac4200068a8d7977b\] "Test 1" 10000000000000 1756415101
    // 0xb101d5910CBa257e418E4c5064876FBE1b1f08a4 --rpc-url base_sepolia --sender
    // 0x1e27dace4a6fc84caad9be5e336f36c1195dafb8 --account main1E --broadcast
    function requestPayment(
        address[] memory _debtors,
        string memory _paymentName,
        uint256 _amountPerDebtor,
        uint256 _expirationTime,
        address _currentContractAddress
    )
        public
        broadcast
    {
        friendPayments = FriendPayments(_currentContractAddress);
        friendPayments.requestPayment(_debtors, _paymentName, _amountPerDebtor, _expirationTime);
    }

    // Example: forge script script/Deploy.s.sol:Deploy --sig "sendFriendRequest(address,address)"
    // 0x1234567890123456789012345678901234567890 0xb101d5910CBa257e418E4c5064876FBE1b1f08a4 --rpc-url base_sepolia
    // --sender 0x1e27dace4a6fc84caad9be5e336f36c1195dafb8 --account main1E --broadcast
    function sendFriendRequest(address _friend, address _currentContractAddress) public broadcast {
        friendPayments = FriendPayments(_currentContractAddress);
        friendPayments.sendFriendRequest(_friend);
    }

    // Example: forge script script/Deploy.s.sol:Deploy --sig "acceptFriendRequest(address,address)"
    // 0x1234567890123456789012345678901234567890 0xb101d5910CBa257e418E4c5064876FBE1b1f08a4 --rpc-url base_sepolia
    // --sender 0x1e27dace4a6fc84caad9be5e336f36c1195dafb8 --account main1E --broadcast
    // --broadcast
    function acceptFriendRequest(address _friend, address _currentContractAddress) public broadcast {
        friendPayments = FriendPayments(_currentContractAddress);
        friendPayments.acceptFriendRequest(_friend);
    }

    // Example: forge script script/Deploy.s.sol:Deploy --sig "rejectFriendRequest(address,address)"
    // 0x1234567890123456789012345678901234567890 0xb101d5910CBa257e418E4c5064876FBE1b1f08a4 --rpc-url base_sepolia
    // --sender 0x1e27dace4a6fc84caad9be5e336f36c1195dafb8 --account main1E --broadcast
    // --broadcast
    function rejectFriendRequest(address _friend, address _currentContractAddress) public broadcast {
        friendPayments = FriendPayments(_currentContractAddress);
        friendPayments.rejectFriendRequest(_friend);
    }

    // Example: forge script script/Deploy.s.sol:Deploy --sig "rescindFriendRequest(address,address)"
    // 0x1234567890123456789012345678901234567890 0xb101d5910CBa257e418E4c5064876FBE1b1f08a4 --rpc-url base_sepolia
    // --sender 0x1e27dace4a6fc84caad9be5e336f36c1195dafb8 --account main1E --broadcast
    function rescindFriendRequest(address _friend, address _currentContractAddress) public broadcast {
        friendPayments = FriendPayments(_currentContractAddress);
        friendPayments.rescindFriendRequest(_friend);
    }

    // keccak256(abi.encodePacked(msg.sender, id));
    // should've emitted an event for the unique payment id
    // forge script script/Deploy.s.sol:Deploy --sig "generateUniquePaymentID(uint256)"
}
