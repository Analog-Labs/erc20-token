# $ANLOG ERC20 Token 

## Initial Requirements

What is needed is an ERC20 implementation which

1.  Has **centralized minting**,
2.  Is **pausable**,
3.  Is **upgradeable**.

For pp.1-2 OZ&rsquo;s [ERC20PresetMinterPauser](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.6/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol) preset should be used.  

For p.3 (**upgradeability**) the following options are available: 

> - [TransparentUpgradeableProxy][transparent-proxy]: A proxy with a built in admin and upgrade interface
> - [UUPSUpgradeable][uups-proxy]: An upgradeability mechanism to be included in the implementation contract.
> 
> ([source](https://docs.openzeppelin.com/contracts/4.x/api/proxy#transparent-vs-uups))

We prefer **UUPSUpgradeable** proxy, because it allows to eventually make the implementation contract non-upgradeable, therefore making its final version immutable, which _might_ be preferable for exchanges and token holders as it implies less trust and removes possible security breaches (like e.g. updating token contract to something working not as agreed or breaking its logic partially or overall).   

[transparent-proxy]: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/proxy/transparent/TransparentUpgradeableProxy.sol
[uups-proxy]: https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable


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

Make sure to provide the private key of the `DEPLOYER` account to script's interactive prompt.

> [!NOTE]  
> You can also use hardware wallet for signing the transaction. E.g. for using with _Ledger_ run: 
> ```sh 
> forge script script/00_Deploy.s.sol --rpc-url $ANVIL_RPC_URL --broadcast -l
> ```
