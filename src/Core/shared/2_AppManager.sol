// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {CollateralManager} from "./CollateralManager.sol";
import {PrivateCoin} from "./../../PrivateCoin.sol";
import {IPrivateCoin} from "./../../interfaces/IPrivateCoin.sol";

struct AppUXConfig {
    string name;
    string symbol;
    uint256 appActions;
    uint256 userActions;
    address[] users;
    address[] tokens;
}

struct AppData {
    address owner;
    address coin;
    uint256 tokensAllowed;
    // address[] tokens;
}

/**
 * @notice Management for each app instance
 * @dev stores app specific configurations and manages adding new instances
 */
abstract contract AppManager is CollateralManager {
    uint256 private constant MAX_COLLATERAL_TYPES = 5;
    uint256 private latestId;
    mapping(uint256 id => AppData) internal appData;
    
    function newInstance(AppUXConfig calldata config) external {
        uint256 id = latestId;
        latestId = id + 1;

        address coin = address(new PrivateCoin(
            config.name,
            config.symbol,
            config.appActions,
            config.userActions,
            config.users,
            msg.sender
        ));

        uint256 tokensAllowed;
        uint256 len = config.tokens.length;
        require(len < MAX_COLLATERAL_TYPES);
        for (uint256 i = 0; i < len; i ++){
            uint256 colID = collateralConfig[config.tokens[i]].id;
            if (colID == 0) continue;
            tokensAllowed |= colID;
        }
        require (tokensAllowed != 0, "At least One Collateral supported");
        
        appData[id] = AppData(
            msg.sender,
            coin,
            tokensAllowed
        );
    }

    function updateUserList(uint256 id, address[] memory toAdd, address[] memory toRevoke) public {
        //ONLY APP
        AppData storage thisApp = appData[id];
        require(msg.sender == thisApp.owner);

        IPrivateCoin(thisApp.coin).updateUserList(toAdd, toRevoke);
    }

    function addCollateral(uint256 appID, address token) external {
        //ONLY APP
        AppData storage thisApp = appData[appID];
        require(msg.sender == thisApp.owner);

        uint256 colID = collateralConfig[token].id;
        require(colID != 0, "Collateral not yet supported by our Protocol");
        thisApp.tokensAllowed |= colID;
    }

    function removeCollateral(uint256 appID, address token) external {
        //ONLY APP
        AppData storage thisApp = appData[appID];
        require(msg.sender == thisApp.owner);

        uint256 colID = collateralConfig[token].id;
        require(colID != 0, "Collateral not yet supported by our Protocol");
        thisApp.tokensAllowed &= ~colID;
        require(thisApp.tokensAllowed != 0, "At least One Collateral supported");
    }

    function _isAppCollateralAllowed(uint256 appID, address token) internal view returns (bool) {
        uint256 colID = collateralConfig[token].id;
        return (appData[appID].tokensAllowed & colID != 0);
    }

    function _mintAppToken(uint256 appID, address to, uint256 value) internal{
        IPrivateCoin(appData[appID].coin).mint(msg.sender, to, value);
    }

    function _burnAppToken(uint256 appID, uint256 value) internal {
        IPrivateCoin(appData[appID].coin).burn(msg.sender, value);
    }

    function _transferAppToken(uint256 appID, address to, uint256 value) internal {
        IPrivateCoin(appData[appID].coin).transferFrom(msg.sender, to, value);
    }
}