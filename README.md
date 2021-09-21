# Crypto Collective YO
Yield Optimizer for the CCDAO

This is a small summary of the contracts.

## Vault

Creates an ERC20 token for the Vault that mints every time there's a deposit and burns them every time there's a withdrawal.

## RewardPool

Contract for staking tokens and getting rewards.

## CryptoCollectiveCoin

ERC20 Token without max supply that will be used for the rewards.

## TimeLock

This TimeLock is goood for delaying the interactions with other contracts, Beefy does not have this kind of TimeLock but this can be a good to be safe.

## Whitelist

Whitelist contract to add addresses that will be allowed to harvest the strategies.

## Strategies

Strategies created for the vaults.

### Curve strategies

When harvesting the rewards and adding liquidity, looks for the asset that has the lowest balance in the pool and adds liquidity only in that asset. This way the pool will give a higher amount of LPs and increase the APR.

### Spooky strategies

When harvesting the rewards we use the Alpha Homora technique of adding liquidity in an optimal way, this means that there will not be any token wasted during the process of adding liquidity.

### Scream strategies

Folding strategy for scream.