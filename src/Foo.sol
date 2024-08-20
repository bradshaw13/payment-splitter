// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

contract Foo {
    error MustBeFriendsToRemove();

    enum FriendshipStatus {
        NotFriends,
        Pending,
        Friends
    }

    mapping(bytes32 key => FriendshipStatus status) private friendships;

    function _getFriendshipKey(address user1, address user2) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(user1 < user2 ? user1 : user2, user1 < user2 ? user2 : user1));
    }

    function sendFriendRequest(address to) external {
        bytes32 key = _getFriendshipKey(msg.sender, to);
        FriendshipStatus status = friendships[key];
        if (status == FriendshipStatus.NotFriends) {
            friendships[key] = FriendshipStatus.Pending;

            return;
        } else if (status == FriendshipStatus.Pending) {
            friendships[key] = FriendshipStatus.Friends;
            return;
        } else {
            // Could revert and say already friends
            return;
        }
    }

    function removeFriend(address to) external {
        bytes32 key = _getFriendshipKey(msg.sender, to);
        FriendshipStatus status = friendships[key];

        if (status == FriendshipStatus.Friends) {
            friendships[key] = FriendshipStatus.NotFriends;
            return;
        } else {
            revert MustBeFriendsToRemove();
        }
    }

    function rescindFriendRequest(address to) external {
        bytes32 key = _getFriendshipKey(msg.sender, to);
        FriendshipStatus status = friendships[key];

        if (status == FriendshipStatus.Pending) {
            friendships[key] = FriendshipStatus.NotFriends;
            return;
        } else {
            // Revert and say you must be pending friends with someone to rescind request
        }
    }

    function acceptFriendRequest(address from) external {
        bytes32 key = _getFriendshipKey(from, msg.sender);
        require(friendships[key] == FriendshipStatus.Pending, "No pending request from this user");
        friendships[key] = FriendshipStatus.Friends;
    }

    function checkFriendshipStatus(address user1, address user2) external view returns (FriendshipStatus) {
        return friendships[_getFriendshipKey(user1, user2)];
    }

    function isMutualFriends(address user1, address user2) external view returns (bool) {
        return friendships[_getFriendshipKey(user1, user2)] == FriendshipStatus.Friends;
    }
    // Need to create a mapping of friends then you can do a look up both ways to see if you are friends
    // 0 means not friends (default)
    // 1 means pending friends
    // 2 means means friends
}
