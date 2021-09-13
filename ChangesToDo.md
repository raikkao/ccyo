# Code modifications to do


- transfer overriddance should be replaced with _transfer in the Token contract 
    - Changed contract to another one, the fact that is Mintable because it can be useful when developing the contribution based rewards

- the reward pool contract should have a constructor-defined "rate" (1e18 literal should be replaced by an immutable variable) and should most likely be deployed via a factory for ease of deployment

- solidity versions should be locked to properly deduce potential compiler errors (although most of those arise from raw assembly usage and quirky dynamic array arguments)

- redundancies may be cleaned if you desire

- the tx.origin == msg.sender check should be evaluated a bit more closely. as a temporary countermeasure, you can move forward with the current implementation but adapt it to be "switchable" to one of the two solutions I proposed further down the line when EIP-3074 will become a reality (which it will 100%) 
    - Created a whitelist contract, the addreses in the whitelist contract will be the only ones able to execute the harvest contract.

- the non-safe transfer after some more thought can be ignored as it's an emergency use case and that is probably the reason they are performing a raw one

- the safe approve invocations should be replaced by simple approve ones

- the Scream strategy must validate the returned codes of Venus 
    - Added the necessary return codes to the code

- the Spooky strategy should use the Alpha Homora V2 algorithm for optimal one sided liquidity (important note: the article actually contains an incorrect implementation of it perhaps to mislead users, you can find the actual one in the post's links as well as Alpha Homora V2 deployment)

- the Curve strategy should try to deposit the most lucrative asset via balance measurements(edited)

