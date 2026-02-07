// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../src/Core/shared/CollateralManager.sol";
import "../../src/Core/shared/AppManager.sol";
import "../../src/utils/ActionsLib.sol";
import "../../src/PrivateCoin.sol";
import "../../src/interfaces/IPrivateCoin.sol";
import "../mocks/MockToken.sol";
import "../mocks/MockOracle.sol";
import {IERC20Metadata} from "@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";

library Core {

//PC users ACTIONS
    uint256 constant defaultUserAction = Actions.HOLD | Actions.TRANSFER_DEST;
    uint256 constant defaultAppAction = Actions.MINT;


    //APP - COLLATERAL

    uint256 constant COL_MODE_STABLE   = 1 << 0;
    uint256 constant COL_MODE_VOLATILE = 1 << 1;
    uint256 constant COL_MODE_YIELD    = 1 << 2;
    uint256 constant COL_MODE_ACTIVE   = 1 << 3;

    uint256 constant PEG_HARD = 0;
    uint256 constant PEG_MED  = 1;
    uint256 constant PEG_SOFT = 2;

    function _newAppInstanceInput() internal pure returns (AppInput memory input) {
        input = AppInput({
            name: "TestCoin",
            symbol: "TC",
            appActions: Core.defaultAppAction, //allowing apps to mint to users
            userActions: Core.defaultUserAction, //allwoing users to hold and transfer
            users: new address[](0),
            tokens: new address[](0)
        });
    }
//app can deposit 500 to user
//app can mint 500 * LTV to user

    function _newAppInstanceInput(address[] memory users, address[] memory tokens) internal pure returns (AppInput memory input) {
        input = AppInput({
            name: "TestCoin",
            symbol: "TC",
            appActions: Core.defaultAppAction,
            userActions: Core.defaultUserAction,
            users: users,
            tokens: tokens
        });
    }

    function _newToken() internal returns (address){
        MockToken token = new MockToken(18);
        return address(token);
    }

//adding global collateral
    function _collateralInput(address token, uint256 mode)
        internal
        returns (CollateralInput memory)
    {
        MockAggregator m = new MockAggregator("x / y", 8);
        m.setPrice(int(10 ** 8));

        address[] memory feeds = new address[](1);
        feeds[0] = address(m);
        return CollateralInput({
            tokenAddress: token,
            mode: mode,
            oracleFeeds: feeds,
            LTV: 50, // 50 % -> deposit 300 I can mint 150
            liquidityThreshold: 80,
            debtCap: 1000
        });
    }

    function _collateralInput()
        internal
        returns (CollateralInput memory)
    {
        MockAggregator m = new MockAggregator("x / y", 8);
        m.setPrice(int(10 ** 8));
        address[] memory feeds = new address[](1);
        feeds[0] = address(m);
        return CollateralInput({
            tokenAddress: _newToken(),
            mode: COL_MODE_STABLE,
            // mode: COL_MODE_YIELD,
            oracleFeeds: feeds,
            LTV: 50,
            liquidityThreshold: 80,
            debtCap: 1000
        });
    }
//ltv 30 
//In 600 >
//Out 300 >
// | 600 col | 300 debt |
// | 400 col | 300 debt | 
// 400 * 80 

//collateral backed... and multiply by ltv 
    function _collateralInputWithFeed(address token, uint256 mode, address feed)
        internal
        pure
        returns (CollateralInput memory)
    {
        address[] memory feeds = new address[](1);
        feeds[0] = feed;
        return CollateralInput({
            tokenAddress: token,
            mode: mode,
            oracleFeeds: feeds,
            LTV: 50,
            liquidityThreshold: 80,
            debtCap: 1000
        });
    }

    function getDigest(
        address coin,
        address owner,
        address allowed,
        uint256 value,
        uint256 deadline
    ) internal view returns (bytes32 digest) {
        digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                IPrivateCoin(coin).DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256(
                            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                        ),
                        owner,
                        allowed,
                        value,
                        IPrivateCoin(coin).nonces(owner),
                        deadline
                    )
                )
            )
        );
    }

}