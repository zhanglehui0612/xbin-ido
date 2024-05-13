// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {Test, console} from "forge-std/Test.sol";
import {RntIDO} from "../src/ido/RntIDO.sol";
import {RNTStake} from "../src/stake/RNTStake.sol";
import {BaseToken} from "../src/token/BaseToken.sol";
import {RewardToken} from "../src/token/RewardToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract RNTStakeTest is Test {
    address initialzier;
    address marketor;
    address buyer1;
    address buyer2;

   function setUp() public {
        initialzier = makeAddr("initialzier");
        marketor = makeAddr("market");

        buyer1 = makeAddr("buyer1");
        vm.startPrank(buyer1);
        vm.deal(buyer1, 1000 ether);
        vm.stopPrank();

        buyer2 = makeAddr("buyer2");
        vm.startPrank(buyer2);
        vm.deal(buyer2, 1000 ether);
        vm.stopPrank();
    }



    function testStake() public {
        vm.startPrank(initialzier);
        BaseToken rnt = new BaseToken("RNT","RNT");
        rnt.mint(1_000_000);
        rnt.transfer(buyer1, 3000);
        rnt.transfer(buyer2, 3000);
        
        RewardToken esrnt = new RewardToken();
        vm.stopPrank();

        vm.startPrank(marketor);
        RNTStake market = new RNTStake(address(rnt), address(esrnt), initialzier);
        vm.stopPrank();

        // initialzier approve to market
        vm.startPrank(initialzier);
        rnt.approve(address(market), 964_000);
        vm.stopPrank();


        vm.startPrank(buyer1);
        vm.expectRevert("stake amount must greater than 0");
        market.stake(0);
        
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(market), 0 , 100));
        market.stake(100);


        rnt.approve(address(market), 10000);
        vm.expectEmit(address(market));
        emit RNTStake.StakeEvent(buyer1, address(market), 100);
        vm.warp(1);
        market.stake(100);
        assertEq(market.balanceOf(buyer1), 100);

        vm.warp(86400 * 1 + 1);
        market.stake(200);
        assertEq(market.balanceOf(buyer1), 300);
        assertEq(market.rewardOf(buyer1), 100);

        vm.warp(86400 * 3 + 1000);
        market.stake(500);
        assertEq(market.balanceOf(buyer1), 800);
        assertEq(market.rewardOf(buyer1), 703);
        vm.stopPrank();
    }



    function testUnstake() public {
        vm.startPrank(initialzier);
        BaseToken rnt = new BaseToken("RNT","RNT");
        rnt.mint(1_000_000);
        rnt.transfer(buyer1, 3000);
        rnt.transfer(buyer2, 3000);
        
        RewardToken esrnt = new RewardToken();
        vm.stopPrank();

        vm.startPrank(marketor);
        RNTStake market = new RNTStake(address(rnt), address(esrnt), initialzier);
        vm.stopPrank();

        // initialzier approve to market
        vm.startPrank(initialzier);
        rnt.approve(address(market), 964_000);
        vm.stopPrank();


        vm.startPrank(buyer1);
        
        rnt.approve(address(market), 10000);
        vm.warp(1);
        market.stake(100);

        vm.warp(86400 * 1 + 1);
        market.stake(200);

        vm.warp(86400 * 3 + 1);
        market.stake(500);


        vm.expectRevert("unstake amount must less than user stake token amount");
        market.unstake(1000);

        vm.warp(86400 * 5 + 1);
        market.unstake(300);
        assertEq(market.balanceOf(buyer1), 500);
        assertEq(market.rewardOf(buyer1), 2298);


        vm.expectEmit(address(market));
        emit RNTStake.UnstakeEvent(buyer1, address(market), 100);
        vm.warp(86400 * 6 + 1);
        market.unstake(100);
        assertEq(market.balanceOf(buyer1), 400);
        assertEq(market.rewardOf(buyer1), 2797);
        vm.stopPrank();
    }


    function testClaim() public {
       vm.startPrank(initialzier);
        BaseToken rnt = new BaseToken("RNT","RNT");
        rnt.mint(1_000_000);
        rnt.transfer(buyer1, 3000);
        rnt.transfer(buyer2, 3000);
        
        RewardToken esrnt = new RewardToken();
        vm.stopPrank();

        vm.startPrank(marketor);
        RNTStake market = new RNTStake(address(rnt), address(esrnt), initialzier);
        vm.stopPrank();

        // initialzier approve to market
        vm.startPrank(initialzier);
        rnt.approve(address(market), 964_000);
        vm.stopPrank();

        vm.startPrank(buyer1);
        rnt.approve(address(market), 10000);
        vm.warp(1);
        market.stake(100);

        // first claim
        vm.warp(86400 * 2 + 100);
        market.claim();
        assertTrue(esrnt.balanceOf(buyer1)/1e18 == 200);

        vm.warp(86400 * 3 + 200);
        market.stake(300);

        // second claim
        vm.expectEmit(address(market));
        emit RNTStake.ClaimRewardEvent(buyer1, address(market), 899);
        vm.warp(86400 * 5 + 100);
        market.claim();

        vm.stopPrank();
    }



    function testGetRewards() public {
        vm.startPrank(initialzier);
        BaseToken rnt = new BaseToken("RNT","RNT");
        rnt.mint(1_000_000);
        rnt.transfer(buyer1, 3000);
        rnt.transfer(buyer2, 3000);
        
        RewardToken esrnt = new RewardToken();
        vm.stopPrank();

        vm.startPrank(marketor);
        RNTStake market = new RNTStake(address(rnt), address(esrnt), initialzier);
        vm.stopPrank();

        // initialzier approve to market
        vm.startPrank(initialzier);
        rnt.approve(address(market), 964_000);
        vm.stopPrank();

        vm.startPrank(buyer1);
        console.log("******",rnt.balanceOf(buyer1));
        vm.expectRevert("User have no claim reward data");
        market.getReward(1);

        // add data
        rnt.approve(address(market), 10000);
        vm.warp(1);
        market.stake(100);

        // first claim
        vm.warp(86400 * 2 + 100);
        market.claim();
        assertTrue(esrnt.balanceOf(buyer1)/1e18 == 200);
        console.log("ESRNT=>", esrnt.balanceOf(buyer1));

        vm.warp(86400 * 3 + 200);
        market.stake(300);

        // second claim
        vm.warp(86400 * 5 + 100);
        market.claim();
        assertTrue(esrnt.balanceOf(buyer1)/1e18 == 1099);
        
        // approve market could burn esrnt
        esrnt.approve(address(market), 10000);

        // test force rewards
        vm.expectEmit(address(market));
        emit RNTStake.GetRewardEvent(buyer1, address(market), 53);
        vm.warp(86400 * 10 + 100);
        market.getReward(1);
        assertTrue(rnt.balanceOf(buyer1) == 2653);
        assertTrue(esrnt.balanceOf(buyer1) == 1098999999999999999853);

        // test liner unlock, after 30 days, the first claim reward could be unlock
        vm.expectEmit(address(market));
        emit RNTStake.GetRewardEvent(buyer1, address(market), 779);
        vm.warp(86400 * 31 + 100);
        market.getReward(2);
        assertEq(rnt.balanceOf(buyer1), 3432);
        assertEq(esrnt.balanceOf(buyer1), 1098999999999999999733);

        // test invalid reward id
        vm.warp(86400 * 32 + 100);
        vm.expectRevert("invalid reward id");
        market.getReward(4);
        vm.stopPrank();
    }
}