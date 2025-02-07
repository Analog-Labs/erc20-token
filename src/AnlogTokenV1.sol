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
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IGmpReceiver} from "@analog-gmp/interfaces/IGmpReceiver.sol";
import {IGateway} from "@analog-gmp/interfaces/IGateway.sol";

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
    UUPSUpgradeable,
    IGmpReceiver
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UNPAUSER_ROLE = keccak256("UNPAUSER_ROLE");

    /**
     * @dev Length of `OutboundTeleportCommand` struct encoded in bytes.
     * ```
     * uint256 messageLength = abi.encode(OutboundTeleportCommand({from: address(0), to: bytes32(0), amount: 0})).length;
     * ```
     */
    uint256 public constant TELEPORT_COMMAND_ENCODED_LEN = 96;

    /**
     * @dev Minimun gas limit necessary to execute the `onGmpReceived` method defined in this contract.
     */
    uint256 public constant INBOUND_TRANSFER_GAS_LIMIT = 100_000;

    /**
     * @dev Address of Analog Gateway deployed in the local network, work as "broker" to exchange messages,
     *      between this contract and the Timechain.
     *
     * References:
     * - Protocol Overview: https://docs.analog.one/documentation/developers/analog-gmp
     * - Gateway source-code: https://github.com/Analog-Labs/analog-gmp
     */
    IGateway public immutable GATEWAY;

    /**
     * @dev Address of the contract or pallet that will handle the GMP message in the remote network.
     */
    address public immutable REMOTE_ADDRESS;

    /**
     * @dev Timechain's Route ID, this is the unique identifier of Timechain's network.
     */
    uint16 public immutable TIMECHAIN_ROUTE_ID;

    /**
     * @dev Minimal quantity of tokens allowed per teleport.
     *
     * IMPORTANT: This value MUST be equal or greater than the timechain's existential deposit.
     * see: https://github.com/paritytech/polkadot-sdk/blob/polkadot-v1.17.1/substrate/frame/balances/README.md?plain=1#L24-L29
     */
    uint256 public immutable MINIMAL_TELEPORT_VALUE;

    /**
     * @dev Emitted when `amount` tokens are teleported from `source` account in the local network to `recipient` in Timechain.
     */
    event OutboundTransfer(bytes32 indexed id, address indexed source, bytes32 indexed recipient, uint256 amount);

    /**
     * @dev @dev Emitted when `amount` tokens are teleported from `source` in Timechain to `recipient` in the local network.
     */
    event InboundTransfer(bytes32 indexed id, bytes32 indexed source, address indexed recipient, uint256 amount);

    /**
     * @dev One or more preconditions of `onGmpReceived` method failed.
     */
    error Unauthorized();

    /**
     * @dev Command encoded in the `data` field on the `onGmpReceived` method, representing a teleport from Timechain to the local network.
     * @param from Timechain's account teleporting the tokens.
     * @param to Local account receing the tokens.
     * @param amount The amount of tokens teleported.
     */
    struct InboundTeleportCommand {
        bytes32 from;
        address to;
        uint256 amount;
    }

    /**
     * @dev Command that that teleports tokens from the local network to the Timechain.
     * @param from Account in the local network teleporting the tokens.
     * @param to Account in Timechain receing the tokens.
     * @param amount The amount of tokens to teleport.
     */
    struct OutboundTeleportCommand {
        address from;
        bytes32 to;
        uint256 amount;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address gateway, address remoteAddr, uint16 timechainId, uint256 minimalTeleport) {
        require(gateway.code.length > 0, "Gateway address is not a contract");
        require(IGateway(gateway).networkId() != timechainId, "local network and Timechain must be different networks");
        GATEWAY = IGateway(gateway);
        REMOTE_ADDRESS = remoteAddr;
        TIMECHAIN_ROUTE_ID = timechainId;
        MINIMAL_TELEPORT_VALUE = minimalTeleport;
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

    /**
     * @dev The following functions are overrides required by Solidity.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20Upgradeable, ERC20PausableUpgradeable)
    {
        super._update(from, to, value);
    }

    /**
     * @dev Workaround for EVM compatibility, in some chains like `Astar` where `address(this).balance` can
     *      be less than `msg.value` if this contract has no previous existential deposit.
     * Reference:
     * - https://github.com/polkadot-evm/frontier/blob/polkadot-v1.11.0/ts-tests/tests/test-balance.ts#L41
     */
    function _msgValue() private view returns (uint256) {
        return Math.min(msg.value, address(this).balance);
    }

    /**
     * @dev Teleport a `value` amount of tokens from the caller's account in the local chain to `to`
     * account in the Timechain.
     *
     * Returns the GMP message identifier.
     *
     * Requirements:
     * - `to` cannot be the zero address.
     * - `value` must be equal or greater than `MINIMAL_TELEPORT_VALUE`.
     * - the caller must have a balance of at least `value`.
     *
     * Emits a {OutboundTransfer} event.
     */
    function teleport(bytes32 to, uint256 value) external payable returns (bytes32 messageID) {
        return _teleportFrom(_msgSender(), to, value);
    }

    /**
     * @dev Teleports a `value` amount of tokens from `from` account in the local chain to `to` account
     * in the Timechain using the allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns the GMP message identifier.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `value`.
     * - `value` must be equal or greater than `MINIMAL_TELEPORT_VALUE`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `value`.
     *
     * Emits a {OutboundTransfer} event.
     */
    function teleportFrom(address from, bytes32 to, uint256 value) external payable returns (bytes32 messageID) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        return _teleportFrom(from, to, value);
    }

    /**
     * @dev Teleports a `value` amount of tokens from `from` account in the local chain to `to` account
     * in the Timechain.
     *
     * Requirements:
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `value`.
     * - `value` must be equal or greater than `MINIMAL_TELEPORT_VALUE`.
     *
     * Emits a {OutboundTransfer} event.
     */
    function _teleportFrom(address from, bytes32 to, uint256 value) private returns (bytes32 messageID) {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        require(value >= MINIMAL_TELEPORT_VALUE, "value below minimum required");
        _burn(from, value);
        bytes memory message = abi.encode(OutboundTeleportCommand({from: from, to: to, amount: value}));
        messageID = GATEWAY.submitMessage{value: _msgValue()}(
            address(REMOTE_ADDRESS), TIMECHAIN_ROUTE_ID, INBOUND_TRANSFER_GAS_LIMIT, message
        );
        emit OutboundTransfer(messageID, from, to, value);
    }

    /**
     * @dev Estimate the teleport cost in native tokens, the returned is the amount of ether to send to `teleport` method.
     */
    function estimateTeleportCost() public view returns (uint256) {
        return GATEWAY.estimateMessageCost(TIMECHAIN_ROUTE_ID, TELEPORT_COMMAND_ENCODED_LEN, INBOUND_TRANSFER_GAS_LIMIT);
    }

    /**
     * @dev Handles the receipt of a single GMP message.
     * The contract must verify the msg.sender, it must be the Gateway Contract address.
     *
     * @param id The global unique identifier of the message.
     * @param network The unique identifier of the source chain who send the message
     * @param source The pubkey/address of who sent the GMP message
     * @param payload The message payload with no specified format
     * @return 32 byte result which will be stored together with GMP message
     *
     * * Requirements:
     * - the caller must be the `GATEWAY` contract.
     * - `network` must be the `TIMECHAIN_ROUTE_ID`.
     * - `source` must be the `REMOTE_ADDRESS`.
     * - `payload` must be the struct `InboundTeleportCommand` encoded.
     *
     * Emits a {InboundTransfer} event.
     */
    function onGmpReceived(bytes32 id, uint128 network, bytes32 source, bytes calldata payload)
        external
        payable
        returns (bytes32)
    {
        // Check preconditions
        require(msg.sender == address(GATEWAY), Unauthorized());
        require(network == TIMECHAIN_ROUTE_ID, Unauthorized());
        require(source == bytes32(uint256(uint160(REMOTE_ADDRESS))), Unauthorized());

        // Decode the command
        InboundTeleportCommand memory command = abi.decode(payload, (InboundTeleportCommand));

        // Mint the tokens to the recipient account
        if (command.to != address(0) && command.amount > 0) {
            _mint(command.to, command.amount);
        }
        emit InboundTransfer(id, command.from, command.to, command.amount);

        // Returns the current total supply as result, the result is included in the `GmpExecuted` event
        // emitted by the gateway. It allows the Timechain to verify if the amount of tokens locked matches
        // the total supply of this contract.
        return bytes32(totalSupply());
    }
}
