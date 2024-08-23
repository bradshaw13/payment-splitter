// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

contract FriendPayments {
    error MustBeFriendsToRemove();
    error DuplicateFriendRequest(address from, address to);
    error AlreadyFriends(address from, address to);
    error FriendRequestMustBeOpenToAccept();
    error InvalidFriendRequestRescind();

    // Events
    event FriendRequestSent(address indexed from, address indexed to);
    event FriendRequestAccepted(address indexed from, address indexed to);
    event FriendRemoved(address indexed from, address indexed to);
    event FriendRequestRescinded(address indexed from, address indexed to);

    // It would be cool to issue NFTs if they reach "best friend status"
    enum FriendshipStatus {
        NotFriends, // 0 - No friendship or pending request
        RequestedByMe, // 1 - I have sent a friendship request to them
        RequestedByThem, // 2 - They have sent a friendship request to me
        Friends // 3 - We are friends
    }

    mapping(address user => mapping(address friendaddress => FriendshipStatus)) private friendships;

    function sendFriendRequest(address to) external {
        FriendshipStatus friendsStatus = friendships[to][msg.sender];

        if (friendsStatus == FriendshipStatus.RequestedByThem) {
            friendships[msg.sender][to] = FriendshipStatus.Friends;
            friendships[to][msg.sender] = FriendshipStatus.Friends;
            emit FriendRequestAccepted(to, msg.sender);
        } else if (friendsStatus == FriendshipStatus.NotFriends) {
            friendships[to][msg.sender] = FriendshipStatus.RequestedByThem;
            friendships[msg.sender][to] = FriendshipStatus.RequestedByMe;
            emit FriendRequestSent(msg.sender, to);
        } else if (friendsStatus == FriendshipStatus.RequestedByMe) {
            revert DuplicateFriendRequest(msg.sender, to);
        } else if (friendsStatus == FriendshipStatus.Friends) {
            revert AlreadyFriends(msg.sender, to);
        }
    }

    function removeFriend(address to) external {
        FriendshipStatus status = friendships[msg.sender][to];

        if (status == FriendshipStatus.Friends) {
            friendships[msg.sender][to] = FriendshipStatus.NotFriends;
            friendships[to][msg.sender] = FriendshipStatus.NotFriends;
            emit FriendRemoved(msg.sender, to);
        } else {
            revert MustBeFriendsToRemove();
        }
    }

    function rescindFriendRequest(address to) external {
        FriendshipStatus status = friendships[msg.sender][to];

        if (status == FriendshipStatus.RequestedByMe) {
            friendships[msg.sender][to] = FriendshipStatus.NotFriends;
            emit FriendRequestRescinded(msg.sender, to);
        } else {
            revert InvalidFriendRequestRescind();
        }
    }

    function acceptFriendRequest(address to) external {
        FriendshipStatus status = friendships[msg.sender][to];

        if (status == FriendshipStatus.RequestedByThem) {
            friendships[to][msg.sender] = FriendshipStatus.Friends;
            friendships[msg.sender][to] = FriendshipStatus.Friends;
            emit FriendRequestAccepted(msg.sender, to);
        } else {
            revert FriendRequestMustBeOpenToAccept();
        }
    }

    function isFriendsWithMe(address to) external view returns (bool) {
        return (friendships[msg.sender][to] == FriendshipStatus.Friends);
    }

    function isMutualFriends(address mainFriend, address poi) external view returns (bool) {
        return (
            friendships[mainFriend][msg.sender] == FriendshipStatus.Friends
                && friendships[mainFriend][poi] == FriendshipStatus.Friends
        );
    }

    // Mapping to keep track of the number of payments a user has made
    mapping(address user => uint256 count) private paymentCount;
    mapping(address => uint256) public activeRequestCount;
    mapping(bytes32 requestId => Payment payment) public paymentRequests;

    error NoDebtorsProvided();
    error AmountPerDebtorGreaterThanZero();

    struct Payment {
        uint256 paymentId; // Unique ID for the payment, typically based on a nonce
        string paymentName; // Name of the payment (e.g., "Dinner", "Rent")
        address[] debtors; // Array of addresses that owe the user
        mapping(address => bool) hasPaid; // Mapping to track whether each debtor has paid
        // mapping(address => uint256) percentageOwed; // Mapping to track percentage of the total owed by each debtor
        uint256 amountPerDebtor; // Total amount owed by all debtors combined
    }
    // Example function to generate a unique payment identifier

    function generateUniquePaymentID(uint256 id) public returns (bytes32) {
        bytes32 uniquePaymentHash = keccak256(abi.encodePacked(msg.sender, id));
        // I think I would rather have this move to at the end of the function. not sure.
        paymentCount[msg.sender] += 1;

        return uniquePaymentHash;
    }

    // Function to retrieve the current payment count for a user (for reference)
    function getPaymentCount(address user) public view returns (uint256) {
        return paymentCount[user];
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   PAYMENT OPERATIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // Pay friend

    // Request Friend
    function requestPayment(address[] memory _debtors, string memory _paymentName, uint256 _amountPerDebtor) public {
        if (_debtors.length == 0) {
            revert NoDebtorsProvided();
        }
        if (_amountPerDebtor == 0) {
            revert AmountPerDebtorGreaterThanZero();
        }
        bytes32 uniqueId = generateUniquePaymentID(paymentCount[msg.sender]);

        Payment storage newPayment = paymentRequests[uniqueId];
        newPayment.paymentId = paymentCount[msg.sender];
        newPayment.paymentName = _paymentName;
        newPayment.amountPerDebtor = _amountPerDebtor;
        newPayment.debtors = _debtors;

        ++paymentCount[msg.sender];
    }

    // Expire a request so someone's request count isn't held up because of one person

    // cannot unfriend someone until they have paid all of their debts

    // payment id can be unique based on

    // you can't request unless you are friends, but you can pay them if you are friends
    // maybe they have to sign a tx to accept a debt to someone

    // activeRequestCount seems to be the way to go for now
}
