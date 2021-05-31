// SPDX-License-Identifier: MIT


pragma solidity ^0.7.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


import "./StakingRewards.sol";


contract LiquidityPoolManager is Ownable, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeMath for uint;

    EnumerableSet.AddressSet private pools;
    mapping(address => uint) public rewardAmount;

    address public treasuryVester;

    address public cnr;

    uint public numPools = 0;

    constructor(address cnr_,address treasuryVester_) {
        treasuryVester = treasuryVester_;
        cnr = cnr_;
    }

    function isWhitelisted(address stakeContract) public view returns (bool) {
        return pools.contains(stakeContract);
    }


    function getPool(uint index) public view returns (address) {
        return pools.at(index);
    }

    function addWhitelistedPool(address stakeContract, uint _rewardAmount) public onlyOwner {
        require(stakeContract != address(0), 'LiquidityPoolManager::addWhitelistedPool: stakeContract cannot be the zero address');
        require(isWhitelisted(stakeContract) == false, 'LiquidityPoolManager::addWhitelistedPool: stakeContract already whitelisted');


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
        require(amount>0, 'LiquidityPoolManager::updateAmount: Amount must be bigger than 0');

        rewardAmount[stakeContract] = amount;
    }

    function distributeTokens() public onlyOwner  {

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

    function distributeTokensSinglePool(uint pairIndex) public onlyOwner {
        require(pairIndex < numPools, 'LiquidityPoolManager::distributeTokensSinglePool: Index out of bounds');

        address stakeContract;
        stakeContract = pools.at(pairIndex);

        uint rewardTokens = rewardAmount[stakeContract];
        if (rewardTokens > 0) {
            require(ICNR(cnr).transfer(stakeContract, rewardTokens), 'LiquidityPoolManager::distributeTokens: Transfer failed');
            StakingRewards(stakeContract).notifyRewardAmount(rewardTokens);
        }
    }

    function vestAllocation() public onlyOwner  {
        ITreasuryVester(treasuryVester).claim();
    }

}

interface ITreasuryVester {
    function claim() external returns (uint);
}

interface ICNR {
    function balanceOf(address account) external view returns (uint);
    function transfer(address dst, uint rawAmount) external returns (bool);
}
