
> [!CAUTION]  
> While this upgradeable token smart contract is built using [audited OZ libraries](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/tree/v5.2.0/audits),  
> **this particular implementation has not yet underwent any security audits. Use at your own risk.**

# `$WANLOG` ERC20 Token 

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

``` sh
forge fmt && forge clean && forge tests
```

## Deployment 

### Locally to Anvil

<details>
<summary>Expand me</summary>

Load environment variables:

``` sh
source .env.anvil
```

Spin out an [Anvil](https://book.getfoundry.sh/anvil/) fork of Sepolia:

``` sh
anvil -f $SEPOLIA_RPC_URL -p $ANVIL_PORT 
```

Run the deployment script:

``` sh
forge script script/00_Deploy.V1.s.sol --rpc-url $ANVIL_RPC_URL --broadcast -i 1
```

It will ask you to enter the private key. As we're using Anvil's default `account (0)` as the deployer (specified in the [`.env.anvil`](./.env.anvil)), use its (**!well-known!**) key here (can be found in Anvil logs). 

</details>

### To Sepolia

Load environment variables:

``` sh
source .env.sepolia
```

#### Deploy 

Once steps described above taken and succeed, deploy to Sepolia with:

``` sh
forge script script/00_Deploy.V1.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast -i 1
```

> [!NOTE]  
> You can also use hardware wallet for signing the transaction. E.g. for using with _Ledger_ run: 
> ```sh 
> forge script script/00_Deploy.V1.s.sol --rpc-url $ANVIL_RPC_URL --broadcast -l
> ```

#### Verify 

Figure out `solc` version used to compile the contracts: 

``` sh
forge inspect src/AnlogTokenV1.sol:AnlogTokenV1 metadata | jq .compiler.version
```

To verify proxy contract run: 

``` sh
forge v --verifier etherscan --compiler-version=<solc_version> \
--rpc-url=$SEPOLIA_RPC_URL <proxy_address> \
./lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy
```

To verify implementation contract run: 

``` sh
forge v --verifier etherscan --compiler-version=<solc_version> \
--rpc-url $SEPOLIA_RPC_URL <implementation_addresss> \
src/AnlogTokenV1.sol:AnlogTokenV1
```

## Upgrade

> [!NOTE]
> Commands below are given for the setting when you upgrade from `V1` to `V2`. 
> Also see [`Upgrade.V1.V2.t.sol` test](test/Upgrade.V0.V1.t.sol) for the reference.

*Prerequisites*: you have `V1` deployed.

### Locally to Anvil 

<details>
<summary>Expand me</summary>

Load environment variables:

``` sh
source .env.anvil
```

First spin out a local anvil and deploy `V1` to it by following instructions above.

Then set `PROXY` environment variable to the address of the deployed proxy.

Then run `V1.V2` upgrade script:

``` sh
forge script script/01_Upgrade.V1.V2.s.sol --rpc-url $ANVIL_RPC_URL --broadcast -i 1
```

It will ask you to enter the private key. As we're using Anvil's default `account (2)` as the `UPGRADER` (specified in the [`.env.anvil`](./.env.anvil)), use its (**!well-known!**) key here (can be found in Anvil logs). 

</details>


### To Sepolia 

In a live network, most probably a multisig is used for the `UPGRADER` account. Thus for doing an upgrade, 

dispatch the call to  [`upgradeToAndCall(address,bytes)`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/332bcb5f4d9cf0ae0f98fe91c77d9c1fb9951506/contracts/proxy/ERC1967/ERC1967Utils.sol#L67), providing the following args:

      - **address**: current (`V1`) implementation contract address;
      - **bytes**: (empty) (this is `calldata` for the `V2` implementation contract initializer, which we don't need for this upgrade).
        **note** for the cases when you need it, look at this [commit](https://github.com/Analog-Labs/erc20-token/blob/2c6025e8099966194ed006c25f1a79b5cabfa0df/README.md#upgrade-instructions) for the instructions of how to calculate it.
