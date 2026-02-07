// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {MediumPeg} from "../../../src/core/MediumPeg.sol";
import {MediumPegAdapter} from "../../../src/adapters/MediumPegAdapter.sol";
import "../../../src/Timelock.sol";
import "../../../src/core/shared/CollateralManager.sol";
import "../../../test/utils/CoreLib.t.sol";

struct DeploymentInfo {
    address mediumPeg;
    address mediumPegAdapter;
}

contract DeployMediumPeg is Script {
    function run() external returns (DeploymentInfo memory info) {
        uint256 deployerPK = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPK);

        vm.startBroadcast(deployerPK);

        // Deploy timelock
        Timelock timelock = new Timelock();

        // Deploy MediumPeg
        address owner = vm.envAddress("OWNER");
        uint256 globalDebtCap = 5_000_000 ether;
        uint256 mintCapPerTx = 1_000 ether;
        MediumPeg mediumPeg = new MediumPeg(
            deployer,
            address(timelock),
            globalDebtCap,
            mintCapPerTx
        );

        // Deploy adapter for frontend
        MediumPegAdapter mediumPegAdapter = new MediumPegAdapter(address(mediumPeg));
        // Now frontend or other scripts can interact via adapter
        // Example: adapter address: mediumPegAdapter.address

        // Register collateral
        address fakeToken = address(core._newToken());
        uint256 stableMode = core.COL_MODE_STABLE;
        address[] memory fakeFeeds = new address[](3);
        fakeFeeds[0] = address(0xA);
        fakeFeeds[1] = address(0xB);
        fakeFeeds[2] = address(0xC);

        mediumPeg.updateGlobalCollateral(CollateralInput({
            tokenAddress: fakeToken,
            mode: stableMode,
            oracleFeeds: fakeFeeds,
            LTV: 0,
            liquidityThreshold: 0,
            debtCap: 200_000 ether
        }));

        //Update timelock to point to protocol (if needed)
        // timelock.setProtocol(address(mediumPeg));

        // Finish setup & transfer ownership to multisig
        mediumPeg.finishSetUp(owner);

        vm.stopBroadcast();

        console.log("Deployment Info ");
        console.log("MediumPeg core contract:   ", address(mediumPeg));
        console.log("MediumPeg adapter:        ", address(mediumPegAdapter));
        info = DeploymentInfo(address(mediumPeg), address(mediumPegAdapter));
    }
}