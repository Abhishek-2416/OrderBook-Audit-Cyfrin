// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 *  ░▒▓██████▓▒░░▒▓███████▓▒░░▒▓███████▓▒░░▒▓████████▓▒░▒▓███████▓▒░       ░▒▓███████▓▒░ ░▒▓██████▓▒░ ░▒▓██████▓▒░░▒▓█▓▒░░▒▓█▓▒░
 * ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░
 * ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░
 * ░▒▓█▓▒░░▒▓█▓▒░▒▓███████▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓██████▓▒░ ░▒▓███████▓▒░       ░▒▓███████▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓███████▓▒░
 * ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░
 * ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░
 *  ░▒▓██████▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓███████▓▒░░▒▓████████▓▒░▒▓█▓▒░░▒▓█▓▒░      ░▒▓███████▓▒░ ░▒▓██████▓▒░ ░▒▓██████▓▒░░▒▓█▓▒░░▒▓█▓▒░
 */
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol"; // For number to string conversion
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol"; 

/**
 * @title OrderBook
 * @author Chukwubuike Victory Chime yeahChibyke @github.com
 * @notice This contract is built to mirror the way order-books operate in TradFi, but on DeFi, as close as possible
 */

/**
 * @dev 🛡️ Reentrancy Protection Explanation:
 *
 * This contract uses OpenZeppelin’s `ReentrancyGuard` to protect functions that interact with
 * external ERC20 tokens. Although this contract does not deal with native ETH transfers (which are
 * a common reentrancy vector), it still interacts with **user-controlled ERC20 contracts**.
 *
 * Reasons for using `nonReentrant`:
 * - ERC20 tokens (especially non-standard or malicious ones) may override `transfer` or `transferFrom`
 *   to include custom logic, such as callbacks or hooks.
 * - These hooks could **reenter** the calling function (`createSellOrder`, `amendSellOrder`, etc.)
 *   before it finishes execution.
 * - Such reentrancy could manipulate internal state like `_nextOrderId`, `orders`, `totalFees`, or
 *   allow unintended logic to run multiple times.
 *
 * Protection Strategy:
 * - All state-changing functions that involve ERC20 `transfer` or `transferFrom` are protected
 *   using `nonReentrant`.
 * - This includes order creation, amendment, cancellation, purchases, fee withdrawal, and emergency token withdrawal.
 *
 * ✅ This ensures that even if a malicious ERC20 is used, it cannot perform recursive attacks
 *    or manipulate the contract’s internal bookkeeping.
 */


