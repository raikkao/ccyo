# Code modifications 


- Transfer overriddance should be replaced with _transfer in the Token contract.
    - Changed contract to another one that is Mintable because it can be useful when developing the contribution based rewards.

- The reward pool contract should have a constructor-defined "rate" (1e18 literal should be replaced by an immutable variable) and should most likely be deployed via a factory for ease of deployment.
    - Added a constructor defined "rate" instead of 1e18 literal in the Rewards Pool contract. 
    - Should we do the same for the Vault?
    - What I have noticed is the ERC20 LP tokens that SpookySwap and Curve create have 18 decimals, as they are the tokens that we accept in the Vaults we should not have problems with this issue, unless of course they decide to create an ERC20 LP token with different amount of decimals.

- Solidity versions should be locked to properly deduce potential compiler errors (although most of those arise from raw assembly usage and quirky dynamic array arguments)
    - Done, locked to version 0.6.12

- Redundancies may be cleaned if you desire.
    - Not done this because of a lack of time and knowledge on which parts can be cleaned. Will do once I have more time to research.

- The tx.origin == msg.sender check should be evaluated a bit more closely. as a temporary countermeasure, you can move forward with the current implementation but adapt it to be "switchable" to one of the two solutions I proposed further down the line when EIP-3074 will become a reality (which it will 100%).
    - Created a whitelist contract, the addreses in the whitelist contract will be the only ones allowed to execute the harvest contract. 

- The safe approve invocations should be replaced by simple approve ones
    - Done

- The Scream strategy must validate the returned codes of Venus.
    - Added the necessary return codes.

- The Spooky strategy should use the Alpha Homora V2 algorithm for optimal one sided liquidity (important note: the article actually contains an incorrect implementation of it perhaps to mislead users, you can find the actual one in the post's links as well as Alpha Homora V2 deployment).
    - Done, using Alpha Homora v2 algorithm

- The Curve strategy should try to deposit the most lucrative asset via balance measurements(edited).
    - Done, both for the 2Pool and the fusdt+2Pool. (Will do the same for the tricrypto once we finish the IVO)
    - Should we do the same for the BTC/renBTC? there's no liquidity pool for exchanging wftm to renBTC, so I would have to go through the Curve pool itself, not sure if worth.

