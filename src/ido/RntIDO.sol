// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "../common/ReentrancyGuard.sol";
import {BaseToken} from "../token/BaseToken.sol";
import {Test, console} from "forge-std/Test.sol";

/**
 * @title raise fund
 * @author nicky.zhang
 * @notice
 */
contract RntIDO is ReentrancyGuard, Ownable(msg.sender) {
    address token;

    mapping(address => uint256) public balances;

    // presale price: 1 token =0.001 ether
    uint256 public constant PRESALE_PRICE = 0.001 ether;

    // min rasie target: MIN_RAISE_FUNDING/PRESALE_PRICE = 10/0.001=10000
    uint256 public constant MIN_RAISE_FUNDING = 10 ether;

    // rasie upper limit
    uint256 public constant MAX_RAISE_FUNDING = 100 ether;

    // duration
    uint256 public immutable END_TIME;

    // how much token haved sold
    uint256 public totalSold;

    // how much eth have raised
    uint256 public totalRaised;

    constructor(address _token) public {
        token = _token;
        END_TIME = block.timestamp + 7 days;
    }

    function getTotalSold() public returns (uint256) {
        return totalSold;
    }

    function getTotalRaised() public returns (uint256) {
        return totalRaised;
    }

    event Presale(address indexed, uint256 indexed);

    error RNTNotEnough();
    error PreSaleNotEnd();
    error NotRaiseMinFunding();
    error NotAllowRefund();
    error UserNotHaveAmount();
    error FailToRefundUser();
    error WithdrawByNonInitiator();
    error InitiatorWithdrawFailed();

    function presale(uint256 amount) public payable noReentrancy {
        require(amount > 0, "Presale amount must greater than 0");
        require(block.timestamp <= END_TIME, "Presale time is end");
        require(
            msg.value == amount * PRESALE_PRICE,
            "Presale eth must equal to amount * price"
        );

        // statistic the totalSold and totalRaised
        totalSold += amount; // how much ido have solded out
        if (BaseToken(token).balanceOf(address(this)) < getTotalSold())
            revert RNTNotEnough();

        totalRaised += msg.value; // how much funds(ether) have raised
        require(
            getTotalRaised() <= MAX_RAISE_FUNDING,
            "Presale haved raise max funding, stop presale"
        );

        // statistic the user amount
        balances[msg.sender] += amount;

        emit Presale(msg.sender, amount);
    }

    /*
     * If success to presale, user could get token
     */
    function claim() public {
        // check if IDO is success
        if (block.timestamp < END_TIME) revert PreSaleNotEnd();
        // check if funding is up to min funding
        if (getTotalRaised() < MIN_RAISE_FUNDING) revert NotRaiseMinFunding();

        // get user balance
        uint256 amount = balanceOf(msg.sender);
        // check if user have buy the token
        require(amount > 0, "User have no any amount, can not claim");

        // calculate the share
        uint256 share = getTotalRaised() / getTotalSold();

        // calculate the claim amount
        uint256 claimAmount = share * amount;

        balances[msg.sender] = 0;
        // calculate the pledge revenue and trnasfer BINX to msg.sender
        BaseToken(token).transfer(msg.sender, claimAmount);
    }

    /*
     * If raise failed, return eth to user
     */
    function refund() public {
        // check if IDO is success
        if (block.timestamp < END_TIME) revert PreSaleNotEnd();

        // check if IDO is success
        if (getTotalRaised() > MIN_RAISE_FUNDING) revert NotAllowRefund();

        // check if user token amount
        uint256 amount = balanceOf(msg.sender);

        require(amount > 0, "User have no any amount, can not refund");

        // reset user  balance
        balances[msg.sender] = 0;

        // refund to user
        uint256 claimAmount = amount * PRESALE_PRICE;

        (bool success, ) = msg.sender.call{value: claimAmount}("");
        if (!success) revert FailToRefundUser();
    }

    /**
     * Generally, the raised funds could put into DEX to improve luiqidity
     * If presale success, project party could withdraw raised funds
     */
    function withdraw() external onlyOwner {
        // check if presale is end
        if (block.timestamp < END_TIME) revert PreSaleNotEnd();

        // check if rasie the minimum funding
        if (getTotalRaised() < MIN_RAISE_FUNDING) revert NotRaiseMinFunding();

        (bool success, ) = msg.sender.call{value: getTotalRaised()}("");
        if (!success) revert InitiatorWithdrawFailed();
    }



    function balanceOf(address user) public view returns (uint256) {
        return balances[user];
    }
}
