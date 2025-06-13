// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20BurnableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {ERC20PausableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {ERC20CappedUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20CappedUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IGmpReceiver} from "gmp-2.0.0/src/IGmpReceiver.sol";
import {IGateway} from "gmp-2.0.0/src/IGateway.sol";
import {ISenderCaller, ISender, ICallee, Utils} from "@oats/IOATS.sol";

/// @notice V2: OATS-compatible Wrapped Analog ERC20 token.
/// @custom:oz-upgrades-from AnlogTokenV1
contract AnlogTokenV2 is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    IGmpReceiver,
    ISenderCaller,
    ISender,
    ERC20CappedUpgradeable
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UNPAUSER_ROLE = keccak256("UNPAUSER_ROLE");

    uint256 constant TRANSFER_CMD_SIZE = 96;
    uint64 constant TRANSFER_GAS_LIMIT = 100_000;
    /**
     * @dev Address of Analog Gateway deployed in the local network, work as a "broker" to exchange messages
     *      between this contract and the Timechain.
     *
     * @notice we store it in immutable, making it part of implementation code, and not the state.
     * Thus changing this value would require an upgrade, and shuold be done in implementation
     * contract's constructor.
     *
     * References:
     * - Protocol Overview: https://docs.analog.one/documentation/developers/analog-gmp
     * - Gateway source code: https://github.com/Analog-Labs/analog-gmp
     */
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IGateway public immutable GATEWAY;
    /// @dev OATS: Supported networks with token contract addresses
    mapping(uint16 => address) public networks;

    /// @dev OATS x-chain transfer command
    struct TransferCmd {
        address from;
        address to;
        uint256 amount;
        address callee;
        bytes caldata;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address gateway) {
        GATEWAY = IGateway(gateway);
        _disableInitializers();
    }

    /// @custom:oz-upgrades-validate-as-initializer
    function initialize(address minter, address upgrader, address pauser, address unpauser, uint256 cap)
        public
        reinitializer(2)
    {
        __ERC20_init("Wrapped Analog One Token", "WANLOG");
        __ERC20Burnable_init();
        __ERC20Pausable_init();
        __ERC20Capped_init(cap);
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
        override(ERC20Upgradeable, ERC20PausableUpgradeable, ERC20CappedUpgradeable)
    {
        super._update(from, to, value);
    }

    /// @dev OATS: Set supported network
    function set_network(uint16 networkId, address token) public onlyRole(UPGRADER_ROLE) {
        networks[networkId] = token;
    }

    /// @inheritdoc ISender
    function cost(uint16 networkId) external view returns (uint256) {
        return GATEWAY.estimateMessageCost(networkId, TRANSFER_CMD_SIZE, TRANSFER_GAS_LIMIT);
    }

    /// @inheritdoc ISenderCaller
    function cost(uint16 networkId, uint64 gasLimit, bytes memory caldata) external view returns (uint256) {
        TransferCmd memory Default;
        Default.caldata = caldata;
        bytes memory message = abi.encode(Default);

        return GATEWAY.estimateMessageCost(networkId, message.length, gasLimit);
    }

    /// @inheritdoc ISender
    function send(uint16 networkId, address recipient, uint256 amount) external payable returns (bytes32 msgId) {
        bytes memory empty;
        return _sendAndCall(networkId, recipient, amount, TRANSFER_GAS_LIMIT, address(0), empty);
    }

    /// @inheritdoc ISenderCaller
    function sendAndCall(
        uint16 networkId,
        address recipient,
        uint256 amount,
        uint64 gasLimit,
        address callee,
        bytes memory caldata
    ) external payable returns (bytes32 msgId) {
        return _sendAndCall(networkId, recipient, amount, gasLimit, callee, caldata);
    }

    function _sendAndCall(
        uint16 networkId,
        address recipient,
        uint256 amount,
        uint64 gasLimit,
        address callee,
        bytes memory caldata
    ) private returns (bytes32 msgId) {
        address targetToken = networks[networkId];
        require(targetToken != address(0), Utils.UnknownToken(targetToken));

        _burn(msg.sender, amount);

        bytes memory message =
            abi.encode(TransferCmd({from: msg.sender, to: recipient, amount: amount, callee: callee, caldata: caldata}));

        return GATEWAY.submitMessage{value: msg.value}(targetToken, networkId, gasLimit, message);
    }

    /**
     * @dev Handles the receipt of a single GMP message.
     * The contract must verify the msg.sender, it must be the Gateway Contract address.
     *
     * @param id The global unique identifier of the message.
     * @param networkId The unique identifier of the source chain who send the message
     * @param data The message payload with no specified format
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
    function onGmpReceived(bytes32 id, uint128 networkId, bytes32 source, uint64, bytes calldata data)
        external
        payable
        returns (bytes32)
    {
        // Check preconditions
        require(msg.sender == address(GATEWAY), Utils.UnauthorizedGW(msg.sender));
        require(
            networks[uint16(networkId)] == address(uint160(uint256(source))), Utils.UnknownNetwork(uint16(networkId))
        );
        TransferCmd memory cmd = abi.decode(data, (TransferCmd));

        _mint(cmd.to, cmd.amount);

        // Make callback if needed
        if (cmd.callee != address(0)) {
            if (cmd.callee.code.length == 0) {
                emit Utils.InvalidCallee(cmd.callee);
            } else {
                try ICallee(cmd.callee).onTransferReceived(cmd.from, cmd.to, cmd.amount, cmd.caldata) {
                    emit Utils.CallSucceed();
                } catch {
                    emit Utils.CallFailed();
                }
            }
        }

        return id;
    }
}