contract OrderBook is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Strings for uint256;

    struct Order {
        uint256 id;
        address seller;
        address tokenToSell; // Address of wETH, wBTC, or wSOL
        uint256 amountToSell; // Amount of tokenToSell
        uint256 priceInUSDC; // Total USDC price for the entire amountToSell
        uint256 createdAt; // Block timestamp at which the order was created
        uint256 lastAmendedAt; // Block timestamp of when it was last amended
        uint256 deadlineTimestamp; // Block timestamp after which the order expires
        bool isActive; // Flag indicating if the order is available to be bought
    }

    // --- Constants ---
    uint256 public constant MAX_DEADLINE_DURATION = 3 days; // Max duration from now for a deadline
    uint256 public constant FEE = 3; // 3%
    uint256 public constant PRECISION = 100;
    uint256 public constant COOLDOWN_PERIOD = 1 hours;

    // --- State Variables ---
    IERC20 public immutable iWETH;
    IERC20 public immutable iWBTC;
    IERC20 public immutable iWSOL;
    IERC20 public immutable iUSDC;

    mapping(address => bool) public allowedSellToken;

    mapping(uint256 => Order) public orders;
    uint256 private _nextOrderId;
    uint256 public totalFees;

    // --- Events ---
    event OrderCreated(
        uint256 indexed orderId,
        address indexed seller,
        address indexed tokenToSell,
        uint256 amountToSell,
        uint256 priceInUSDC,
        uint256 createdAt,
        uint256 lastAmendedAt,
        uint256 deadlineTimestamp
    );
    event OrderAmended(
        uint256 indexed orderId, uint256 newAmountToSell, uint256 newPriceInUSDC, uint256 newDeadlineTimestamp
    );
    event OrderCancelled(uint256 indexed orderId, address indexed seller);
    event OrderFilled(uint256 indexed orderId, address indexed buyer, address indexed seller);
    event TokenAllowed(address indexed token, bool indexed status);
    event EmergencyWithdrawal(address indexed token, uint256 indexed amount, address indexed receiver);
    event FeesWithdrawn(address indexed receiver);

    // --- Errors ---
    error OrderNotFound();
    error NotOrderSeller();
    error OrderNotActive();
    error OrderExpired();
    error OrderAlreadyInactive();
    error InvalidToken();
    error InvalidAmount();
    error InvalidPrice();
    error InvalidDeadline();
    error InvalidAddress();
    error DuplicateAddresses();
    error CannotCrossTheMaxDeadline();
    error CooldownInEffect();

    // --- Constructor ---
    constructor(address _weth, address _wbtc, address _wsol, address _usdc, address _owner) Ownable(_owner) {
        if (_weth == address(0) || _wbtc == address(0) || _wsol == address(0) || _usdc == address(0)) {
            revert InvalidToken();
        }

        // Prevent any two of the token parameters from aliasing the same contract:
        // without this, passing the wETH address as both _weth and _wbtc would:
        // 1) log “Sell wBTC” but actually hold wETH,
        // 2) let a buyer pay USDC for BTC and unwittingly receive ETH.
        if (
            _weth == _wbtc || _weth == _wsol || _weth == _usdc ||
            _wbtc == _wsol || _wbtc == _usdc ||
            _wsol == _usdc
        ) {
            revert DuplicateAddresses(); // fail-fast to ensure orders’ symbol and underlying token always match
        }

        if (_owner == address(0)) {
            revert InvalidAddress();
        }

        iWETH = IERC20(_weth);
        allowedSellToken[_weth] = true;

        iWBTC = IERC20(_wbtc);
        allowedSellToken[_wbtc] = true;

        iWSOL = IERC20(_wsol);
        allowedSellToken[_wsol] = true;

        iUSDC = IERC20(_usdc);

        _nextOrderId = 1; // Start order IDs from 1
    }

    /// @notice Creates a new sell order by transferring tokens from seller to the contract
    /// @dev This function is marked `nonReentrant` for the following reasons:
    /// - It calls `safeTransferFrom()` on a user-supplied token address, which may be malicious.
    /// - Some ERC20 tokens (non-standard ones) may have custom `transferFrom` implementations
    ///   that invoke callbacks or external logic during the transfer (e.g., reentrancy hooks).
    /// - A malicious token could use a fallback or hook to recursively call `createSellOrder()`
    ///   again before the current execution completes, resulting in:
    ///     - Incorrect state updates (`_nextOrderId`, `orders` overwritten)
    ///     - Inconsistent contract balance checks
    ///     - Multiple incomplete or invalid orders being created
    /// - Even though no ETH is sent or received, this precaution ensures the contract's
    ///   internal state cannot be manipulated during execution via reentrancy.
    function createSellOrder(
        address _tokenToSell,
        uint256 _amountToSell,
        uint256 _priceInUSDC,
        uint256 _deadlineDuration
    ) public nonReentrant returns (uint256) {
        if (!allowedSellToken[_tokenToSell]) revert InvalidToken();
        if (_amountToSell == 0) revert InvalidAmount();
        if (_priceInUSDC == 0) revert InvalidPrice();
        if (_deadlineDuration == 0 || _deadlineDuration > MAX_DEADLINE_DURATION) revert InvalidDeadline();

        uint256 deadlineTimestamp = block.timestamp + _deadlineDuration;
        uint256 orderId = _nextOrderId++;

        //Check contract balance Before transfer
        uint256 contractTokenBalanceBeforeTransfer = IERC20(_tokenToSell).balanceOf(address(this));

        //Transfer token
        // ⚠️ External call: if token is malicious, it could trigger a reentrant callback here
        IERC20(_tokenToSell).safeTransferFrom(msg.sender, address(this), _amountToSell);

        //Check contract balance After Transfer
        uint256 contractTokenBalanceAfterTransfer = IERC20(_tokenToSell).balanceOf(address(this));

        //The Amount of sell should be difference in balance as there could be hidden transfer Fees
        _amountToSell = contractTokenBalanceAfterTransfer - contractTokenBalanceBeforeTransfer;

        // Store the order
        orders[orderId] = Order({
            id: orderId,
            seller: msg.sender,
            tokenToSell: _tokenToSell,
            amountToSell: _amountToSell,
            priceInUSDC: _priceInUSDC,
            createdAt: block.timestamp,
            lastAmendedAt: block.timestamp,
            deadlineTimestamp: deadlineTimestamp,
            isActive: true
        });

        emit OrderCreated(orderId, msg.sender, _tokenToSell, _amountToSell, _priceInUSDC, block.timestamp,block.timestamp,deadlineTimestamp);
        return orderId;
    }

    function amendSellOrder(
        uint256 _orderId,
        uint256 _newAmountToSell,
        uint256 _newPriceInUSDC,
        uint256 _newDeadlineDuration
    ) public nonReentrant{
        Order storage order = orders[_orderId];

        // Validation checks
        if (order.seller == address(0)) revert OrderNotFound(); // Check if order exists
        if (order.seller != msg.sender) revert NotOrderSeller();
        if (!order.isActive) revert OrderAlreadyInactive();
        if (block.timestamp >= order.deadlineTimestamp) revert OrderExpired(); // Cannot amend expired order
        if (_newAmountToSell == 0) revert InvalidAmount();
        if (_newPriceInUSDC == 0) revert InvalidPrice();
        if (_newDeadlineDuration == 0 || _newDeadlineDuration > MAX_DEADLINE_DURATION) revert InvalidDeadline();
        if (block.timestamp < order.lastAmendedAt + COOLDOWN_PERIOD) revert CooldownInEffect();

        IERC20 token = IERC20(order.tokenToSell);

        uint256 newExpiry = block.timestamp + _newDeadlineDuration;
        require(newExpiry <= order.createdAt + MAX_DEADLINE_DURATION, CannotCrossTheMaxDeadline()); 

        // Handle token amount changes
        if (_newAmountToSell > order.amountToSell) {
            // Increasing amount: Transfer additional tokens from seller
            uint256 contractBalanceBefore = IERC20(order.tokenToSell).balanceOf(address(this));
            uint256 diff = _newAmountToSell - order.amountToSell;
            token.safeTransferFrom(msg.sender, address(this), diff);
            uint256 contractBalanceAfter = IERC20(order.tokenToSell).balanceOf(address(this));
            _newAmountToSell = contractBalanceAfter - contractBalanceBefore;
        } else if (_newAmountToSell < order.amountToSell) {
            // Decreasing amount: Transfer excess tokens back to seller
            uint256 diff = order.amountToSell - _newAmountToSell;
            token.safeTransfer(order.seller, diff);
        }

        // Update order details
        order.amountToSell = _newAmountToSell;
        order.priceInUSDC = _newPriceInUSDC;

        //Deadline refresh can be abused
        order.deadlineTimestamp = newExpiry;

        // update the last amended time
        order.lastAmendedAt = block.timestamp;

        emit OrderAmended(_orderId, _newAmountToSell, _newPriceInUSDC, newExpiry);
    }

    function cancelSellOrder(uint256 _orderId) public nonReentrant {
        Order storage order = orders[_orderId];

        // Validation checks
        if (order.seller == address(0)) revert OrderNotFound();
        if (order.seller != msg.sender) revert NotOrderSeller();
        if (!order.isActive) revert OrderAlreadyInactive(); // Already inactive (filled or cancelled)

        // Mark as inactive
        order.isActive = false;

        // Return locked tokens to the seller
        IERC20(order.tokenToSell).safeTransfer(order.seller, order.amountToSell);

        emit OrderCancelled(_orderId, order.seller);
    }

    function buyOrder(uint256 _orderId) public nonReentrant{
        Order storage order = orders[_orderId];

        // Validation checks
        if (order.seller == address(0)) revert OrderNotFound();
        if (!order.isActive) revert OrderNotActive();
        if (block.timestamp >= order.deadlineTimestamp) revert OrderExpired();

        order.isActive = false;
        uint256 protocolFee = (order.priceInUSDC * FEE) / PRECISION;
        uint256 sellerReceives = order.priceInUSDC - protocolFee;

        iUSDC.safeTransferFrom(msg.sender, address(this), protocolFee);
        iUSDC.safeTransferFrom(msg.sender, order.seller, sellerReceives);
        IERC20(order.tokenToSell).safeTransfer(msg.sender, order.amountToSell);

        totalFees += protocolFee;

        emit OrderFilled(_orderId, msg.sender, order.seller);
    }

    function getOrder(uint256 _orderId) public view returns (Order memory orderDetails) {
        if (orders[_orderId].seller == address(0)) revert OrderNotFound();
        orderDetails = orders[_orderId];
    }

    function getOrderDetailsString(uint256 _orderId) public view returns (string memory details) {
        Order storage order = orders[_orderId];
        if (order.seller == address(0)) revert OrderNotFound(); // Check if order exists

        string memory tokenSymbol;
        if (order.tokenToSell == address(iWETH)) {
            tokenSymbol = "wETH";
        } else if (order.tokenToSell == address(iWBTC)) {
            tokenSymbol = "wBTC";
        } else if (order.tokenToSell == address(iWSOL)) {
            tokenSymbol = "wSOL";
        }

        string memory status = order.isActive
            ? (block.timestamp < order.deadlineTimestamp ? "Active" : "Expired (Active but past deadline)")
            : "Inactive (Filled/Cancelled)";
        if (order.isActive && block.timestamp >= order.deadlineTimestamp) {
            status = "Expired (Awaiting Cancellation)";
        } else if (!order.isActive) {
            status = "Inactive (Filled/Cancelled)";
        } else {
            status = "Active";
        }

        details = string(
            abi.encodePacked(
                "Order ID: ",
                order.id.toString(),
                "\n",
                "Seller: ",
                Strings.toHexString(uint160(order.seller), 20),
                "\n",
                "Selling: ",
                order.amountToSell.toString(),
                " ",
                tokenSymbol,
                "\n",
                "Asking Price: ",
                order.priceInUSDC.toString(),
                " USDC\n",
                "Deadline Timestamp: ",
                order.deadlineTimestamp.toString(),
                "\n",
                "Status: ",
                status
            )
        );

        return details;
    }

    function setAllowedSellToken(address _token, bool _isAllowed) external onlyOwner {
        if (_token == address(0) || _token == address(iUSDC)) revert InvalidToken(); // Cannot allow null or USDC itself
        allowedSellToken[_token] = _isAllowed;

        emit TokenAllowed(_token, _isAllowed);
    }

    function emergencyWithdrawERC20(address _tokenAddress, uint256 _amount, address _to) external nonReentrant onlyOwner {
        if (
            _tokenAddress == address(iWETH) || _tokenAddress == address(iWBTC) || _tokenAddress == address(iWSOL)
                || _tokenAddress == address(iUSDC)
        ) {
            revert("Cannot withdraw core order book tokens via emergency function");
        }
        if (_to == address(0)) {
            revert InvalidAddress();
        }
        IERC20 token = IERC20(_tokenAddress);
        token.safeTransfer(_to, _amount);

        emit EmergencyWithdrawal(_tokenAddress, _amount, _to);
    }

    function withdrawFees(address _to) external nonReentrant onlyOwner {
        if (totalFees == 0) {
            revert InvalidAmount();
        }
        if (_to == address(0)) {
            revert InvalidAddress();
        }

        iUSDC.safeTransfer(_to, totalFees);

        totalFees = 0;

        emit FeesWithdrawn(_to);
    }
}
