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


[transparent-proxy]: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/proxy/transparent/TransparentUpgradeableProxy.sol
[uups-proxy]: https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable


## Foundry

This project is built with the [Foundry](https://book.getfoundry.sh/) framework.
