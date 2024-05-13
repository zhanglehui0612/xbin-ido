// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {Test, console} from "forge-std/Test.sol";
import {RntIDO} from "../src/ido/RntIDO.sol";
import {BaseToken} from "../src/token/BaseToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract RntIDOTest is Test {
    address rntOwner;
    address buyer;
    address buyer1;

    function setUp() public {
        buyer = makeAddr("buyer");
        vm.startPrank(buyer);
        vm.deal(buyer, 1000 ether);
        vm.stopPrank();

        buyer1 = makeAddr("buyer1");
        vm.startPrank(buyer1);
        vm.deal(buyer1, 1000 ether);
        vm.stopPrank();
    }

    function testPresale() public {
        address rntOwner = makeAddr("RNTIDO");
        vm.startPrank(rntOwner);
        BaseToken rnt = new BaseToken("RNT", "RNT");
        vm.warp(1715380188);
        RntIDO rntIDO = new RntIDO(address(rnt));
        vm.stopPrank();

        vm.startPrank(address(rntIDO));
        rnt.mint(100000);
        vm.stopPrank();
        vm.roll(10000);

        vm.startPrank(buyer);

        vm.expectRevert("Presale amount must greater than 0");
        vm.warp(1715380189);
        rntIDO.presale(0);

        vm.expectRevert("Presale eth must equal to amount * price");
        rntIDO.presale{value: 0.1 ether}(1000);

        rntIDO.presale{value: 1 ether}(1000);
        assertTrue(rntIDO.getTotalSold() == 1000);
        assertTrue(rntIDO.getTotalRaised() == 1 ether);
        assertTrue(buyer.balance == 999 ether);

        vm.expectRevert("Presale haved raise max funding, stop presale");
        vm.warp(1715380190);
        rntIDO.presale{value: 100 ether}(100000);
        vm.stopPrank();

        rntIDO.presale{value: 99 ether}(99000);
        vm.stopPrank();
    }

    function testRefund() public {
        address rntOwner = makeAddr("RNTIDO");
        vm.startPrank(rntOwner);
        BaseToken rnt = new BaseToken("RNT", "RNT");
        vm.warp(1715380188);
        RntIDO rntIDO = new RntIDO(address(rnt));
        vm.stopPrank();

        vm.startPrank(address(rntIDO));
        rnt.mint(100000);
        vm.stopPrank();
        vm.roll(10000);

        vm.startPrank(buyer);
        vm.expectRevert(abi.encodeWithSelector(RntIDO.PreSaleNotEnd.selector));
        rntIDO.refund();

        vm.expectRevert("User have no any amount, can not refund");
        vm.warp(1716157788);
        rntIDO.refund();
        vm.stopPrank();

        vm.warp(1715380188);
        rntIDO.presale{value: 1 ether}(1000);
        vm.expectRevert(
            abi.encodeWithSelector(RntIDO.FailToRefundUser.selector)
        );
        vm.warp(1716157788);
        rntIDO.refund();

        vm.warp(1715380188);
        rntIDO.presale{value: 20 ether}(20000);
        vm.expectRevert(abi.encodeWithSelector(RntIDO.NotAllowRefund.selector));
        vm.warp(1716157788);
        rntIDO.refund();
    }

    function testClaim() public {
        address rntOwner = makeAddr("RNTIDO");
        vm.startPrank(rntOwner);
        BaseToken rnt = new BaseToken("RNT", "RNT");
        vm.warp(1715380188);
        RntIDO rntIDO = new RntIDO(address(rnt));
        vm.stopPrank();

        vm.startPrank(address(rntIDO));
        rnt.mint(100000);
        vm.stopPrank();

        vm.startPrank(buyer);
        vm.expectRevert(abi.encodeWithSelector(RntIDO.PreSaleNotEnd.selector));
        rntIDO.claim();

        vm.expectRevert(
            abi.encodeWithSelector(RntIDO.NotRaiseMinFunding.selector)
        );
        vm.warp(1716157788);
        rntIDO.claim();
        vm.stopPrank();

        vm.startPrank(buyer1);
        vm.warp(1715380188);
        rntIDO.presale{value: 30 ether}(30000);
        vm.stopPrank();

        vm.startPrank(buyer);
        vm.warp(1715380188);
        rntIDO.presale{value: 10 ether}(10000);
        vm.warp(1716157788);
        rntIDO.claim();
        assertTrue(rntIDO.balanceOf(buyer) == 0);
        assertTrue(rnt.balanceOf(address(rntIDO)) == 99990000000000000000000);
        vm.stopPrank();
    }

    function testWithDraw() public {
        address rntOwner = makeAddr("RNTIDO");
        vm.startPrank(rntOwner);
        BaseToken rnt = new BaseToken("RNT", "RNT");
        vm.warp(1715380188);
        RntIDO rntIDO = new RntIDO(address(rnt));
        vm.stopPrank();

        vm.startPrank(address(rntIDO));
        rnt.mint(100000);
        vm.stopPrank();

        vm.startPrank(rntOwner);
        vm.expectRevert(abi.encodeWithSelector(RntIDO.PreSaleNotEnd.selector));
        rntIDO.withdraw();

        vm.warp(1716157788);
        vm.expectRevert(
            abi.encodeWithSelector(RntIDO.NotRaiseMinFunding.selector)
        );
        rntIDO.withdraw();
        vm.stopPrank();

        vm.startPrank(buyer1);
        vm.warp(1715380188);
        rntIDO.presale{value: 30 ether}(30000);
        vm.stopPrank();

        vm.startPrank(buyer);
        vm.warp(1715380188);
        rntIDO.presale{value: 10 ether}(10000);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                buyer
            )
        );
        rntIDO.withdraw();
        vm.stopPrank();

        vm.startPrank(rntOwner);
        vm.warp(1716157788);
        rntIDO.withdraw();
        vm.stopPrank();
    }
}
