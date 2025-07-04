//Abhishek
// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import {OrderBook} from "../src/OrderBook.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";
import {MockWBTC} from "./mocks/MockWBTC.sol";
import {MockWETH} from "./mocks/MockWETH.sol";
import {MockWSOL} from "./mocks/MockWSOL.sol";

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

    function setUp() public {
        book = new OrderBook(address(weth), address(wbtc), address(wsol), address(usdc), owner);

        //Minting tokens
        usdc.mint(dan, 200_000);

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

    function testTransferChargesFeesWhenCreateSellOrder() external {
        uint256 contractWBTCBalanceBefore = MockWBTC(wbtc).balanceOf(address(book));
        vm.prank(alice);
        book.createSellOrder(address(wbtc),1e8,10 ether,2 days);
        uint256 contractWBTCBalanceAfter = MockWBTC(wbtc).balanceOf(address(book));
        console2.log(contractWBTCBalanceBefore);
        console2.log(contractWBTCBalanceAfter);
        console2.log("Alice Balance After Transfer:",MockWBTC(wbtc).balanceOf(alice));

        console2.log(book.getOrderDetailsString(1));
        vm.warp(block.timestamp + 3 days);
        console2.log(book.getOrderDetailsString(1));
    }
}