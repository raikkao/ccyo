/**
 *Submitted for verification at FtmScan.com on 2021-07-22
*/

// SPDX-License-Identifier: MIT




pragma solidity ^0.6.12;

import "../interfaces/IRewardsGauge.sol";
import "../interfaces/ICurveSwap.sol";
import "../lib/SafeERC20.sol";
import "../lib/SafeMath.sol";
import "../lib/Math.sol";
import "../lib/Address.sol";
import "../interfaces/IUniswapRouterETH.sol";
import "./StratManager.sol";



// File: contracts/BIFI/strategies/Curve/StrategyCurveLP.sol


pragma solidity ^0.6.0;


contract StrategyCurveLP is StratManager, FeeManager {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    // Tokens used
    address constant public want = 0x27E611FD27b276ACbd5Ffd632E5eAEBEC9761E40; // curve lpToken
    address constant public crv =0x1E4F97b9f9F913c46F1632781732927B9019C68b;
    address constant public native = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83;
    address constant public usdc = 0x04068DA6C83AFCFA0e13ba15A6696662335D5B75;
    address constant public dai = 0x8D11eC38a3EB5E956B052f67Da8Bdc9bef8Abf3E;

    // Third party contracts
    address constant public rewardsGauge = 0x8866414733F22295b7563f9C5299715D2D76CAf4;
    address constant public pool = 0x27E611FD27b276ACbd5Ffd632E5eAEBEC9761E40   ;
    uint public poolSize;

    // Routes
    address[] public crvToNativeRoute;
    address[] public nativeToDAI;
    address[] public nativeToUSDC;

    bool public harvestOnDeposit = true;

    /**
     * @dev Event that is fired each time someone harvests the strat.
     */
    event StratHarvest(address indexed harvester);

    constructor(
        uint _poolSize,
        address _vault,
        address _unirouter,
        address _keeper,
        address _whitelist,
        address _feeRecipient
    ) StratManager(_keeper, _whitelist, _unirouter, _vault, _feeRecipient) public {
        poolSize = _poolSize;

        crvToNativeRoute = [crv, native];
        nativeToDAI = [native, dai];
        nativeToUSDC = [native, usdc];

        _giveAllowances();
    }

    // puts the funds to work
    function deposit() public whenNotPaused {
        uint256 wantBal = IERC20(want).balanceOf(address(this));

        if (wantBal > 0) {
            IRewardsGauge(rewardsGauge).deposit(wantBal);
        }
    }

    function withdraw(uint256 _amount) external {
        require(msg.sender == vault, "!vault");

        uint256 wantBal = IERC20(want).balanceOf(address(this));

        if (wantBal < _amount) {
            IRewardsGauge(rewardsGauge).withdraw(_amount.sub(wantBal));
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

    function beforeDeposit() external override {
        if (harvestOnDeposit) {
            harvest();
        }
    }

    // compounds earnings and charges performance fee
    function harvest() public whenNotPaused onlyWhitelist {
        IRewardsGauge(rewardsGauge).claim_rewards(address(this));

        uint256 crvBal = IERC20(crv).balanceOf(address(this));
        uint256 nativeBal = IERC20(native).balanceOf(address(this));
        if (nativeBal > 0 || crvBal > 0) {
            chargeFees();
            addLiquidity();
            deposit();
            emit StratHarvest(msg.sender);
        }
    }

    // performance fees
    function chargeFees() internal {
        uint256 crvBal = IERC20(crv).balanceOf(address(this));
        if (crvBal > 0) {
            IUniswapRouterETH(unirouter).swapExactTokensForTokens(crvBal, 0, crvToNativeRoute, address(this), block.timestamp);
        }

        uint256 nativeFeeBal = IERC20(native).balanceOf(address(this)).mul(300).div(1000);

        uint256 callFeeAmount = nativeFeeBal.mul(callFee).div(MAX_FEE);
        IERC20(native).safeTransfer(tx.origin, callFeeAmount);

        uint256 ccdaoFeeAmount = nativeFeeBal.mul(ccdaoFee).div(MAX_FEE);
        IERC20(native).safeTransfer(feeRecipient, ccdaoFeeAmount);
    }

    // Adds liquidity to AMM and gets more LP tokens.
    function addLiquidity() internal {
        uint256 nativeBal = IERC20(native).balanceOf(address(this));
        //IUniswapRouterETH(unirouter).swapExactTokensForTokens(nativeBal, 0, nativeToDepositRoute, address(this), block.timestamp);

        uint256 balancePoolUSDC = IERC20(usdc).balanceOf(pool).mul(1e18).div(1e6);
        uint256 balancePoolDAI = IERC20(dai).balanceOf(pool);

        (address depositToken, 
        uint256 depositIndex, 
        address[] memory route) = balancePoolUSDC > balancePoolDAI ? (dai, 0, nativeToDAI) : (usdc, 1, nativeToUSDC);

        IUniswapRouterETH(unirouter).swapExactTokensForTokens(nativeBal, 0, route, address(this), block.timestamp);
        uint256 depositBal = IERC20(depositToken).balanceOf(address(this));

        uint256[2] memory amounts;
        amounts[depositIndex] = depositBal;
        ICurveSwap2(pool).add_liquidity(amounts, 0);
    
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
        return IRewardsGauge(rewardsGauge).balanceOf(address(this));
    }

    function crvToNative() external view returns(address[] memory) {
        return crvToNativeRoute;
    }


    function setHarvestOnDeposit(bool _harvest) external onlyManager {
        harvestOnDeposit = _harvest;
    }

    // called as part of strat migration. Sends all the available funds back to the vault.
    function retireStrat() external {
        require(msg.sender == vault, "!vault");

        IRewardsGauge(rewardsGauge).withdraw(balanceOfPool());

        uint256 wantBal = IERC20(want).balanceOf(address(this));
        IERC20(want).transfer(vault, wantBal);
    }

    // pauses deposits and withdraws all funds from third party systems.
    function panic() public onlyManager {
        pause();
        IRewardsGauge(rewardsGauge).withdraw(balanceOfPool());
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
        IERC20(want).approve(rewardsGauge, type(uint).max);
        IERC20(native).approve(unirouter, type(uint).max);
        IERC20(crv).approve(unirouter, type(uint).max);
        IERC20(dai).approve(pool, type(uint).max);
        IERC20(usdc).approve(pool, type(uint).max);
    }

    function _removeAllowances() internal {
        IERC20(want).approve(rewardsGauge, 0);
        IERC20(native).approve(unirouter, 0);
        IERC20(crv).approve(unirouter, 0);
        IERC20(dai).approve(pool, 0);
        IERC20(usdc).approve(pool, 0);

    }
}