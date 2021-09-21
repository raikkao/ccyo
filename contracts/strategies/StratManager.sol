
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "../lib/Context.sol";
import "../lib/Address.sol";
import "../lib/Pausable.sol";
import "../lib/Ownable.sol";

interface IWhitelist {
    function isWhitelisted(address addressToCheck) external returns(bool);
}


contract StratManager is Ownable, Pausable {
    /**
     * @dev ccdao Contracts:
     * {keeper} - Address to manage a few lower risk features of the strat
     * {vault} - Address of the vault that controls the strategy's funds.
     * {unirouter} - Address of exchange to execute swaps.
     */
    address public keeper;
    address public whitelist;
    address public unirouter;
    address public vault;
    address public feeRecipient;

    /**
     * @dev Initializes the base strategy.
     * @param _keeper address to use as alternative owner.
     * @param _unirouter router to use for swaps
     * @param _vault address of parent vault.
     * @param _feeRecipient address where to send ccdao's fees.
     */
    constructor(
        address _keeper,
        address _whitelist,
        address _unirouter,
        address _vault,
        address _feeRecipient
    ) public {
        keeper = _keeper;
        whitelist = _whitelist;
        unirouter = _unirouter;
        vault = _vault;
        feeRecipient = _feeRecipient;
    }

    /// @notice Address changed the variable with `address`
    event UpdatedAddressSlot(string indexed name, address oldValue, address newValue);

    // checks that caller is either owner or keeper.
    modifier onlyWhitelist() {
        require(msg.sender == owner() || msg.sender == keeper || IWhitelist(keeper).isWhitelisted(msg.sender), "!manager");
        _;
    }

    // checks that caller is either owner or keeper.
    modifier onlyManager() {
        require(msg.sender == owner() || msg.sender == keeper, "!manager");
        _;
    }

    // verifies that the caller is not a contract.
    modifier onlyEOA() {
        require(msg.sender == tx.origin, "!EOA");
        _;
    }

    /**
     * @dev Updates address of the strat keeper.
     * @param newKeeper new keeper address.
     */
    function setKeeper(address newKeeper) external onlyManager {
        emit UpdatedAddressSlot("Keeper", keeper, newKeeper);
        keeper = newKeeper;
    }

    /**
     * @dev Updates router that will be used for swaps.
     * @param newUnirouter new unirouter address.
     */
    function setUnirouter(address newUnirouter) external onlyOwner {
        unirouter = newUnirouter;
    }

    /**
     * @dev Updates parent vault.
     * @param newVault new vault address.
     */
    function setVault(address newVault) external onlyOwner {
        vault = newVault;
    }

    /**
     * @dev Updates ccdao fee recipient.
     * @param newFeeRecipient new ccdao fee recipient address.
     */
    function setfeeRecipient(address newFeeRecipient) external onlyOwner {
        feeRecipient = newFeeRecipient;
    }

    /**
     * @dev Function to synchronize balances before new user deposit.
     * Can be overridden in the strategy.
     */
    function beforeDeposit() external virtual {}
}



abstract contract FeeManager is StratManager {
    uint constant public MAX_FEE = 1000;
    uint constant public MAX_CALL_FEE = 111;

    uint constant public WITHDRAWAL_FEE_CAP = 50;
    uint constant public WITHDRAWAL_MAX = 10000;

    uint public withdrawalFee = 10;

    uint public callFee = 111;
    uint public ccdaoFee = MAX_FEE - callFee;

      /// @notice Value changed the variable with `name`
    event UpdatedUint256Slot(string indexed name, uint256 oldValue, uint256 newValue);

    function setCallFee(uint256 newFee) public onlyManager {
        require(newFee <= MAX_CALL_FEE, "!cap");
        emit UpdatedUint256Slot("CallFee", callFee, newFee);
        
        callFee = newFee;
        ccdaoFee = MAX_FEE - callFee;
    }

    function setWithdrawalFee(uint256 newWithdrawalfee) public onlyManager {
        require(newWithdrawalfee <= WITHDRAWAL_FEE_CAP, "!cap");

        withdrawalFee = newWithdrawalfee;
    }
}