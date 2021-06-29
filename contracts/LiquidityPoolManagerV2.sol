// SPDX-License-Identifier: MIT


pragma solidity ^0.7.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";


import "./StakingRewards.sol";


contract LiquidityPoolManagerV2 is Ownable, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    EnumerableSet.AddressSet private pools;
    mapping(address => uint) public rewardAmount;

    address public canaryFactory;

    address public treasuryVester;

    address public cnr;

    address public charger;

    uint public numPools = 0;


    constructor(address cnr_,address treasuryVester_,address cnrfactory_,address charger_) {
        canaryFactory = cnrfactory_;
        treasuryVester = treasuryVester_;
        cnr = cnr_;
        charger = charger_;
    }

    function isWhitelisted(address stakeContract) public view returns (bool) {
        return pools.contains(stakeContract);
    }

    function getPool(uint index) public view returns (address) {
        return pools.at(index);
    }

    function addWhitelistedPool(address tokenA, address tokenB, address stakeContract, uint _rewardAmount) public onlyOwner {
        require(stakeContract != address(0), 'LiquidityPoolManager::addWhitelistedPool: stakeContract cannot be the zero address');
        require(isWhitelisted(stakeContract) == false, 'LiquidityPoolManager::addWhitelistedPool: stakeContract already whitelisted');
        require(_rewardAmount > 0, 'LiquidityPoolManager::addWhitelistedPool: rewardAmount cannot be zero');

        require(tokenA != tokenB, 'LiquidityPoolManager::addWhitelistedPool: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'LiquidityPoolManager::addWhitelistedPool: ZERO_ADDRESS');
        require(ICanaryFactory(canaryFactory).getPair(token0, token1) == address(StakingRewards(stakeContract).stakingToken()), 'LiquidityPoolManager::addWhitelistedPool: PAIR_DOESNT_EXISTS');

        pools.add(stakeContract);
        rewardAmount[stakeContract] = _rewardAmount;

        numPools = numPools.add(1);
    }

    function addWhitelistedStakePool(address token, address stakeContract, uint _rewardAmount) public onlyOwner {
        require(stakeContract != address(0), 'LiquidityPoolManager::addWhitelistedStakePool: stakeContract cannot be the zero address');
        require(isWhitelisted(stakeContract) == false, 'LiquidityPoolManager::addWhitelistedStakePool: stakeContract already whitelisted');
        require(_rewardAmount > 0, 'LiquidityPoolManager::addWhitelistedStakePool: rewardAmount cannot be zero');

        require(token != address(0), 'LiquidityPoolManager::addWhitelistedStakePool: ZERO_ADDRESS');
        require(token == address(StakingRewards(stakeContract).stakingToken()), 'LiquidityPoolManager::addWhitelistedStakePool: STAKEADDR_NOT_EQUAL');
        require(IERC20(token).totalSupply() > 0, 'LiquidityPoolManager::addWhitelistedStakePool: token_NOT_A_TOKEN');

        pools.add(stakeContract);
        rewardAmount[stakeContract] = _rewardAmount;

        numPools = numPools.add(1);
    }

    function removeWhitelistedPool(address stakeContract) public onlyOwner {
        require(isWhitelisted(stakeContract), 'LiquidityPoolManager::removeWhitelistedPool: Pool not whitelisted');

        pools.remove(stakeContract);
        rewardAmount[stakeContract] = 0;

        numPools = numPools.sub(1);
    }

    function updateAmount(address stakeContract, uint amount) public onlyOwner {
        require(isWhitelisted(stakeContract), 'LiquidityPoolManager::updateAmount: Pool not whitelisted');
        require(amount > 0, 'LiquidityPoolManager::updateAmount: Amount must be bigger than 0');

        rewardAmount[stakeContract] = amount;
    }

    function distributeTokens() public  {
        require(msg.sender == charger, "LiquidityPoolManager::distributeTokens: charger can call this.");

        address stakeContract;
        uint rewardTokens;

        for (uint i = 0; i < pools.length(); i++) {
            stakeContract = pools.at(i);
           
            rewardTokens = rewardAmount[stakeContract];
            if (rewardTokens > 0) {
                require(ICNR(cnr).transfer(stakeContract, rewardTokens), 'LiquidityPoolManager::distributeTokens: Transfer failed');
                StakingRewards(stakeContract).notifyRewardAmount(rewardTokens);
            }
        }
    }

    function distributeTokensSinglePool(uint pairIndex) public {
        require(msg.sender == charger, "LiquidityPoolManager::distributeTokensSinglePool: charger can call this.");
        require(pairIndex < numPools, 'LiquidityPoolManager::distributeTokensSinglePool: Index out of bounds');

        address stakeContract;
        stakeContract = pools.at(pairIndex);

        uint rewardTokens = rewardAmount[stakeContract];
        if (rewardTokens > 0) {
            require(ICNR(cnr).transfer(stakeContract, rewardTokens), 'LiquidityPoolManager::distributeTokens: Transfer failed');
            StakingRewards(stakeContract).notifyRewardAmount(rewardTokens);
        }
    }

    function vestAllocation() public  {
        require(msg.sender == charger, "LiquidityPoolManager::vestAllocation: charger can call this.");
        ITreasuryVester(treasuryVester).claim();
    }

    function setCharger(address charger_) public onlyOwner {
        charger = charger_;
    }

}

interface ITreasuryVester {
    function claim() external returns (uint);
}

interface ICanaryFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface ICNR {
    function balanceOf(address account) external view returns (uint);
    function transfer(address dst, uint rawAmount) external returns (bool);
}
