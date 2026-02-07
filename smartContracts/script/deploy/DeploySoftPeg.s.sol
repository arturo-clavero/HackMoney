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
        address fakeToken = address(core._newToken());
        uint256 stableMode = core.COL_MODE_STABLE;
        address[] memory fakeFeeds = new address[](3);
        fakeFeeds[0] = address(0xA);
        fakeFeeds[1] = address(0xB);
        fakeFeeds[2] = address(0xC);

        softPeg.updateGlobalCollateral(CollateralInput({
            tokenAddress: fakeToken,
            mode: stableMode,
            oracleFeeds: fakeFeeds,
            LTV: 0,
            liquidityThreshold: 0,
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