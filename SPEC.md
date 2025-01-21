# `AnlogTokenV1` Tech Spec 

## ERC20

### Basic Config 

1. **Token name**: `"Analog One Token"`.
2. **Token ticker**: `"ANLOG"`.
3. **Token decimals**: `18`.
4. **Pre-minted amount**: `0`.

### Extensions 

+ [ERC20PausableUpgradeable](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/fa525310e45f91eb20a6d3baa2644be8e0adba31/contracts/token/ERC20/extensions/ERC20PausableUpgradeable.sol#L23)
+ [ERC20BurnableUpgradeable](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/fa525310e45f91eb20a6d3baa2644be8e0adba31/contracts/token/ERC20/extensions/ERC20BurnableUpgradeable.sol#L15)

## Access Model 

Each of the Roles defined below should be assigned to a single account upon contract initialization.

Implementation should be based on the [AccessControlUpgradeable](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/fa525310e45f91eb20a6d3baa2644be8e0adba31/contracts/access/AccessControlUpgradeable.sol#L50) (OpenZeppelin).

### Roles 

+ **MINTER_ROLE**  
  Allowed actions: mint new tokens.
+ **UPGRADER_ROLE**  
  Allowed actions: upgrade contract to next version.
+ **PAUSER_ROLE**  
  Allowed actions: pause contract operations.
+ **UNPAUSER_ROLE**  
  Allowed actions: resume contract operations.

### Roles Admin 

Account getting **UPGRADER_ROLE** upon contract initialization should also be assigned the [`DEFAULT_ADMIN_ROLE`](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/3837fe4e4506529be67065cc98583b601173a7e9/contracts/access/AccessControlUpgradeable.sol#L56) for managing the roles after contract initialization.

## Upgradeability 

Implementation should be based on the [UUPSUpgradeable](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/fa525310e45f91eb20a6d3baa2644be8e0adba31/contracts/proxy/utils/UUPSUpgradeable.sol#L20) (OpenZeppelin).
