pragma solidity ^0.6.12;
interface IBoostHandler {

  //Returns ADDY earning boost based on user's veADDY, boost should be divided by 1e18
  function getBoost(address _user, address _vaultAddress) external view returns (uint256);

  //Returns ADDY earning boost based on user's veADDY if the user was to stake in vaultAddress, boost is divided by 1e18
  function getBoostForValueStaked(address _user, address _vaultAddress, uint256 valueStaked) external view returns (uint256);

  //Returns the value in USD for which a user's ADDY earnings are doubled
  function getDoubleLimit(address _user) external view returns (uint256 doubleLimit);

  //Returns the total VeAddy from all sources
  function getTotalVeAddy(address _user) external view returns (uint256);

  //Returns the total VeAddy from locking ADDY in the locked ADDY staking contract
  function getVeAddyFromLockedStaking(address _user) external view returns (uint256);

  function setFeeDist(address _feeDist) external;
}