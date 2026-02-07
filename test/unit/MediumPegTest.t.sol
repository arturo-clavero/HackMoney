// test/HardPeg.unit.t.sol
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/Core/MediumPeg.sol";
import "../utils/BaseEconomicTest.t.sol";
import "../utils/CoreLib.t.sol";
import {MockToken} from "../mocks/MockToken.sol";
import {ERC4626Mock} from "@openzeppelin/mocks/token/ERC4626Mock.sol";


contract MediumPegUnitTest is BaseEconomicTest {

    uint256 ID;
    address minter;
    address alice;
    address bob;
    ERC4626Mock usdcVault;
    ERC4626Mock daiVault;
    ERC4626Mock[] vaults;

    function _deployPeg() internal override returns (IPeg) {
        MediumPeg pegMed = new MediumPeg(owner, timelock, globalDebtcap, mintCapPerTx);
        return IPeg(address(pegMed));
    }

    function setUp() public {
        uint256 _totalTokens = 2;
        uint256 _totalUsers = 2;
        uint256 _totalApps = 1;

        uint256[] memory modes = new uint256[](_totalTokens);
        uint8[] memory decimals = new uint8[](_totalTokens);

        for (uint256 i = 0 ; i < _totalTokens; i++){
            modes[i] = Core.COL_MODE_STABLE;
            decimals[i] = i == 0 ? 6 : 18; // USDC 6, DAI 18
        }

        setUpBase(modes, decimals, _totalUsers, _totalApps);

        ID = appIDs[0];
        alice = users[0];
        bob = users[1];
        minter = appOwners[ID];

        // Deploy vaults and set them
        usdcVault = new ERC4626Mock(tokens[0]);
        daiVault  = new ERC4626Mock(tokens[1]);

        vm.prank(minter);
        MediumPeg(address(peg)).setVault(ID, address(usdcVault));

        vm.prank(minter);
        MediumPeg(address(peg)).setVault(ID, address(daiVault));

        vaults.push(usdcVault);
        vaults.push(daiVault);
    }

    // ---- DEPOSIT ----
    function testDepositERC20() public {
        _mintTokenTo(tokens[0], 100, alice);

        vm.startPrank(alice);
        MediumPeg(address(peg)).deposit(ID, _raw(100, address(tokens[0])));
        vm.stopPrank();

        (uint256 principal, uint256 shares) = MediumPeg(address(peg)).getPosition(ID, alice);
        assertEq(principal, _raw(100, address(tokens[0])));
        assertEq(shares, _raw(100, address(tokens[0]))); // vault 1:1
    }

    function testDepositZeroReverts() public {
        vm.prank(alice);
        vm.expectRevert(Error.InvalidTokenAddress.selector); // vault not set or zero amount
        MediumPeg(address(peg)).deposit(ID, 0);
    }
}   