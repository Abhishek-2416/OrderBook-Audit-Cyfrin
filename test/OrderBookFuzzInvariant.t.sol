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
import {StdInvariant} from "forge-std/StdInvariant.sol";

contract OrderBookTest is StdInvariant,Test{
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

    function invariant_deadlineNeverExceedsMax() public {
        
        vm.prank(alice);
        book.createSellOrder(address(wbtc),BTC_AMOUNT,BTC_PRICE,1 days);

        vm.warp(block.timestamp + 3 hours);

        uint256 maxOrderId = book._nextOrderId(); // Replace with _nextOrderId() if public or create a getter

        for (uint256 i = 1; i < maxOrderId; i++) {
        (, , , , , , , uint256 deadline, bool isActive) = book.orders(i);

        if (isActive) {
            // Check invariant conditions
            assert(deadline < book.MAX_DEADLINE_DURATION());
            assert(deadline > block.timestamp); // Optional: if expired orders must not be active
        }
        }
    }

    // function testdeadlineNeverExceedsMaxDeadline(uint256 _newDuration) public {
    //     _newDuration = bound(_newDuration,1 minutes,book.MAX_DEADLINE_DURATION());

    //     vm.prank(alice);
    //     book.createSellOrder(address(wbtc),BTC_AMOUNT,BTC_PRICE,1 days);

    //     (, , , , , , , uint256 originalDeadline, ) = book.orders(1);

    //     vm.warp(block.timestamp + 3 hours);

    //     vm.prank(alice);
    //     book.amendSellOrder(1,BTC_AMOUNT,BTC_PRICE,_newDuration);

    //     (, , , , , , , uint256 amendedDeadline, ) = book.orders(1);

    //     assertLe(amendedDeadline, originalDeadline); // Never exceed original deadline
    //     assertLe(amendedDeadline, block.timestamp + book.MAX_DEADLINE_DURATION()); // Never exceed MAX_DEADLINE_DURATION
    // }
}