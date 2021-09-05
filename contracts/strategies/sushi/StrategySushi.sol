pragma solidity ^0.6.12;

import "../base/BaseStrategyMiniChef.sol";
//For A/B token pairs, where I have to convert the harvested token to A (ETH/MATIC/USDC/etc) and then sell 1/2 of A for B
contract StrategySushi is BaseStrategyMiniChef {

    address public WMATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    address public sushi = 0x0b3F868E0BE5597D5DB7fEB59E1CADBb0fdDa50a;
    address public tokenA;
    address public tokenB;
    address public sushiRouter = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;
    address public miniChef = 0x0769fd68dFb93167989C6f7254cd0D766Fb2841F;

    uint256 public constant keepMax = 10000;

    // Uniswap swap paths
    address[] public sushi_matic_path;
    address[] public reward_a_path;
    address[] public a_b_path;

    constructor(
        address _want,
        address _tokenA,
        address _tokenB,
        uint256 _poolId,
        address _strategist
    )
        public
        BaseStrategyMiniChef(
            miniChef,
            _want,
            _strategist,
            _poolId,
            WMATIC,
            sushiRouter
        )
    {
        sushi_matic_path = new address[](2);
        sushi_matic_path[0] = sushi;
        sushi_matic_path[1] = WMATIC;

        tokenA = _tokenA;
        tokenB = _tokenB;

        reward_a_path = new address[](2);
        reward_a_path[0] = WMATIC;
        reward_a_path[1] = _tokenA;

        a_b_path = new address[](2);
        a_b_path[0] = _tokenA;
        a_b_path[1] = _tokenB;

        IERC20(harvestedToken).safeApprove(currentRouter, uint256(-1));
        IERC20(sushi).safeApprove(currentRouter, uint256(-1));

        if(harvestedToken != _tokenA) IERC20(_tokenA).safeApprove(currentRouter, uint256(-1));
        if(harvestedToken != _tokenB) IERC20(_tokenB).safeApprove(currentRouter, uint256(-1));
    }

    function getFeeDistToken() public override view returns (address) {
        return harvestedToken;
    }

    // **** State Mutations ****

    function harvest() public override onlyHumanOrWhitelisted nonReentrant {
        //Transfer any harvestedToken (WMATIC) that may already be in the contract to the fee dist fund
        IERC20(harvestedToken).safeTransfer(strategist, IERC20(harvestedToken).balanceOf(address(this)));
        //Transfer any sushi that may already be in the contract to the fee dist fund
        IERC20(sushi).safeTransfer(strategist, IERC20(sushi).balanceOf(address(this)));

        //Claims Sushi and some WMATIC
        _getReward();

        //Swap Sushi for WMATIC, because WMATIC is used to calculate profit
        uint256 _sushi_balance = IERC20(sushi).balanceOf(address(this));
        if (_sushi_balance > 0) {
            _swapUniswapWithPathPreapproved(sushi_matic_path, _sushi_balance);
        }

        //Distribute fee
        uint256 _harvested_balance = IERC20(harvestedToken).balanceOf(address(this));
        if (_harvested_balance > 0) {
            uint256 feeAmount = _harvested_balance.mul(IERCFund(strategist).getFee()).div(keepMax);
            uint256 afterFeeAmount = _harvested_balance.sub(feeAmount);
            _notifyJar(feeAmount);

            IERC20(harvestedToken).safeTransfer(strategist, feeAmount);

            //Swap WMATIC for tokenA if it isn't WMATIC
            //make sure token A has a high liquidity pair with WMATIC, like WETH and USDC
            if(tokenA != WMATIC) {
                _swapUniswapWithPathPreapproved(reward_a_path, afterFeeAmount);
            }
        }

        //Swap 1/2 of tokenA for tokenB
        uint256 _balanceA = IERC20(tokenA).balanceOf(address(this));
        if (_balanceA > 0) {
            _swapUniswapWithPathPreapproved(a_b_path, _balanceA.div(2));
        }

        //Add liquidity
        uint256 aBalance = IERC20(tokenA).balanceOf(address(this));
        uint256 bBalance = IERC20(tokenB).balanceOf(address(this));
        if (aBalance > 0 && bBalance > 0) {
            IUniswapRouterV2(currentRouter).addLiquidity(
                tokenA, tokenB,
                aBalance, bBalance,
                0, 0,
                address(this),
                now + 60
            );
        }

        // Stake the LP tokens
        _distributePerformanceFeesAndDeposit();
    }

    function _notifyJar(uint256 _amount) internal {
        IGenericVault(jar).notifyReward(getFeeDistToken(), _amount);
    }
}