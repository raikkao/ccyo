// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "./lib/Ownable.sol";
import "./lib/Context.sol";


contract Whitelist is Ownable {
    mapping(address => bool) whitelist;
    event AddedToWhitelist(address indexed account);
    event RemovedFromWhitelist(address indexed account);

    constructor() public {
        add(msg.sender);
    }

    function add(address newWhitelisted) public onlyOwner {
        whitelist[newWhitelisted] = true;
        emit AddedToWhitelist(newWhitelisted);
    }

    function remove(address previousWhitelisted) public onlyOwner {
        whitelist[previousWhitelisted] = false;
        emit RemovedFromWhitelist(previousWhitelisted);
    }

    function isWhitelisted(address addressToCheck) public view returns(bool) {
        return whitelist[addressToCheck];
    }
}