// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";

library RiskEngine {

    using SafeERC20 for IERC20;

    // function _receiveToken(address token, uint256 amount) internal payable {
    //     if (token == address(0)) {
    //         // ETH deposit 
    //         require(msg.value != 0, Error.InvalidAmount.selector);
    //         amount = msg.value;
    //     } else { 
    //         //ERC20 deposit
    //         require(msg.value == 0, Error.InvalidAmount.selector);
    //         require(amount != 0, Error.InvalidAmount.selector);
    //         IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
    //     }
    // }

    // function _sendToken(address token, uint256 amount) internal {
    //      require(amount != 0, Error.InvalidAmount.selector);

    //     if (token == address(0)) {
    //         // ETH withdrawal
    //         (bool ok, ) = msg.sender.call{value: amount}("");
    //         require(ok, "ETH transfer failed");
    //     } else {
    //         // ERC20 withdrawal
    //         IERC20(token).safeTransfer(msg.sender, amount);
    //     }
    // }
}