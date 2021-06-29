// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "@canary/exchange-contracts/contracts/canary-core/interfaces/ICanaryERC20.sol";

contract CNRAutocompound is Ownable {
    using SafeMath for uint;
    using SafeERC20 for IERC20;
    
    IERC20 public depositToken;
    IERC20 public rewardToken;
    address public sysAddr;
    
    IStakingRewards public stakingContract;

    uint public totalDeposits;
    uint public totalSupply;
    uint public ReinvestMinValue;
    bool public depositsEnabled;
    uint public ReinvestRewardPerc;
    uint public SystemFeePerc;
    uint constant internal _divisor = 10000;
    uint constant internal _maxUint = uint(-1);

    mapping(address => uint256) private _balances;

    event Deposit(address indexed account, uint amount);
    event Withdraw(address indexed account, uint amount);
    event Reinvest(uint newTotalDeposits, uint newTotalSupply);

    constructor (
        address _depositToken,
        address _rewardToken,
        address _stakingContract,
        uint _reinvestMinValue,
        uint _reinvestRewardPerc,
        uint _systemFeePerc
    ) {
        depositToken = IERC20(_depositToken);
        rewardToken = IERC20(_rewardToken);
        stakingContract = IStakingRewards(_stakingContract);
        ReinvestMinValue = _reinvestMinValue;
        ReinvestRewardPerc = _reinvestRewardPerc;
        SystemFeePerc = _systemFeePerc;
        depositsEnabled = true;
        sysAddr = _msgSender();
        setAllowances();
    }

    function setAllowances() public onlyOwner {
        depositToken.approve(address(stakingContract), _maxUint);
    }

    function deposit(uint amount) external {
        _deposit(msg.sender, amount);
    }

    function depositWithPermit(uint amount, uint deadline, uint8 v, bytes32 r, bytes32 s) external {
        ICanaryERC20(address(depositToken)).permit(msg.sender, address(this), amount, deadline, v, r, s);
        _deposit(msg.sender, amount);
    }

    function depositFor(address account, uint amount) external {
        _deposit(account, amount);
    }

    function _deposit(address account, uint amount) private {
        require(depositsEnabled == true, "CNRAutocompound::deposit false");
        require(depositToken.transferFrom(msg.sender, address(this), amount));
        _stakeCNRToken(amount);
        uint depositTokenAmount = getSharesForDepositTokens(amount);
        totalSupply = totalSupply.add(depositTokenAmount);
        _balances[account] = _balances[account].add(depositTokenAmount);
        totalDeposits = totalDeposits.add(amount);
        emit Deposit(account, amount);
    }

    function withdraw(uint amount) public {
        require(amount != 0, "CNRAuto::withdraw: amount cant be 0");
        require(amount <= _balances[msg.sender], "CNRAuto::withdraw: no balance");
        uint depositTokenAmount = getDepositTokensForShares(amount);
        if (depositTokenAmount > 0) {
            _withdrawDepositTokens(depositTokenAmount);
            require(depositToken.transfer(msg.sender, depositTokenAmount), "CNRAutocompound::withdraw");
            _balances[msg.sender] = _balances[msg.sender].sub(amount);
            totalSupply = totalSupply.sub(amount);
            totalDeposits = totalDeposits.sub(depositTokenAmount);
            emit Withdraw(msg.sender, depositTokenAmount);
        }
    }

    function _withdrawDepositTokens(uint amount) private {
        require(amount > 0, "CNRAutocompound::_withdrawDepositTokens");
        stakingContract.withdraw(amount);
    }

    function exit() external {
        withdraw(_balances[msg.sender]);
    }

    function reinvest() external {
        uint unclaimedRewards = checkReward();
        require(unclaimedRewards >= ReinvestMinValue, "CNRAutocompound::reinvest");
        _reinvest(unclaimedRewards);
    }

    function _reinvest(uint amount) private {
        stakingContract.getReward();

        uint reinvestFee = amount.mul(ReinvestRewardPerc).div(_divisor);
        if (reinvestFee > 0) {
            require(rewardToken.transfer(msg.sender, reinvestFee), "CNRAutocompound::_reinvest, reward");
        }

        uint systemFee = amount.mul(SystemFeePerc).div(_divisor);
        if (systemFee > 0) {
            require(rewardToken.transfer(sysAddr, systemFee), "CNRAutocompound::_systemfee, fee");
        }

        uint depositTokenAmount = amount.sub(reinvestFee);

        _stakeCNRToken(depositTokenAmount);
        totalDeposits = totalDeposits.add(depositTokenAmount);

        emit Reinvest(totalDeposits, totalSupply);
    }
    
    function _stakeCNRToken(uint amount) private {
        require(amount > 0, "CNRAutocompound::_stakeCNRToken");
        stakingContract.stake(amount);
    }
    
    function checkReward() public view returns (uint) {
        return stakingContract.earned(address(this));
    }

    function getBalance(address account) public view returns (uint) {
        return _balances[account];
    }

    function rescueDeployedFunds(uint minReturnAmountAccepted, bool disableDeposits) external onlyOwner {
        uint balanceBefore = depositToken.balanceOf(address(this));
        stakingContract.exit();
        uint balanceAfter = depositToken.balanceOf(address(this));
        require(balanceAfter.sub(balanceBefore) >= minReturnAmountAccepted, "CNRAutocompound::rescueDeployedFunds");
        totalDeposits = balanceAfter;
        emit Reinvest(totalDeposits, totalSupply);
        if (depositsEnabled == true && disableDeposits == true) {
            setDepositsEnabled(false);
        }
    }

    function getSharesForDepositTokens(uint amount) public view returns (uint) {
        if (totalSupply.mul(totalDeposits) == 0) {
            return amount;
        }
        return amount.mul(totalSupply).div(totalDeposits);
    }

    function getDepositTokensForShares(uint amount) public view returns (uint) {
        if (totalSupply.mul(totalDeposits) == 0) {
            return 0;
        }
        return amount.mul(totalDeposits).div(totalSupply);
    }

    function setReinvestMinValue(uint value) public onlyOwner {
        ReinvestMinValue = value;
    }

    function setReinvestReward(uint value) public onlyOwner {
        ReinvestRewardPerc = value;
    }

    function setSystemFee(uint value) public onlyOwner {
        SystemFeePerc = value;
    }

    function setSysAddr(address value) public onlyOwner {
        sysAddr = value;
    }

    function setDepositsEnabled(bool value) public onlyOwner {
        require(depositsEnabled != value);
        depositsEnabled = value;
    }
}

interface IStakingRewards {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function lastTimeRewardApplicable() external view returns (uint256);
    function rewardPerToken() external view returns (uint256);
    function earned(address account) external view returns (uint256);
    function getRewardForDuration() external view returns (uint256);
    function stake(uint256 amount) external;
    function stakeWithPermit(uint256 amount, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
    function withdraw(uint256 amount) external;
    function getReward() external;
    function exit() external;
    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardsDurationUpdated(uint256 newDuration);
    event Recovered(address token, uint256 amount);
}