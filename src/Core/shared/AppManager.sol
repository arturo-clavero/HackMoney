// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {CollateralManager} from "./CollateralManager.sol";
import {PrivateCoin} from "./../../PrivateCoin.sol";
import {IPrivateCoin} from "./../../interfaces/IPrivateCoin.sol";

struct AppInput {
    string name;
    string symbol;
    uint256 appActions;
    uint256 userActions;
    address[] users;
    address[] tokens;
}

struct AppConfig {
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
    uint256 private latestId = 1;
    mapping(uint256 id => AppConfig) private appConfig;
    mapping(address token => uint256 id) private stablecoins;
    
    event RegisteredApp(address indexed owner, uint256 indexed id, address coin);
 
    //-> called per app at registration
    // * creates id
    // * creates coin
    // * calculates tokens allowed int from array
    // -> stores config: tokens allowed, coin and owner
    function newInstance(AppInput calldata config) external returns (uint256 id) {
        id = latestId;
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
            tokensAllowed |= 1 << colID;
        }
        require (tokensAllowed != 0, "At least One Collateral supported");
        
        appConfig[id] = AppConfig(
            msg.sender,
            coin,
            tokensAllowed
        );

        stablecoins[coin] = id;

        emit RegisteredApp(msg.sender, id, coin);
    }

    //->update(add/delete) user list 
    // use toAdd array : new users to add
    // use toRevoke array : old users to delete
    function updateUserList(uint256 id, address[] memory toAdd, address[] memory toRevoke) public {
        //ONLY APP
        AppConfig storage thisApp = appConfig[id];
        require(msg.sender == thisApp.owner);

        IPrivateCoin(thisApp.coin).updateUserList(toAdd, toRevoke);
    }

    //->add app-specific support for collateral
    // * must already be supported by the protocol
    function addCollateral(uint256 appID, address token) external {
        //ONLY APP
        AppConfig storage thisApp = appConfig[appID];
        require(msg.sender == thisApp.owner);

        uint256 colID = collateralConfig[token].id;
        require(colID != 0, "Collateral not supported by our Protocol");
        thisApp.tokensAllowed |= 1 << colID;
    }


    //->delete app-specific support for collateral
    function removeCollateral(uint256 appID, address token) external {
        //ONLY APP
        AppConfig storage thisApp = appConfig[appID];
        require(msg.sender == thisApp.owner);

        uint256 colID = collateralConfig[token].id;
        require(colID != 0, "Collateral not supported by our Protocol");
        thisApp.tokensAllowed &= ~ (1 << colID);
        require(thisApp.tokensAllowed != 0, "At least One Collateral supported");
    }

    function _isAppCollateralAllowed(uint256 appID, address token) internal view returns (bool) {
        uint256 colID = collateralConfig[token].id;
        return (appConfig[appID].tokensAllowed & 1 << colID != 0);
    }

    //->check app-specific support for collateral
    function _mintAppToken(uint256 appID, address to, uint256 value) internal{
        IPrivateCoin(appConfig[appID].coin).mint(msg.sender, to, value);
    }

    //burn app-specific STABLECOIN
    //  * safe external call
    function _burnAppToken(uint256 appID, uint256 value) internal {
        IPrivateCoin(appConfig[appID].coin).burn(msg.sender, value);
    }

    //trasnfer app-specific STABLECOIN from PERMIT
    //  * safe external call
    function _transferFromAppTokenPermit(uint256 appID, address from, address to, uint256 value) internal {
        IPrivateCoin(appConfig[appID].coin).transferFrom(from, to, value);
    }

    //get STABLECOIN's app id
    function _getStablecoinID(address token) internal view returns (uint256 id) {
        id = stablecoins[token];
        require (id != 0, "Invalid stablecoin address");
    }

    function _getAppConfig(uint256 id) internal returns (AppConfig memory){
        return appConfig[id];
    }
}