// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract AirdropTreasury is Ownable {
    using SafeERC20 for IERC20;

    // Token to custody
    IERC20 public cnr;

    constructor(address cnr_) {
        cnr = IERC20(cnr_);
    }

    /**
     * Transfer CNR to the destination. Can only be called by the contract owner.
     */
    function transfer(address dest, uint amount) external onlyOwner {
        cnr.safeTransfer(dest, amount);
    }

    /**
     * Return the CNR balance of this contract.
     */
    function balance() view external returns(uint) {
        return cnr.balanceOf(address(this));
    }

}