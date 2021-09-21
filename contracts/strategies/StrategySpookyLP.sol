// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "../lib/SafeERC20.sol";
import "../lib/SafeMath.sol";
import "../lib/Address.sol";
import "../lib/OptimizedMath.sol";
import "../interfaces/IUniswapRouterETH.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "../interfaces/IMasterChef.sol";
import "./StratManager.sol";



contract StrategySpookyLP is StratManager, FeeManager {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    // Tokens used
    address constant public wrapped = address(0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83);
    address constant public output = address(0x841FAD6EAe12c286d1Fd18d1d525DFfA75C7EFFE);
    address public want;
    address public lpToken0;
    address public lpToken1;

    // Third party contracts
    address constant public masterchef = address(0x2b2929E785374c651a81A63878Ab22742656DcDd);
    uint256 public poolId;

    // Routes
    address[] public outputToWrappedRoute = [output, wrapped];
    address[] public outputToLp0Route;
    address[] public outputToLp1Route;

    /**
     * @dev Event that is fired each time someone harvests the strat.
     */
    event StratHarvest(address indexed harvester);

    constructor(
        address _want,
        uint256 _poolId,
        address _vault,
        address _unirouter,
        address _keeper,
        address _whitelist,
        address _feeRecipient
    ) StratManager(_keeper, _whitelist, _unirouter, _vault, _feeRecipient) public {
        want = _want;
        lpToken0 = IUniswapV2Pair(want).token0();
        lpToken1 = IUniswapV2Pair(want).token1();
        poolId = _poolId;

        if (lpToken0 == wrapped) {
            outputToLp0Route = [output, wrapped];
        } else if (lpToken0 != output) {
            outputToLp0Route = [output, wrapped, lpToken0];
        }

        if (lpToken1 == wrapped) {
            outputToLp1Route = [output, wrapped];
        } else if (lpToken1 != output) {
            outputToLp1Route = [output, wrapped, lpToken1];
        }

        _giveAllowances();
    }

    // puts the funds to work
    function deposit() public whenNotPaused {
        uint256 wantBal = IERC20(want).balanceOf(address(this));

        if (wantBal > 0) {
            IMasterChef(masterchef).deposit(poolId, wantBal);
        }
    }

    function withdraw(uint256 _amount) external {
        require(msg.sender == vault, "!vault");

        uint256 wantBal = IERC20(want).balanceOf(address(this));

        if (wantBal < _amount) {
            IMasterChef(masterchef).withdraw(poolId, _amount.sub(wantBal));
            wantBal = IERC20(want).balanceOf(address(this));
        }

        if (wantBal > _amount) {
            wantBal = _amount;
        }

        if (tx.origin == owner() || paused()) {
            IERC20(want).safeTransfer(vault, wantBal);
        } else {
            uint256 withdrawalFeeAmount = wantBal.mul(withdrawalFee).div(WITHDRAWAL_MAX);
            IERC20(want).safeTransfer(vault, wantBal.sub(withdrawalFeeAmount));
        }
    }

    // compounds earnings and charges performance fee
    function harvest() external whenNotPaused onlyWhitelist {
        IMasterChef(masterchef).deposit(poolId, 0);
        chargeFees();
        addLiquidity();
        deposit();

        emit StratHarvest(msg.sender);
    }

    // performance fees
    function chargeFees() internal {
        uint256 toWrapped = IERC20(output).balanceOf(address(this)).mul(300).div(1000);
        IUniswapRouterETH(unirouter).swapExactTokensForTokens(toWrapped, 0, outputToWrappedRoute, address(this), now);

        uint256 wrappedBal = IERC20(wrapped).balanceOf(address(this));

        uint256 callFeeAmount = wrappedBal.mul(callFee).div(MAX_FEE);
        IERC20(wrapped).safeTransfer(msg.sender, callFeeAmount);

        uint256 ccdaoFeeAmount = wrappedBal.mul(ccdaoFee).div(MAX_FEE);
        IERC20(wrapped).safeTransfer(feeRecipient, ccdaoFeeAmount);

    }


  //Alpha Homoras function to find the optimal deposit to add to the liquidity pool
  function optimalDeposit(
        uint amtA,
        uint amtB,
        uint resA,
        uint resB
    ) internal pure returns (uint) {
        require(amtA.mul(resB) >= amtB.mul(resA), 'Reversed');
        uint a = 997;
        uint b = uint(1997).mul(resA);
        uint _c = (amtA.mul(resB)).sub(amtB.mul(resA));
        uint c = _c.mul(1000).div(amtB.add(resB)).mul(resA);
        uint d = a.mul(c).mul(4);
        uint e =OptimizedMath.sqrt(b.mul(b).add(d));
        uint numerator = e.sub(b);
        uint denominator = a.mul(2);
        return numerator.div(denominator);
    }


    // Adds liquidity to AMM and gets more LP tokens.
    function addLiquidity() internal {
        uint256 balanceRewards = IERC20(output).balanceOf(address(this));

        IUniswapRouterETH(unirouter).swapExactTokensForTokens(balanceRewards, 0, outputToLp0Route, address(this), now);
        uint256 balanceToken0 = IERC20(lpToken0).balanceOf(address(this));

        uint swapAmt;
        (uint token0Reserve, uint token1Reserve, ) = IUniswapV2Pair(want).getReserves();
        swapAmt = optimalDeposit(
            balanceToken0,
            0,
            token0Reserve,
            token1Reserve
        );
        if (swapAmt > 0) {
            address[] memory path = new address[](2);
            (path[0], path[1]) = (lpToken0, lpToken1);
            IUniswapRouterETH(unirouter).swapExactTokensForTokens(swapAmt, 0, path, address(this), now);
        }

        uint256 lp0Bal = IERC20(lpToken0).balanceOf(address(this));
        uint256 lp1Bal = IERC20(lpToken1).balanceOf(address(this));
        IUniswapRouterETH(unirouter).addLiquidity(lpToken0, lpToken1, lp0Bal, lp1Bal, 1, 1, address(this), now);
    }

    // calculate the total underlaying 'want' held by the strat.
    function balanceOf() public view returns (uint256) {
        return balanceOfWant().add(balanceOfPool());
    }

    // it calculates how much 'want' this contract holds.
    function balanceOfWant() public view returns (uint256) {
        return IERC20(want).balanceOf(address(this));
    }

    // it calculates how much 'want' the strategy has working in the farm.
    function balanceOfPool() public view returns (uint256) {
        (uint256 _amount, ) = IMasterChef(masterchef).userInfo(poolId, address(this));
        return _amount;
    }

    // called as part of strat migration. Sends all the available funds back to the vault.
    function retireStrat() external {
        require(msg.sender == vault, "!vault");

        IMasterChef(masterchef).emergencyWithdraw(poolId);

        uint256 wantBal = IERC20(want).balanceOf(address(this));
        IERC20(want).transfer(vault, wantBal);
    }

    // pauses deposits and withdraws all funds from third party systems.
    function panic() public onlyManager {
        pause();
        IMasterChef(masterchef).emergencyWithdraw(poolId);
    }

    function pause() public onlyManager {
        _pause();

        _removeAllowances();
    }

    function unpause() external onlyManager {
        _unpause();

        _giveAllowances();

        deposit();
    }

    function _giveAllowances() internal {
        IERC20(want).approve(masterchef, uint256(-1));
        IERC20(output).approve(unirouter, uint256(-1));

        IERC20(lpToken0).approve(unirouter, 0);
        IERC20(lpToken0).approve(unirouter, uint256(-1));

        IERC20(lpToken1).approve(unirouter, 0);
        IERC20(lpToken1).approve(unirouter, uint256(-1));
    }

    function _removeAllowances() internal {
        IERC20(want).approve(masterchef, 0);
        IERC20(output).approve(unirouter, 0);
        IERC20(lpToken0).approve(unirouter, 0);
        IERC20(lpToken1).approve(unirouter, 0);
    }
}