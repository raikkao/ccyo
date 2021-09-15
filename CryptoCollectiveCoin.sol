pragma solidity 0.5.16;

import "@openzeppelin/contracts@2.5.0/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@2.5.0/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts@2.5.0/token/ERC20/ERC20Mintable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CCC is ERC20, ERC20Detailed, ERC20Mintable {

  constructor(uint256 initialSupply) public ERC20Detailed('Crypto Collective Coin', 'CCC', 18) {
    _mint(msg.sender, initialSupply);
  }

   /**
  * Overrides adding new minters so that only owner can authorized them.
  */
  function addMinter(address _minter) public onlyOwner {
    super.addMinter(_minter);
  }

}