// test/base/BaseEconomicTest.sol
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/Core/HardPeg.sol";
import {MockToken} from "../mocks/MockToken.sol";
import {IPeg} from "./IPeg.sol";
import "./CoreLib.t.sol";
import "@openzeppelin/utils/Strings.sol";


abstract contract BaseEconomicTest is Test {
    using Strings for uint256;

    IPeg peg;

    address owner = address(0x1);
    address timelock = address(0x2);

    MockToken[] tokens;
    uint256 totalTokens;

    address[] users;
    uint256[] usersPK;
    uint256 totalUsers;
    uint256 globalDebtcap = 1000000;
    uint256 mintCapPerTx = 10000;

    mapping(uint256 id => address) appOwners;
    uint256[] appIDs;
    uint256 totalApps;

    uint256 constant ID1 = 1;
    uint256 constant ID2 = 2;

    // child test decides WHICH peg
    function _deployPeg() internal virtual returns (IPeg){
        HardPeg hard = new HardPeg(owner, timelock, globalDebtcap, mintCapPerTx);
        return IPeg(address(hard));
    }

    function _setUpUsers(uint256 _totalUsers) private {
        users = new address[](_totalUsers);
        usersPK = new uint256[](_totalUsers);
        for (uint256 i = 0; i < _totalUsers; i++){
            string memory seed = string(abi.encodePacked("user", i.toString()));
            (address newUser, uint256 pk) = makeAddrAndKey(seed);
            users[i] = newUser;
            usersPK[i]= pk;
        }
        totalUsers = _totalUsers;
    }
    function _setUpCol(uint256[] memory modes, uint8[] memory decimals) private {
        uint256 len = modes.length;
        tokens = new MockToken[](len);
        assertEq(len, decimals.length);
        for(uint256 i = 0 ; i < len; i ++){
            MockToken newToken = _addGlobalCollateral(modes[i], decimals[i]);
            _mintTokenTo(newToken, 1000, users);
            tokens[i] = newToken;
        }
        totalTokens = len;
    }

    function _setUpApps(uint256 _totalApps) private {
        for (uint256 i = 0; i < appIDs.length; i++){
            uint256 id = appIDs[i];
            delete appOwners[id];
        }
        appIDs = new uint256[](_totalApps);
        for (uint256 i = 0; i < _totalApps; i++){
            bytes32 seed = keccak256(abi.encodePacked("app", i));
            address newAppOwner = vm.addr(uint256(seed));
            uint256 newAppId = _addApp(newAppOwner);
            appOwners[newAppId] = newAppOwner;
            appIDs[i] = newAppId;
        }
        totalApps = _totalApps;
    }

    function setUpBase(uint256[] memory modes, uint8[] memory decimals, uint256 _totalUsers, uint256 _totalApps) internal {
        peg = _deployPeg();
        vm.prank(owner);
        peg.finishSetUp(address(0));
        _updateBase(modes, decimals, _totalUsers, _totalApps);
    }

    function _updateBase(uint256[] memory modes, uint8[] memory decimals, uint256 _totalUsers, uint256 _totalApps) internal virtual{
        _setUpUsers(_totalUsers);
        _setUpCol(modes, decimals);
        _setUpApps(_totalApps);
    }

//set up helpers
    function _raw(uint256 amount, address token) internal view returns (uint256){
        uint8 d;

        if (token == address(0)) d = uint8(18);
        else d = MockToken(token).decimals();

        uint256 scale = 10 ** d;
        return(amount * scale);
    }

    function _val(uint256 amount, address token) internal view returns (uint256){
        uint8 d;

        if (token == address(0)) d = uint8(18);
        else d = MockToken(token).decimals();
        uint256 scale = 10 ** d; 
        return(amount / scale);
    }

    function _addGlobalCollateral(uint256 mode, uint8 decimals) internal returns (MockToken token) {
        token = new MockToken(decimals);
        vm.startPrank(timelock);
        peg.updateGlobalCollateral(Core._collateralInput(address(token), mode));
        vm.stopPrank();
    }

    function _addGlobalCollateral(address token, uint256 mode) internal {
        vm.startPrank(timelock);
        peg.updateGlobalCollateral(Core._collateralInput(token, mode));
        vm.stopPrank();
    }

    function _addNewToken(address token, uint256 id) internal {
        vm.prank(appOwners[id]);
        try peg.addAppCollateral(id, token) {
        } catch {
            // failed, probably because token is not global yet
            _addGlobalCollateral(token, Core.COL_MODE_STABLE);
            vm.prank(appOwners[id]);
            peg.addAppCollateral(id, token);
        }
    }

    function _mintTokenTo(MockToken token, uint256 valueAmount, address[] memory _users) internal {
        uint256 len = _users.length;
        for (uint256 i = 0; i < len; i++){
            token.mint(_users[i], _raw(valueAmount, address(token)));
            vm.startPrank(_users[i]);
            token.approve(address(peg), type(uint256).max);
            vm.stopPrank();
        }
    }

    function _mintTokenTo(MockToken token, uint256 valueAmount, address _user) internal {
        token.mint(_user, _raw(valueAmount, address(token)));
        vm.startPrank(_user);
        token.approve(address(peg), type(uint256).max);
        vm.stopPrank();
    }

    function _addApp(address _appOwner) private returns (uint256 id) {
        address[] memory tokensAddress = new address[](totalTokens);
        for (uint256 i = 0; i < totalTokens; i++){
            tokensAddress[i] = address(tokens[i]);
        }
        AppInput memory input = Core._newAppInstanceInput(users, tokensAddress);
        vm.startPrank(_appOwner);
        id = peg.newInstance(input);
        vm.stopPrank();
    }

    function _assertConservation() internal  {
        uint256 sum = _calculateTotalCollateral(false, new uint256[](0));
        assertEq(sum, peg.getTotalPool(), "collateral not conserved");

        sum =  _calculateTotalDebt();
        assertEq(sum, peg.getTotalSupply(), "supply not conserved");

    }

    function _assertSolvency() internal view {
        assertGe(peg.getTotalPool(), peg.getTotalSupply(), "system insolvent");
    }

    function _calculateTotalCollateral(bool usePrice, uint256[] memory price) internal virtual returns (uint256 sum){
        for (uint256 i = 0; i < totalTokens; i++){
            uint256 value = peg.getGlobalPool(address(tokens[i]));
            if (usePrice) value = value * price[i]/ 1e18;
            sum += value;
        }
    }

    function _calculateTotalDebt() internal virtual returns (uint256 sum){
        for (uint256 i = 0; i < totalApps; i++){
            address coin = peg.getAppCoin(appIDs[i]);
            sum += IERC20(coin).totalSupply();
        }
    }
}