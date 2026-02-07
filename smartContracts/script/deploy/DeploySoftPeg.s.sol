// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {SoftPeg} from "../../../src/core/SoftPeg.sol";
import {SoftPegAdapter} from "../../../src/adapters/SoftPegAdapter.sol";
import "../../../src/Y_Timelock.sol";
import "../../../src/core/shared/CollateralManager.sol";
import "../../../test/utils/CoreLib.t.sol";

struct DeploymentInfo {
    address softPeg;
    address softPegAdapter;
}

contract DeploySoftPeg is Script {
    function run() external returns (DeploymentInfo memory info) {
        uint256 deployerPK = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPK);

        vm.startBroadcast(deployerPK);

        // Deploy timelock
        Timelock timelock = new Timelock();

        // Deploy SoftPeg
        address owner = vm.envAddress("OWNER");
        uint256 globalDebtCap = 5_000_000 ether;
        uint256 mintCapPerTx = 1_000 ether;
        SoftPeg softPeg = new SoftPeg(
            deployer,
            address(timelock),
            globalDebtCap,
            mintCapPerTx
        );

        // Deploy adapter for frontend
        SoftPegAdapter softPegAdapter = new SoftPegAdapter(address(softPeg));
        // Now frontend or other scripts can interact via adapter
        // Example: adapter address: softPegAdapter.address


        // Register collateral
        uint256 stableMode = core.COL_MODE_STABLE;
        uint256 volatileMode = core.COL_MODE_VOLATILE;
        uint256 yieldMode = core.COL_MODE_YIELD;

        //collateral stable
        address pyusd = address(core._newToken());
        address[] memory feeds1 = new address[](1);
        feeds1[0] = address(0x57020Ba11D61b188a1Fd390b108D233D87c06057);//Pyusd/usd

        softPeg.updateGlobalCollateral(CollateralInput({
            tokenAddress: pyusd, //pyusd
            mode: stableMode,
            oracleFeeds: feeds1,
            LTV: 100,
            liquidityThreshold: 100,
            debtCap: 200_000 ether
        }));


        // Register volotile
        address linkToken = address(core._newToken());
        address[] memory feeds2 = new address[](1);
        feeds2[0] = address(0xc59E3633BAAC79493d908e63626716e204A45EdF);//link/usd

        softPeg.updateGlobalCollateral(CollateralInput({
            tokenAddress: linkToken,
            mode: volatileMode,
            oracleFeeds: feeds2,
            LTV: 70,
            liquidityThreshold: 75,
            debtCap: 200_000 ether
        }));

// Register collateral3 stable
        address daiToken = address(core._newToken());
        address[] memory feeds3 = new address[](1);
        feeds3[0] = address(0x14866185B1962B63C3Ea9E03Bc1da838bab34C19); //dai/usd

        softPeg.updateGlobalCollateral(CollateralInput({
            tokenAddress: daiToken, //dai
            mode: stableMode, // chamge
            oracleFeeds: feeds3,
            LTV: 100, //50 - 70 -> if its a stable leave at 100 
            liquidityThreshold: 100, //60-80 -> if its a stable 100
            debtCap: 200_000 ether
        }));

        //Update timelock to point to protocol (if needed)
        // timelock.setProtocol(address(softPeg));

        // Finish setup & transfer ownership to multisig
        softPeg.finishSetUp(owner);

        vm.stopBroadcast();

        console.log("Deployment Info ");
        console.log("SoftPeg core contract:   ", address(softPeg));
        console.log("SoftPeg adapter:        ", address(softPegAdapter));
        info = DeploymentInfo(address(softPeg), address(softPegAdapter));
    }
}