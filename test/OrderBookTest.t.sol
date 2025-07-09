//Abhishek
// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import {OrderBook} from "../src/OrderBook.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";
import {MockWBTC} from "./mocks/MockWBTC.sol";
import {MockWETH} from "./mocks/MockWETH.sol";
import {MockWSOL} from "./mocks/MockWSOL.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract OrderBookTest is Test{
    OrderBook book;

    MockUSDC usdc = new MockUSDC(6);
    MockWBTC wbtc = new MockWBTC(8);
    MockWETH weth = new MockWETH(18);
    MockWSOL wsol = new MockWSOL(18);

    address owner = makeAddr("owner");
    address alice = makeAddr("will_sell_wbtc_order");
    address bob = makeAddr("will_sell_weth_order");
    address clara = makeAddr("will_sell_wsol_order");
    address dan = makeAddr("will_buy_orders");

    uint256 MAX_DEADLINE_DURATION;

    uint256 immutable BTC_PRICE = 100_000;
    uint256 immutable BTC_AMOUNT = 1e8;

    uint256 immutable ETH_PRICE = 2000;
    uint256 immutable ETH_AMOUNT = 1e18; 

    function setUp() public {
        book = new OrderBook(address(weth), address(wbtc), address(wsol), address(usdc), owner);

        //Minting tokens
        usdc.mint(dan, 200_000);
        vm.prank(dan);
        usdc.approve(address(book),200_000);

        wbtc.mint(alice, 2);
        vm.prank(alice);
        wbtc.approve(address(book),2e8);

        weth.mint(bob, 2);
        vm.prank(bob);
        weth.approve(address(book),2e18);

        wsol.mint(clara, 2);
        vm.prank(clara);
        wsol.approve(address(book),2e18);

        MAX_DEADLINE_DURATION = book.MAX_DEADLINE_DURATION();
    }

    function testCannotSubmitSameTokens() external {
        vm.prank(owner);
        vm.expectRevert(OrderBook.DuplicateAddresses.selector);
        OrderBook _book2 = new OrderBook(address(weth), address(wbtc), address(wbtc), address(usdc), owner);
        _book2;
    }

    // Create Sell order
    function testCannotPassInInvalidTokens() external {
        vm.prank(alice);
        vm.expectRevert(OrderBook.InvalidToken.selector);
        book.createSellOrder(makeAddr("Corrupt Token"),1e18,BTC_PRICE,2 days);
    }

    function testAmountToSellCannotBeZero() external {
        vm.prank(alice);
        vm.expectRevert(OrderBook.InvalidAmount.selector);
        book.createSellOrder(address(wbtc),0,BTC_PRICE,2 days);
    }

    function testPriceCannotBeZero() external {
        vm.prank(alice);
        vm.expectRevert(OrderBook.InvalidPrice.selector);
        book.createSellOrder(address(wbtc),1e8,0,2 days);
    }

    function testDurationCannotBeZeroOrCannotExceedMaxDeadline() external {
        vm.prank(alice);
        vm.expectRevert(OrderBook.InvalidDeadline.selector);
        book.createSellOrder(address(wbtc),BTC_AMOUNT,BTC_PRICE,0 days);

        vm.prank(alice);
        vm.expectRevert(OrderBook.InvalidDeadline.selector);
        book.createSellOrder(address(wbtc),BTC_AMOUNT,BTC_PRICE,4 days);
    }

    modifier createBasicSellOrder {
        vm.prank(alice);
        book.createSellOrder(address(wbtc),BTC_AMOUNT,BTC_PRICE,2 days);

        vm.warp(block.timestamp + 3 hours);
        _;
    }

    function testTheBookContractGetTheToken() external {
        assertEq(IERC20(wbtc).balanceOf(address(book)),0);

        vm.prank(alice);
        book.createSellOrder(address(wbtc),BTC_AMOUNT,BTC_PRICE,2 days);

        assertEq(IERC20(wbtc).balanceOf(address(book)),BTC_AMOUNT);        
    }

    // Amend Order
    function testCannotAmmendOthersSellOrders() external {
        vm.prank(alice);
        book.createSellOrder(address(wbtc),BTC_AMOUNT,BTC_PRICE,2 days);
        
        vm.prank(bob);
        vm.expectRevert(OrderBook.NotOrderSeller.selector);
        book.amendSellOrder(1,BTC_AMOUNT,BTC_PRICE,1 days);
    }

    function testCannotAmendOnceOrderIsExpired() createBasicSellOrder external {
        vm.warp(block.timestamp + 2 days);

        vm.prank(alice);
        vm.expectRevert(OrderBook.OrderExpired.selector);
        book.amendSellOrder(1,BTC_AMOUNT,BTC_PRICE,1 days);
    }

    function testCannotSetNewParameterToZero() createBasicSellOrder external {
        vm.prank(alice);
        vm.expectRevert(OrderBook.InvalidAmount.selector);
        book.amendSellOrder(1,0,BTC_PRICE,1 days);

        vm.prank(alice);
        vm.expectRevert(OrderBook.InvalidPrice.selector);
        book.amendSellOrder(1,BTC_AMOUNT,0,1 days);

        vm.prank(alice);
        vm.expectRevert(OrderBook.InvalidDeadline.selector);
        book.amendSellOrder(1,BTC_AMOUNT,BTC_PRICE,0 days);
    }

    function testCannotAmendOrderWhileInCoolDownPeriod() createBasicSellOrder external {
        vm.warp(block.timestamp + 3 hours);

        vm.prank(alice);
        book.amendSellOrder(1,BTC_AMOUNT,BTC_PRICE,1 days);

        vm.warp(block.timestamp + 30 minutes);

        vm.prank(alice);
        vm.expectRevert(OrderBook.CooldownInEffect.selector);
        book.amendSellOrder(1,BTC_AMOUNT,BTC_PRICE,1 days);
    }

    function testTheNewDeadlineAlwaysStaysBelowTheOriginalThreeDaysTimeline() createBasicSellOrder external {
        console2.log(book.getOrderDetailsString(1));

        // vm.prank(alice);
        // book.amendSellOrder(1, BTC_AMOUNT, BTC_PRICE, 1 days);

        console2.log(book.getOrderDetailsString(1));

        vm.warp(block.timestamp + 1 days);
        vm.prank(alice);
        vm.expectRevert(OrderBook.CannotCrossTheMaxDeadline.selector);
        book.amendSellOrder(1,BTC_AMOUNT,BTC_PRICE,2 days);
    }

    function testTheSellerReceivesAmountIfLessThanBefore() createBasicSellOrder external {
        assertEq(IERC20(wbtc).balanceOf(address(book)),BTC_AMOUNT);
        vm.prank(alice);
        book.amendSellOrder(1,1e4,BTC_PRICE,1 days);
        assertLe(IERC20(wbtc).balanceOf(address(book)),BTC_AMOUNT);
        assertEq(IERC20(wbtc).balanceOf(address(book)),10_00_10_000);
    }

    function testTheFullLifecycle() external {
        vm.prank(alice);
        book.createSellOrder(address(wbtc),1e8,50_000,2 days);

        vm.prank(bob); 
        book.createSellOrder(address(weth),1 ether,1500,1 days);

        console2.log();
    }
}