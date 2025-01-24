
> [!CAUTION]  
> While this upgradeable token smart contract is built using [audited OZ libraries](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/tree/v5.2.0/audits),  
> **this particular implementation has not yet underwent any security audits. Use at your own risk.**

# $ANLOG ERC20 Token 

## Initial Requirements

What is needed is an ERC20 implementation which

1.  Has **centralized minting**,
2.  Is **pausable**,
3.  Is **upgradeable**.

For pp.1-2 OZ&rsquo;s [ERC20Upgradeable](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/v5.2.0/contracts/token/ERC20/) should be used with corresponding extensions.  

For p.3 (**upgradeability**) the following options are available: 

> - [TransparentUpgradeableProxy][transparent-proxy]: A proxy with a built in admin and upgrade interface
> - [UUPSUpgradeable][uups-proxy]: An upgradeability mechanism to be included in the implementation contract.
> 
> ([source](https://docs.openzeppelin.com/contracts/5.x/api/proxy#transparent-vs-uups))

We prefer **UUPSUpgradeable** proxy, because it allows to eventually make the implementation contract non-upgradeable, therefore making its final version immutable, which _might_ be preferable for exchanges and token holders as it implies less trust and removes possible security breaches (like e.g. updating token contract to something working not as agreed or breaking its logic partially or overall).   

[transparent-proxy]: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/proxy/transparent/TransparentUpgradeableProxy.sol
[uups-proxy]: https://docs.openzeppelin.com/contracts/5.x/api/proxy#UUPSUpgradeable


### Business Requirements 

Laid out at this [Notion page](https://www.notion.so/teamanalog/Wrapped-Token-16d4872af8ca801db917f7cb1f7e2283).

### Tech Spec 

See [SPEC.md](spec.md).

## Based on OpenZeppelin Libraries 

Our token implementation is based on well-tested and audited industry-wide standard libraries and plugins: 

+ [OpenZeppelin Upgradeable Contracts v5](https://docs.openzeppelin.com/contracts/5.x/upgradeable)
+ [OpenZeppelin Upgrades Plugins](https://docs.openzeppelin.com/upgrades-plugins/)

## Foundry

This project is built with the [Foundry](https://book.getfoundry.sh/) framework.

## Testing 

If changed some contract, run this first:

``` sh
forge fmt && forge clean && forge build
```

Then run tests: 

``` sh
forge test
```

## Deployment 

### Locally to Anvil

Spin out a default [Anvil](https://book.getfoundry.sh/anvil/) node:

``` sh
anvil -p 9545
```

Load environment variables and run the deployment script:

``` sh
source .env.anvil
forge script script/00_Deploy.s.sol --rpc-url $ANVIL_RPC_URL --broadcast -i 1
```

It will ask you to enter the private key. As we're using Anvil's default `account (0)` as the deployer (specified in the [`.env.anvil`](./.env.anvil)), use its (**!well-known!**) key here (can be found in Anvil logs). 

### To Sepolia testnet 


> [!IMPORTANT]  
> You need to setup environment first, see [`.env.sepolia.example`](./.env.sepolia.example)

#### Dry-run on Fork 

Spin out an Anvil fork of Sepolia network:

``` sh
source .env.sepolia
anvil -f $SEPOLIA_RPC_URL -p 9545
```

Deploy: 

``` sh
source .env.sepolia
forge script script/00_Deploy.s.sol --rpc-url $ANVIL_RPC_URL --broadcast -i 1
```

Make sure to provide the private key of the `DEPLOYER` account upon script's interactive prompt.

> [!NOTE]  
> You can also use hardware wallet for signing the transaction. E.g. for using with _Ledger_ run: 
> ```sh 
> forge script script/00_Deploy.s.sol --rpc-url $ANVIL_RPC_URL --broadcast -l
> ```

#### Real run on Sepolia 

Once steps described above taken and succeed, deploy to Sepolia with:

``` sh
forge script script/00_Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast -i 1
```

### Upgrade instructions

> [!NOTE]
> Commands below are given for the setting when you upgrade from `V0` to `V1`. See [`Upgrade.V0.V1.t.sol`](test/Upgrade.V0.V1.t.sol) for the reference.


Let say you have deployed proxy and `V0` implementation contract for it.  
To upgrade the implementation contract to `V1`:

1. Prepare calldata for V1 initializer:

   ```sh
   source .env.sepolia
   cast ae "initialize(address,address,address,address)()" $MINTER $UPGRADER $PAUSER $UNPAUSER
   ``` 
   You should get hex-encoded calldata as the result.

2. Dispatch the call to  [`upgradeToAndCall(address,bytes)`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/332bcb5f4d9cf0ae0f98fe91c77d9c1fb9951506/contracts/proxy/ERC1967/ERC1967Utils.sol#L67), providing the following args:

      - Current (`V0`) impl contract address;
      - Calldata for the `V1` impl contract initializer 
        (the one you've got on the previous step).



