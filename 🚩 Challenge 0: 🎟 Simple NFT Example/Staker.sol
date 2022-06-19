// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./ExampleExternalContract.sol";

/// @title Contranct for 🚩 Challenge 1: 🥩 Decentralized Staking App
/// @author Olivier Winkler
/// @notice This is an example Contract for solving Challenge 1
/// @dev All function calls are currently implemented without side effects
contract Staker {
    ExampleExternalContract public immutable EXTERNAL_CONTRACT;
    uint256 public constant THRESHOLD = 1 ether;
    uint256 public constant MINIMAL_STAKE_AMOUNT = 0.5 ether;

    uint256 public deadline = block.timestamp + 72 hours;

    mapping(address => uint256) public balances;

    bool private openForWithdraw = false;

    event Stake(address sender, uint256 value);

    /// Invalid balance to transfer. Needed `minRequired` but sent `amount`
    /// @param sent sent amount.
    /// @param minRequired minimum amount to send.
    error InvalidAmount(uint256 sent, uint256 minRequired);

    /// Invalid user's balance. Need more than 0 as balance
    error InvalidUserBalance();

    constructor(address exampleExternalContractAddress) {
        EXTERNAL_CONTRACT = ExampleExternalContract(
            exampleExternalContractAddress
        );
    }

    /// @notice Checks if the staking goal is already met
    modifier isThresholdMet() {
        require(
            address(this).balance >= THRESHOLD,
            "Staking Goal isn't reached yet!"
        );
        _;
    }

    /// @notice Checks if the deadline has already been passed
    modifier hasDeadlinePassed(bool requireReached) {
        uint256 remainingTime = timeLeft();
        requireReached
            ? require(remainingTime == 0, "Deadline not reached yet!")
            : require(remainingTime > 0, "Sorry, the deadline has passed!");
        _;
    }

    /// @notice Checks if the external contract has completed
    modifier stakingNotCompleted() {
        bool completed = EXTERNAL_CONTRACT.completed();
        require(!completed, "Staking period has completed");
        _;
    }

    /// @notice Add the `receive()` special function that receives eth and calls stake()
    /// @dev Fallback function
    receive() external payable {
        stake();
    }

    /// @notice Collect funds in a payable `stake()` function and track individual `balances` with a mapping
    /// @dev Stake method that update the user's balance
    function stake()
        public
        payable
        hasDeadlinePassed(false)
        stakingNotCompleted
    {
        uint256 amount = msg.value;
        if (amount < MINIMAL_STAKE_AMOUNT)
            revert InvalidAmount(amount, MINIMAL_STAKE_AMOUNT);

        balances[msg.sender] += amount;
        emit Stake(msg.sender, msg.value);
    }

    /// @notice After some `deadline` allow anyone to call an `execute()` function
    /// @dev Stake method that update the sender's balance
    function execute() public isThresholdMet {
        EXTERNAL_CONTRACT.complete{value: address(this).balance}();
    }

    /// @notice Add a `withdraw()` function to let users withdraw their balance,
    /// if the `threshold` was not met, allow everyone to call a `withdraw()` function
    /// @dev Withdraw user's funds from contract
    function withdraw() public hasDeadlinePassed(true) stakingNotCompleted {
        uint256 userBalance = balances[msg.sender];
        if (userBalance <= 0) revert InvalidUserBalance();

        balances[msg.sender] = 0;

        (bool success, ) = msg.sender.call{value: userBalance}("");
        require(success, "Transfer failed.");
    }

    /// @notice Add a `timeLeft()` view function that returns the time left before the deadline for the frontend
    /// @dev Returns reamining Time, if deadline has passen, return 0
    /// @return Returns remaining time
    function timeLeft() public view returns (uint256) {
        if (block.timestamp >= deadline) return 0;

        return deadline - block.timestamp;
    }
}
