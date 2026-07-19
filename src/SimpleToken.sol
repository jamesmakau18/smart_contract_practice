// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title SimpleToken - Day 2 practice contract
/// @notice A minimal token implementation (ERC-20-like, but hand-built)
///         teaching: balances, transfers, allowances/approvals,
///         payable vs view vs pure functions, and custom errors.
contract SimpleToken {
    // ── State ──────────────────────────────────────────────

    string public name;
    string public symbol;
    uint256 public totalSupply;
    address public owner;

    // How many tokens each address holds
    mapping(address => uint256) public balanceOf;

    // allowance[owner][spender] = how many tokens `spender` is allowed
    // to move on behalf of `owner`. This is the classic ERC-20 "approve" pattern.
    mapping(address => mapping(address => uint256)) public allowance;

    // ── Custom errors (cheaper on gas than require() strings) ─
    // This is the modern Solidity pattern — worth knowing for interviews.
    error InsufficientBalance(uint256 available, uint256 required);
    error InsufficientAllowance(uint256 available, uint256 required);
    error NotOwner();
    error ZeroAddress();

    // ── Events ─────────────────────────────────────────────
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 amount
    );
    event Minted(address indexed to, uint256 amount);

    // ── Constructor ────────────────────────────────────────
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply
    ) {
        name = _name;
        symbol = _symbol;
        owner = msg.sender;

        // Mint the initial supply directly to the deployer
        totalSupply = _initialSupply;
        balanceOf[msg.sender] = _initialSupply;

        emit Transfer(address(0), msg.sender, _initialSupply);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    // ── Core transfer logic ────────────────────────────────

    /// @notice Move tokens directly from the caller to `to`.
    function transfer(
        address to,
        uint256 amount
    ) public returns (bool success) {
        if (to == address(0)) revert ZeroAddress();

        uint256 senderBalance = balanceOf[msg.sender];
        if (senderBalance < amount) {
            revert InsufficientBalance(senderBalance, amount);
        }

        balanceOf[msg.sender] = senderBalance - amount;
        balanceOf[to] += amount;

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    /// @notice Allow `spender` to move up to `amount` tokens on your behalf.
    /// @dev This does NOT move any tokens itself — it just grants permission.
    function approve(
        address spender,
        uint256 amount
    ) public returns (bool success) {
        if (spender == address(0)) revert ZeroAddress();

        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /// @notice Move tokens from `from` to `to`, using an allowance the
    ///         caller was previously granted via `approve`.
    /// @dev This is how DEXs, marketplaces, and staking contracts move
    ///      YOUR tokens without needing your private key — you approve
    ///      them once, then they call transferFrom on your behalf.
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public returns (bool success) {
        if (to == address(0)) revert ZeroAddress();

        uint256 currentAllowance = allowance[from][msg.sender];
        if (currentAllowance < amount) {
            revert InsufficientAllowance(currentAllowance, amount);
        }

        uint256 fromBalance = balanceOf[from];
        if (fromBalance < amount) {
            revert InsufficientBalance(fromBalance, amount);
        }

        // Spend down the allowance first
        allowance[from][msg.sender] = currentAllowance - amount;

        balanceOf[from] = fromBalance - amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
        return true;
    }

    // ── Owner-only minting ──────────────────────────────────

    /// @notice Owner can mint new tokens to any address.
    function mint(address to, uint256 amount) public onlyOwner {
        if (to == address(0)) revert ZeroAddress();

        totalSupply += amount;
        balanceOf[to] += amount;

        emit Transfer(address(0), to, amount);
        emit Minted(to, amount);
    }

    // ── Function type demonstrations ────────────────────────

    /// @notice A `view` function: reads blockchain state, costs no gas
    ///         when called externally (only costs gas if called from
    ///         inside another transaction).
    function isRich(address account) public view returns (bool) {
        return balanceOf[account] >= 1000 * 10 ** 18;
    }

    /// @notice A `pure` function: touches NO blockchain state at all —
    ///         just pure computation on the inputs you give it.
    ///         Notice it doesn't read balanceOf, totalSupply, anything.
    function calculateFee(
        uint256 amount,
        uint256 feeBasisPoints
    ) public pure returns (uint256 fee) {
        // basis points: 100 = 1%, 250 = 2.5%, etc.
        return (amount * feeBasisPoints) / 10_000;
    }

    /// @notice Example of combining a pure calculation with a real transfer —
    ///         transfers `amount` minus a fee, sending the fee to `feeCollector`.
    function transferWithFee(
        address to,
        uint256 amount,
        address feeCollector,
        uint256 feeBasisPoints
    ) public returns (bool success) {
        uint256 fee = calculateFee(amount, feeBasisPoints);
        uint256 amountAfterFee = amount - fee;

        bool feeSuccess = transfer(feeCollector, fee);
        require(feeSuccess, "Fee transfer failed");

        bool transferSuccess = transfer(to, amountAfterFee);
        require(transferSuccess, "Transfer failed");

        return true;
    }
}
