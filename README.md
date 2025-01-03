# $ANLOG ERC20 Token 

## Spec 

### Business Requirements 

Laid out at this [Notion page](https://www.notion.so/teamanalog/Wrapped-Token-16d4872af8ca801db917f7cb1f7e2283).

### Tech Specs 

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


### Based on OpenZeppelin Libraries 

Our token implementation is based on well-tested and audited industry-wide standard libraries and plugins: 

+ [OpenZeppelin Upgradeable Contracts v5](https://docs.openzeppelin.com/contracts/5.x/upgradeable)
+ [OpenZeppelin Upgrades Plugins](https://docs.openzeppelin.com/upgrades-plugins/)

## Foundry

This project is built with the [Foundry](https://book.getfoundry.sh/) framework.
