// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20BurnableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {ERC20PausableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @notice V1: Roles Model implementation of upgradable ERC20 token.
/// This to be used as the initial implementation of UUPS proxy.
/// If an upgrade from V0 to V1 is needed,
/// AnlogTokenV1Upgrade should be used instead.
contract AnlogTokenV1 is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UNPAUSER_ROLE = keccak256("UNPAUSER_ROLE");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address minter, address upgrader, address pauser, address unpauser) public initializer {
        __ERC20_init("Wrapped Analog One Token", "WANLOG");
        __ERC20Burnable_init();
        __ERC20Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(MINTER_ROLE, minter);
        _grantRole(UPGRADER_ROLE, upgrader);
        _grantRole(DEFAULT_ADMIN_ROLE, upgrader);
        _grantRole(PAUSER_ROLE, pauser);
        _grantRole(UNPAUSER_ROLE, unpauser);
    }

    function decimals() public pure override returns (uint8) {
        return 12;
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(UNPAUSER_ROLE) {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20Upgradeable, ERC20PausableUpgradeable)
    {
        super._update(from, to, value);
    }
}
