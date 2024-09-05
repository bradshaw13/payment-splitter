// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract FriendPayments is ReentrancyGuard, Ownable {
    // Errors
    error AlreadyFriends(address from, address to);
    error AmountPerDebtorGreaterThanZero();
    error CannotRequestPaymentFromSelf();
    error DuplicateFriendRequest(address from, address to);
    error FriendRequestMustBeOpenToAccept();
    error IncorrectPaymentAmount();
    error InvalidEthPayment();
    error InvalidFriendRequestRescind();
    error MaximumRequestsOut();
    error MustBeFriendsToRemove();
    error NoDebtorsProvided();
    error NotADebtor();
    error NotFriends(address notFriendAddress);
    error PaymentExpired();
    error NoFriendRequestToReject();

    // Enums
    enum DebtorStatus {
        NotDebtor,
        InDebt,
        DebtPaid
    }

    enum FriendshipStatus {
        NotFriends, // 0 - No friendship or pending request
        RequestedByMe, // 1 - I have sent a friendship request to them
        RequestedByThem, // 2 - They have sent a friendship request to me
        Friends // 3 - We are friends

    }

    enum PaymentStatus {
        Active,
        PartiallyFulfilled,
        Fulfilled,
        Expired
    }

    // Structs
    struct Payment {
        uint256 paymentId; // Unique ID for the payment, typically based on a nonce
        address requestor;
        string paymentName; // Name of the payment (e.g., "Dinner", "Rent")
        // address[] debtors; // Array of addresses that owe the user
        mapping(address debtor => DebtorStatus) debtorStatus; // Mapping to track whether each debtor has paid
        // mapping(address => uint256) percentageOwed; // Mapping to track percentage of the total owed by each debtor
        uint256 amountPerDebtor; // Total amount owed by all debtors combined
        uint256 totalDebtLeft;
        uint256 expirationTime; // Time when the payment request expires
        PaymentStatus status;
    }

    // Events
    event FriendRemoved(address indexed from, address indexed to);
    event FriendRequestAccepted(address indexed from, address indexed to);
    event FriendRequestRescinded(address indexed from, address indexed to);
    event FriendRequestSent(address indexed from, address indexed to);
    event FriendRequestRejected(address indexed rejector, address indexed rejected);
    event PaymentRequested(
        bytes32 indexed uniqueId, address indexed requestor, address indexed debtors, string paymentName
    );
    event ArbitraryPaymentSent(
        address indexed sender, address indexed debtor, uint256 indexed amount, string paymentName
    );

    // State Variables
    uint256 public activeRequestCountMax = 20;

    mapping(address user => uint256 count) private paymentCount;
    mapping(address user => uint256 requestCount) public activeRequestCount;
    mapping(bytes32 requestId => Payment payment) public paymentRequests;
    mapping(address user => mapping(address friendaddress => FriendshipStatus)) public friendships;

    constructor() Ownable(msg.sender) { }

    function sendFriendRequest(address to) external {
        // TODO: Check if to == msg.sender
        FriendshipStatus friendsStatus = friendships[msg.sender][to];

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

    function rejectFriendRequest(address from) external {
        FriendshipStatus status = friendships[msg.sender][from];

        if (status == FriendshipStatus.RequestedByThem) {
            friendships[msg.sender][from] = FriendshipStatus.NotFriends;
            friendships[from][msg.sender] = FriendshipStatus.NotFriends;
            emit FriendRequestRejected(msg.sender, from);
        } else {
            revert NoFriendRequestToReject();
        }
    }

    function getFriendshipStatus(address user, address friend) external view returns (uint256) {
        return uint256(friendships[user][friend]);
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

    function generateUniquePaymentID(uint256 id) public returns (bytes32) {
        bytes32 uniquePaymentHash = keccak256(abi.encodePacked(msg.sender, id));
        // I think I would rather have this move to at the end of the function. not sure.
        paymentCount[msg.sender] += 1;

        return uniquePaymentHash;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   PAYMENT OPERATIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function sendArbitraryPayment(
        string memory _paymentName,
        address[] memory _debtors,
        uint256[] memory _amounts
    )
        external
        payable
        nonReentrant
    {
        if (_debtors.length != _amounts.length) {
            revert IncorrectPaymentAmount();
        }

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < _debtors.length; i++) {
            totalAmount += _amounts[i];
            (bool sent, bytes memory data) = _debtors[i].call{ value: _amounts[i] }("");
            if (!sent) {
                revert InvalidEthPayment();
            }
            // create event for htis
            emit ArbitraryPaymentSent(msg.sender, _debtors[i], _amounts[i], _paymentName);
        }

        if (msg.value < totalAmount) {
            revert IncorrectPaymentAmount();
        }
    }

    function fulfillPayment(bytes32 _paymentId, address debtorToPay) external payable nonReentrant {
        Payment storage payment = paymentRequests[_paymentId];

        if (payment.status == PaymentStatus.Expired) {
            revert PaymentExpired();
        }

        if (payment.debtorStatus[debtorToPay] != DebtorStatus.InDebt) {
            revert NotADebtor();
        }

        if (msg.value < payment.amountPerDebtor) {
            revert IncorrectPaymentAmount();
        }
        unchecked {
            paymentCount[payment.requestor] = paymentCount[payment.requestor] - 1;
        }

        payment.debtorStatus[debtorToPay] = DebtorStatus.DebtPaid;
        payment.totalDebtLeft -= payment.amountPerDebtor;

        if (payment.totalDebtLeft == 0) {
            payment.status = PaymentStatus.Fulfilled;
        } else {
            payment.status = PaymentStatus.PartiallyFulfilled;
        }

        (bool sent, bytes memory data) = payment.requestor.call{ value: msg.value }("");
        if (!sent) {
            revert InvalidEthPayment();
        }
    }

    function requestPayment(
        address[] memory _debtors,
        string memory _paymentName,
        uint256 _amountPerDebtor,
        uint256 _expirationTime
    )
        public
        returns (bytes32)
    {
        if (activeRequestCount[msg.sender] > activeRequestCountMax) {
            revert MaximumRequestsOut();
        }
        if (_debtors.length == 0) {
            revert NoDebtorsProvided();
        }
        if (_amountPerDebtor == 0) {
            revert AmountPerDebtorGreaterThanZero();
        }

        bytes32 uniqueId = generateUniquePaymentID(paymentCount[msg.sender]);

        Payment storage newPayment = paymentRequests[uniqueId];
        newPayment.paymentId = paymentCount[msg.sender];
        newPayment.requestor = msg.sender;
        newPayment.paymentName = _paymentName;
        newPayment.amountPerDebtor = _amountPerDebtor;
        newPayment.totalDebtLeft = _amountPerDebtor * _debtors.length;
        newPayment.expirationTime = _expirationTime;

        for (uint256 i = 0; i < _debtors.length; i++) {
            if (_debtors[i] == msg.sender) {
                revert CannotRequestPaymentFromSelf();
            }
            if (friendships[msg.sender][_debtors[i]] != FriendshipStatus.Friends) {
                revert NotFriends(_debtors[i]);
            }
            newPayment.debtorStatus[_debtors[i]] = DebtorStatus.InDebt;
            emit PaymentRequested(uniqueId, msg.sender, _debtors[i], _paymentName);
        }

        ++paymentCount[msg.sender];

        return uniqueId;
    }

    // Expire a request so someone's request count isn't held up because of one person
    function expirePayment(bytes32 _paymentId) public {
        Payment storage payment = paymentRequests[_paymentId];
        if (payment.expirationTime < block.timestamp && payment.status != PaymentStatus.Fulfilled) {
            payment.status = PaymentStatus.Expired;
        }
    }

    function changeActiveRequestCountMax(uint256 newMax) external onlyOwner {
        activeRequestCountMax = newMax;
    }
}
// add a function to allow a debter to pay off multiple debts at once
