pragma solidity ^0.6.12;

import "./BaseStrategyStakingRewards.sol";
import "../../interfaces/IERCFund.sol";
import "../../interfaces/IGenericVault.sol";
import "../../interfaces/sushi/IMiniChef.sol";

// Base contract for the new version of MasterChef that Sushi uses on Matic
abstract contract BaseStrategyMiniChef is BaseStrategy {

    uint256 public poolId;

    constructor(
        address _rewards,
        address _want,
        address _strategist,
        uint256 _poolId,
        address _harvestedToken,
        address _currentRouter
    )
        public
        BaseStrategy(_want, _strategist, _harvestedToken, _currentRouter, _rewards)
    {
        poolId = _poolId;
        IERC20(_want).safeApprove(_rewards, uint256(-1));
    }

    // **** Getters ****
    function balanceOfPool() public override view returns (uint256) {
        (uint256 amount, ) = IMiniChef(rewards).userInfo(poolId, address(this));
        return amount;
    }

    function getHarvestable() external override view returns (uint256) {
        return IMiniChef(rewards).pendingSushi(poolId, address(this));
    }

    // **** Setters ****

    function deposit() public override {
        uint256 _want = IERC20(want).balanceOf(address(this));
        if (_want > 0) {
            IMiniChef(rewards).deposit(poolId, _want, address(this));
        }
    }

    function _withdrawSome(uint256 _amount)
        internal
        override
        returns (uint256)
    {
        IMiniChef(rewards).withdraw(poolId, _amount, address(this));
        return _amount;
    }
    
    /* **** Other Mutative functions **** */

    function _getReward() internal {
        IMiniChef(rewards).harvest(poolId, address(this));
    }

    // **** Admin functions ****

    function salvage(address token) public onlyOwner {
        require(token != want && token != harvestedToken, "cannot salvage");

        uint256 _token = IERC20(token).balanceOf(address(this));
        if (_token > 0) {
            IERC20(token).safeTransfer(msg.sender, _token);
        }
    }

    function emergencyWithdraw() public onlyOwner {
        IMiniChef(rewards).emergencyWithdraw(poolId, address(this));

        uint256 _want = IERC20(want).balanceOf(address(this));
        if (_want > 0) {
            IERC20(want).safeTransfer(jar, _want);
        }
    }
}