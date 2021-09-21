// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "./lib/ERC20.sol";
import "./lib/ERC20Mintable.sol";
import "./lib/Ownable.sol";

contract CCC is ERC20, ERC20Mintable, Ownable {

  constructor(uint256 initialSupply) public ERC20('Crypto Collective Coin', 'CCC') {
    _mint(msg.sender, initialSupply);
  }

   /**
  * Overrides adding new minters so that only owner can authorized them.
  */
  function addMinter(address _minter) public override onlyOwner {
    super.addMinter(_minter);
  }

}