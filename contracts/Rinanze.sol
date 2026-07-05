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

    // Supply cap (0 = uncapped)
    uint256 public cap;

    // Events
    event WalletFrozen(address indexed account);
    event WalletUnfrozen(address indexed account);
    event Minted(address indexed to, uint256 amount);
    event NameChanged(string oldName, string newName);
    event SymbolChanged(string oldSymbol, string newSymbol);
    event CapUpdated(uint256 oldCap, uint256 newCap);

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
        __Ownable_init(msg.sender);
        __Ownable2Step_init();
        __AccessControl_init();

        // Set mutable name & symbol
        _name = name_;
        _symbol = symbol_;

        // Grant remaining operational roles to the deployer.
        // DEFAULT_ADMIN_ROLE is granted automatically to msg.sender via the
        // _transferOwnership override below (triggered by __Ownable_init above),
        // so it is intentionally NOT granted again here.
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
        require(cap == 0 || totalSupply() + amount <= cap, "Mint exceeds cap");
        _mint(to, amount);
        emit Minted(to, amount);
    }

    /// @notice Sets the max mintable supply. 0 means uncapped.
    /// @dev Cannot be set below the current total supply.
    function setCap(uint256 newCap) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newCap == 0 || newCap >= totalSupply(), "Cap below current supply");
        uint256 old = cap;
        cap = newCap;
        emit CapUpdated(old, newCap);
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

    // ----- Keep owner as an admin -----
    // Ownable and AccessControl are two independent privilege systems.
    // This override guarantees the owner always holds DEFAULT_ADMIN_ROLE
    // (granted automatically on transfer/accept), while still allowing
    // additional, independent admins to be granted or revoked via the
    // normal grantRole/revokeRole flow below.
    function _transferOwnership(address newOwner) internal override {
        super._transferOwnership(newOwner);

        if (newOwner != address(0)) {
            _grantRole(DEFAULT_ADMIN_ROLE, newOwner);
        }
    }

    // Prevent the current owner from being left without DEFAULT_ADMIN_ROLE.
    // Other admins can still be freely granted/revoked; only the owner's
    // own admin status is protected. To remove the owner as an admin,
    // transfer ownership away first.
    function revokeRole(bytes32 role, address account) public override {
        require(
            !(role == DEFAULT_ADMIN_ROLE && account == owner()),
            "Owner must remain admin; transfer ownership instead"
        );
        super.revokeRole(role, account);
    }
}
