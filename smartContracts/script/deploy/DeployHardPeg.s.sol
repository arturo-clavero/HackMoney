// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {HardPeg} from "../../../src/core/HardPeg.sol";
import {HardPegAdapter} from "../../../src/adapters/HardPegAdapter.sol";
import "../../../src/Y_Timelock.sol";
import "../../../src/core/shared/CollateralManager.sol";
import "../../../test/utils/CoreLib.t.sol";

struct DeploymentInfo {
    address hardPeg;
    address hardPegAdapter;
}

contract DeployHardPeg is Script {
    function run() external returns (DeploymentInfo memory info) {
        uint256 deployerPK = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPK);

        vm.startBroadcast(deployerPK);

        // Deploy timelock
        Timelock timelock = new Timelock();

        // Deploy HardPeg
        address owner = vm.envAddress("OWNER");
        uint256 globalDebtCap = 5_000_000 ether;
        uint256 mintCapPerTx = 1_000 ether;
        HardPeg hardPeg = new HardPeg(
            deployer,
            address(timelock),
            globalDebtCap,
            mintCapPerTx
        );

        // Deploy adapter for frontend
        HardPegAdapter hardPegAdapter = new HardPegAdapter(address(hardPeg));
        // Now frontend or other scripts can interact via adapter
        // Example: adapter address: hardPegAdapter.address

        // Register collateral
        uint256 stableMode = core.COL_MODE_STABLE;

        address pyusd = 0xCaC524BcA292aaade2DF8A05cC58F0a65B1B3bB9;
        address[] memory feeds1 = new address[](1);
        fakeFeeds[0] = address(0x57020Ba11D61b188a1Fd390b108D233D87c06057); //pyusd
        hardPeg.updateGlobalCollateral(CollateralInput({
            tokenAddress: pyusd,
            mode: stableMode,
            oracleFeeds: feeds1,
            LTV: 98,
            liquidityThreshold: 100,
            debtCap: 200_000 ether
        }));

        address usdc = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
        address[] memory feeds2 = new address[](1);
        fakeFeeds[0] = address(0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E); //usdc
         hardPeg.updateGlobalCollateral(CollateralInput({
            tokenAddress: usdc,
            mode: stableMode,
            oracleFeeds: feeds2,
            LTV: 98,
            liquidityThreshold: 100,
            debtCap: 200_000 ether
        }));

        address dai = 0x776b6fc2ed15d6bb5fc32e0c89de68683118c62a;
        address[] memory feeds3 = new address[](1);
        fakeFeeds[0] = address(0x14866185B1962B63C3Ea9E03Bc1da838bab34C19); //dai
         hardPeg.updateGlobalCollateral(CollateralInput({
            tokenAddress: dai,
            mode: stableMode,
            oracleFeeds: feeds3,
            LTV: 98,
            liquidityThreshold: 100,
            debtCap: 200_000 ether
        }));
        //Update timelock to point to protocol (if needed)
        // timelock.setProtocol(address(hardPeg));

        // Finish setup & transfer ownership to multisig
        hardPeg.finishSetUp(owner);

        vm.stopBroadcast();

        console.log("Deployment Info ");
        console.log("HardPeg core contract:   ", address(hardPeg));
        console.log("HardPeg adapter:        ", address(hardPegAdapter));
        info = DeploymentInfo(address(hardPeg), address(hardPegAdapter));
    }
}