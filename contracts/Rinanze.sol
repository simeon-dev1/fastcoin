// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract Rinanze is
    Initializable,
    ERC20Upgradeable,
    ERC20PausableUpgradeable,
    Ownable2StepUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    // Role identifiers
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant FREEZER_ROLE = keccak256("FREEZER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant TRADER_ROLE = keccak256("TRADER_ROLE");

    // Mutable name & symbol
    string private _name;
    string private _symbol;

    // Storage for frozen wallets
    mapping(address => bool) private _frozenWallets;

    // Events
    event WalletFrozen(address indexed account);
    event WalletUnfrozen(address indexed account);
    event Minted(address indexed to, uint256 amount);
    event NameChanged(string oldName, string newName);
    event SymbolChanged(string oldSymbol, string newSymbol);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string calldata name_,
        string calldata symbol_
    ) external initializer {
        __ERC20_init(name_, symbol_);
        __ERC20Pausable_init();
        __Ownable2Step_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        // Set mutable name & symbol
        _name = name_;
        _symbol = symbol_;

        // Grant roles to the owner (deployer)
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(FREEZER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);

        // TRADER_ROLE is intentionally NOT granted – remains false initially
    }

    // ----- Name & Symbol updaters (only owner) -----
    function setName(string calldata newName) external onlyOwner {
        string memory old = _name;
        _name = newName;
        emit NameChanged(old, newName);
    }

    function setSymbol(string calldata newSymbol) external onlyOwner {
        string memory old = _symbol;
        _symbol = newSymbol;
        emit SymbolChanged(old, newSymbol);
    }

    // Override name() and symbol() to use mutable storage
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    // ----- Admin / Role Functions -----
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
        emit Minted(to, amount);
    }

    function freezeWallet(address account) external onlyRole(FREEZER_ROLE) {
        require(!_frozenWallets[account], "Already frozen");
        _frozenWallets[account] = true;
        emit WalletFrozen(account);
    }

    function unfreezeWallet(address account) external onlyRole(FREEZER_ROLE) {
        require(_frozenWallets[account], "Not frozen");
        _frozenWallets[account] = false;
        emit WalletUnfrozen(account);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // ----- Internal Overrides -----
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20Upgradeable, ERC20PausableUpgradeable)
    {
        // 1. Freeze check
        require(!_frozenWallets[from] && !_frozenWallets[to], "Wallet is frozen");

        // 2. Transfer restriction – only for non-mint/burn operations
        if (from != address(0) && to != address(0)) {
            // Sender MUST have TRADER_ROLE
            require(hasRole(TRADER_ROLE, from), "Sender lacks TRADER_ROLE");

            // Receiver must have TRADER_ROLE, EXCEPT if it currently holds 0 tokens
            if (!hasRole(TRADER_ROLE, to)) {
                require(balanceOf(to) == 0, "Receiver has balance but lacks TRADER_ROLE");
            }
        }

        // 3. Let ERC20Pausable handle pause check and actual transfer
        super._update(from, to, value);
    }

    // ----- UUPS Upgrade Authorization (only owner) -----
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}
}
