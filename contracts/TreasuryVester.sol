// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract TreasuryVester is Ownable, ReentrancyGuard {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    address public cnr;
    address public recipient;

    uint public vestingAmount = 888_888_330_000_000_000_000_000;

    uint public vestingCliff = 432_000;

    uint public halvingPeriod = 292;

    uint public nextSlash;

    bool public vestingEnabled;

    uint public lastUpdate;

    uint public startingBalance = 512_000_000_000_000_000_000_000_000 ;

    event VestingEnabled();
    event TokensVested(uint amount, address recipient);


    constructor(
        address cnr_
    ) {
        cnr = cnr_;
        lastUpdate = 0;
        nextSlash = halvingPeriod;
    }

    function startVesting() external onlyOwner {
        require(!vestingEnabled, 'TreasuryVester::startVesting: vesting already started');
        require(IERC20(cnr).balanceOf(address(this)) >= startingBalance, 'TreasuryVester::startVesting: incorrect CNR supply');
        require(recipient != address(0), 'TreasuryVester::startVesting: recipient not set');
        vestingEnabled = true;

        emit VestingEnabled();
    }

    function setRecipient(address recipient_) public onlyOwner {
        recipient = recipient_;
    }

    function claim() public nonReentrant returns (uint) {
        require(vestingEnabled, 'TreasuryVester::claim: vesting not enabled');
        require(msg.sender == recipient, 'TreasuryVester::claim: only recipient can claim');
        require(block.timestamp >= lastUpdate + vestingCliff, 'TreasuryVester::claim: not time yet');

        if (nextSlash == 0) {
            nextSlash = halvingPeriod - 1;
            vestingAmount = vestingAmount / 2;
        } else {
            nextSlash = nextSlash.sub(1);
        }

        lastUpdate = block.timestamp;

        emit TokensVested(vestingAmount, recipient);
        IERC20(cnr).safeTransfer(recipient, vestingAmount);

        return vestingAmount;
    }
}