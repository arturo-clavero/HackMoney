// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/Core/shared/AppManager.sol";
import "../../src/Core/shared/AccessManager.sol";
import "../utils/CoreLib.t.sol";

contract AppManagerHarness is AppManager {
    address public owner;
    address public timelock;

    constructor(address timelock_, address owner_) 
    CollateralManager(0) 
    AccessManager(owner_, timelock_) {
        owner = owner_;
        timelock = timelock_;
    }

    function exposed_isAllowed(uint256 id, address token) external view returns (bool) {
        return _isAppCollateralAllowed(id, token);
    }

    function exposed_mint(uint256 id, address to, uint256 value) external {
        _mintAppToken(id, to, value);
    }

    function exposed_burn(uint256 id, uint256 value) external {
        _burnAppToken(id, value);
    }

    function exposed_transfer(uint256 id, address from, address to, uint256 value) external {
        _transferFromAppTokenPermit(id, from, to, value);
    }
    
    function exposed_getStablecoinID(address token) external view returns (uint256) {
        return _getStablecoinID(token);
    }

    function exposed_getAppConfig(uint256 id) external view returns (AppConfig memory){
        return _getAppConfig(id);
    }

}

contract AppManagerTest is Test {
    AppManagerHarness manager;

    address timelock = vm.addr(0xDEAD);
    // Users
    address owner = address(0xA);
    address user1 = address(0xB);
    address user2 = address(0xC);
    address user3;
    uint256 user3PK;
    address alien = address(0xD);

    // Collateral
    address col1;
    address col2;
    address col3;
    address notSupportedCol = address(0x104);

    event RegisteredApp(address indexed owner, uint256 indexed id, address coin);

    function setUp() public {
        manager = new AppManagerHarness(timelock, owner);
        (user3, user3PK) = makeAddrAndKey("alice");

        col1 = Core._newToken();
        col2 = Core._newToken();
        col3 = Core._newToken();

        vm.startPrank(owner);
        manager.updateGlobalCollateral(Core._collateralInput(col1, Core.COL_MODE_STABLE));
        manager.updateGlobalCollateral(Core._collateralInput(col2, Core.COL_MODE_STABLE));
        manager.updateGlobalCollateral(Core._collateralInput(col3, Core.COL_MODE_STABLE));
        manager.finishSetUp(address(0));
        vm.stopPrank();
    }


    function _defaultUsers() internal view returns (address[] memory users) {
        users = new address[](3);
        users[0] = user1;
        users[1] = user2;
        users[2] = user3;
    }

    function _defaultTokens() internal view returns (address[] memory tokens) {
        tokens = new address[](2);
        tokens[0] = col1;
        tokens[1] = col2;
    }

    function _defaultInput() internal view returns (AppInput memory input) {
        input = Core._newAppInstanceInput();
        input.tokens = _defaultTokens();
        input.users = _defaultUsers();
    }

    function _singleUser(address user) internal pure returns (address[] memory users) {
        users = new address[](1);
        users[0] = user;
    }

    function _emptyAddr() internal pure returns (address[] memory arr) {
        arr = new address[](0);
    }

    // newInstance
    function testNewInstance_Success() public {
        AppInput memory input = _defaultInput();

        vm.prank(owner);
        uint256 id = manager.newInstance(input);

        AppConfig memory cfg = manager.exposed_getAppConfig(id);
        assertTrue(cfg.coin != address(0));
        assertEq(cfg.tokensAllowed, (1 << 1) | (1 << 2));
        assertEq(cfg.owner, owner);
    }

    function testNewInstance_CorrectId() public {
        AppInput memory input = _defaultInput();
        assertEq(manager.newInstance(input), 1);
        assertEq(manager.newInstance(input), 2);
        assertEq(manager.newInstance(input), 3);
        assertEq(manager.newInstance(input), 4);
    }

    function testNewInstance_Revert_NoCollateral() public {
        AppInput memory input = _defaultInput();
        input.tokens = new address[](1);
        input.tokens[0] = address(0xdead); // id = 0

        vm.prank(owner);
        vm.expectRevert(Error.AtLeastOneCollateralSupported.selector);
        manager.newInstance(input);
    }

    function testNewInstance_Revert_TooManyCollateral() public {
        AppInput memory input = _defaultInput();
        input.tokens = new address[](1); // more than MAX_COLLATERAL_TYPES

        vm.prank(owner);
        vm.expectRevert();
        manager.newInstance(input);
    }

        function testAddAllowedCollateral() public {
        AppInput memory input = _defaultInput();
        input.tokens = new address[](1); 
        input.tokens[0] = col1;

        vm.prank(owner);
        manager.newInstance(input);

        assertTrue(manager.exposed_isAllowed(1, col1));
    }

    function testAddNotAllowedCollateralSkip() public {
        AppInput memory input = _defaultInput();
        input.tokens = new address[](3); 
        input.tokens[0] = col1;
        input.tokens[1] = notSupportedCol;
        input.tokens[2] = col2;

        vm.prank(owner);
        manager.newInstance(input);

        assertFalse(manager.exposed_isAllowed(1, notSupportedCol));
        assertTrue(manager.exposed_isAllowed(1, col1));
        assertTrue(manager.exposed_isAllowed(1, col2));
    }

    function testAddNotAllowedCollateralRevert() public {
        AppInput memory input = _defaultInput();
        input.tokens = new address[](1); 
        input.tokens[0] = notSupportedCol;

        vm.prank(owner);

        vm.expectRevert();
        manager.newInstance(input);
    }
    

    // addUsers
    function testUpdateUserList_OwnerOnly() public {
        vm.prank(owner);
        manager.newInstance(_defaultInput());

        vm.prank(owner);
        manager.addUsers(1, _singleUser(user2));
    }

    function testUpdateUserList_Revert_NotOwner() public {
        vm.prank(owner);
        manager.newInstance(_defaultInput());

        vm.prank(user1);
        vm.expectRevert();
        manager.addUsers(1, _singleUser(user2));
    }

    // addAppCollateral
    function testAddCollateral_Success() public {
        vm.prank(owner);
        manager.newInstance(_defaultInput());

        vm.prank(owner);
        manager.addAppCollateral(1, col3);
        assertTrue(manager.exposed_isAllowed(1, col3));
    }

    function testAddCollateral_Revert_NotOwner() public {
        vm.prank(owner);
        manager.newInstance(_defaultInput());

        vm.prank(user1);
        vm.expectRevert();
        manager.addAppCollateral(1, col3);
    }

    function testAddCollateral_Revert_Unsupported() public {
        vm.prank(owner);
        manager.newInstance(_defaultInput());

        vm.prank(owner);
        vm.expectRevert(Error.CollateralNotSupportedByProtocol.selector);
        manager.addAppCollateral(1, address(0xdead));
    }

    // removeAppCollateral
    function testremoveGlobalCollateral_Success() public {
        vm.prank(owner);
        manager.newInstance(_defaultInput());

        vm.prank(owner);
        manager.removeAppCollateral(1, col2);
        assertFalse(manager.exposed_isAllowed(1, col2));
    }

    function testremoveGlobalCollateral_Revert_LastCollateral() public {
        AppInput memory input = _defaultInput();
        input.tokens = new address[](1); 
        input.tokens[0] = col1;

        vm.prank(owner);
        manager.newInstance(input);

        vm.prank(owner);
        vm.expectRevert(Error.AtLeastOneCollateralSupported.selector);
        manager.removeAppCollateral(1, col1);
    }

    // _getStablecoinID
    function testGetStablecoinID_Success() public {
        vm.prank(owner);
        manager.newInstance(_defaultInput());

        address coin = manager.exposed_getAppConfig(1).coin;
        assertEq(manager.exposed_getStablecoinID(coin), 1);
    }

    function testGetStablecoinID_Revert_Invalid() public {
        vm.expectRevert(Error.InvalidTokenAddress.selector);
        manager.exposed_getStablecoinID(address(0xdead));
    }

    // mint / transfer / burn
    function testMintBurnTransfer_Delegation() public {
        vm.prank(owner);
        manager.newInstance(_defaultInput());

        address coin = manager.exposed_getAppConfig(1).coin;

        vm.startPrank(owner);
        manager.exposed_mint(1, user3, 10);
        assertEq(IPrivateCoin(coin).balanceOf(user3), 10);
        vm.stopPrank();

        // transfer from requires permit
        uint256 deadline = block.timestamp + 1 days;
        bytes32 digest = Core.getDigest(coin, user3, address(manager), 5, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user3PK, digest);
        IPrivateCoin(coin).permit(user3, address(manager), 5, deadline, v, r, s);

        manager.exposed_transfer(1, user3, user2, 5);
        assertEq(IPrivateCoin(coin).balanceOf(user3), 5);
        assertEq(IPrivateCoin(coin).balanceOf(user2), 5);

        vm.prank(user2);
        manager.exposed_burn(1, 5);
        assertEq(IPrivateCoin(coin).balanceOf(user2), 0);
        vm.stopPrank();
    }

///// getAppTotalSupply Tests

    function testGetAppTotalSupply_InitialZero() public {
        vm.prank(owner);
        manager.newInstance(_defaultInput());

        uint256 supply = IERC20(manager.getAppCoin(1)).totalSupply();
        assertEq(supply, 0, "Initial supply should be 0");
    }

    function testGetAppTotalSupply_AfterMint() public {
        vm.prank(owner);
        manager.newInstance(_defaultInput());

        vm.prank(owner);
        manager.exposed_mint(1, user1, 100);

        uint256 supply = IERC20(manager.getAppCoin(1)).totalSupply();
        assertEq(supply, 100, "Supply should match minted amount");
    }

    function testGetAppTotalSupply_AfterMintAndBurn() public {
        vm.prank(owner);
        manager.newInstance(_defaultInput());

        // mint
        vm.prank(owner);
        manager.exposed_mint(1, user1, 100);

        // burn
        vm.prank(user1);
        manager.exposed_burn(1, 40);

        uint256 supply = IERC20(manager.getAppCoin(1)).totalSupply();
        assertEq(supply, 60, "Supply should account for burned tokens");
    }

    function testGetAppTotalSupply_MultipleUsers() public {
        vm.prank(owner);
        manager.newInstance(_defaultInput());

        // mint to multiple users
        vm.prank(owner);
        manager.exposed_mint(1, user1, 50);
        vm.prank(owner);
        manager.exposed_mint(1, user2, 70);

        uint256 supply = IERC20(manager.getAppCoin(1)).totalSupply();
        assertEq(supply, 120, "Supply should sum across all users");
    }

// newInstance extended tests

    function testNewInstance_EventEmitted() public {
        AppInput memory input = _defaultInput();
        vm.prank(owner);
        vm.expectEmit(true, true, false, false);
        emit RegisteredApp(owner, 1, address(0)); // coin address will be ignored in check
        manager.newInstance(input);
    }

    function testNewInstance_DuplicateCollateralIgnored() public {
        AppInput memory input = _defaultInput();
        input.tokens = new address[](3);
        input.tokens[0] = col1;
        input.tokens[1] = col1; // duplicate
        input.tokens[2] = col2;

        vm.prank(owner);
        uint256 id = manager.newInstance(input);

        AppConfig memory cfg = manager.exposed_getAppConfig(id);
        // Ensure duplicate did not break tokensAllowed
        assertEq(cfg.tokensAllowed, (1 << 1) | (1 << 2));
    }

    function testNewInstance_MaxCollateralBoundary() public {
        AppInput memory input = _defaultInput();
        input.tokens = new address[](5); // exactly MAX_COLLATERAL_TYPES
        input.tokens[0] = col1;
        input.tokens[1] = col2;
        input.tokens[2] = col3;
        input.tokens[3] = Core._newToken();
        input.tokens[4] = Core._newToken();

        vm.prank(owner);
        manager.newInstance(input); // should succeed

        input.tokens = new address[](6); // exactly MAX_COLLATERAL_TYPES
        input.tokens[0] = col1;
        input.tokens[1] = col2;
        input.tokens[2] = col3;
        input.tokens[3] = Core._newToken();
        input.tokens[4] = Core._newToken();
        input.tokens[5] = Core._newToken();
        // > MAX_COLLATERAL_TYPES
        vm.prank(owner);
        vm.expectRevert(); // expect revert
        manager.newInstance(input);
    }

    function testNewInstance_EmptyUserList() public {
        AppInput memory input = _defaultInput();
        input.users = _emptyAddr();

        vm.prank(owner);
        uint256 id = manager.newInstance(input);
        AppConfig memory cfg = manager.exposed_getAppConfig(id);
        assertTrue(cfg.coin != address(0));
    }

// addUsers extended tests

    function testUpdateUserList_EmptyArrays() public {
        vm.prank(owner);
        manager.newInstance(_defaultInput());

        vm.prank(owner);
        manager.addUsers(1, _emptyAddr());
    }

// add/remove collateral extended tests

    function testAddAlreadyAddedCollateral() public {
        vm.prank(owner);
        manager.newInstance(_defaultInput());

        vm.prank(owner);
        manager.addAppCollateral(1, col1); // already added, should not fail
        assertTrue(manager.exposed_isAllowed(1, col1));
    }

    function testRemoveCollateralNotEnabled() public {
        vm.prank(owner);
        manager.newInstance(_defaultInput());

        // Removing col3 which was never added
        vm.prank(owner);
        manager.removeAppCollateral(1, col3);
        assertFalse(manager.exposed_isAllowed(1, col3));
    }

// mint / burn / transfer extended tests

    function testMintToZeroAddress() public {
        vm.prank(owner);
        manager.newInstance(_defaultInput());

        vm.prank(owner);
        vm.expectRevert(); // should revert if minting to zero address
        manager.exposed_mint(1, address(0), 10);
    }

    function testBurnMoreThanBalance() public {
        vm.prank(owner);
        manager.newInstance(_defaultInput());

        vm.prank(owner);
        manager.exposed_mint(1, user1, 10);

        vm.prank(user1);
        vm.expectRevert(); // burn > balance
        manager.exposed_burn(1, 20);
    }

    function testTransferMoreThanBalance() public {
        vm.prank(owner);
        manager.newInstance(_defaultInput());

        vm.prank(owner);
        manager.exposed_mint(1, user1, 10);

        // transfer > balance
        vm.startPrank(user1);
        vm.expectRevert();
        manager.exposed_transfer(1, user1, user2, 20);
        vm.stopPrank();
    }

    function testBurnFromZeroAddress() public {
        vm.prank(owner);
        manager.newInstance(_defaultInput());

        vm.prank(address(0));
        vm.expectRevert();
        manager.exposed_burn(1, 10);
    }

    function testTransferToZeroAddress() public {
        vm.prank(owner);
        manager.newInstance(_defaultInput());

        vm.prank(owner);
        manager.exposed_mint(1, user1, 10);

        vm.startPrank(user1);
        vm.expectRevert();
        manager.exposed_transfer(1, user1, address(0), 5);
        vm.stopPrank();
    }

    function testGetStablecoinID_MultipleApps() public {
        vm.prank(owner);
        uint256 id1 = manager.newInstance(_defaultInput());
        vm.prank(owner);
        uint256 id2 = manager.newInstance(_defaultInput());

        address coin1 = manager.exposed_getAppConfig(id1).coin;
        address coin2 = manager.exposed_getAppConfig(id2).coin;

        assertEq(manager.exposed_getStablecoinID(coin1), id1);
        assertEq(manager.exposed_getStablecoinID(coin2), id2);
    }

    function testNewInstance_RevertBeforeSetup() public {
        AppInput memory input = _defaultInput();

        AppManagerHarness preSetupManager = new AppManagerHarness(timelock, owner);

        vm.prank(owner);
        vm.expectRevert(Error.InvalidAccess.selector);
        preSetupManager.newInstance(input);
    }

}
