// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {HardPeg} from "./testAll.sol";
import "../../../src/Y_Timelock.sol";
import "../../../src/Core/shared/CollateralManager.sol";
import "../../../test/utils/CoreLib.t.sol";

//Update timelock deployment & adding protocol inside timelock
contract DeployHardPeg is Script {
    function run() external {
        uint256 deployerPK = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPK);

        vm.startBroadcast(deployerPK);

        // 1. (todo) | Deploy timelock
        Timelock timelock = new Timelock();

        // 2. Deploy protocol with deployer as temporary owner
        address owner = vm.envAddress("OWNER");
        uint256 globalDebtCap = 5_000_000 ether;
        uint256 mintCapPerTx = 1_000 ether;
        HardPeg protocol = new HardPeg(
            deployer,
            address(timelock),
            globalDebtCap,
            mintCapPerTx
        );

        // 3. Register all collateral pre-setup | (todo)
        // struct CollateralInput {
        //     address     tokenAddress;
        //     uint256     mode;                | =Core.COL_MODE_STABLE
        //     address[]   oracleFeeds;
        //     uint256     LTV;                 | =100
        //     uint256     liquidityThreshold;  | =0
        //     uint256     debtCap;             | A big number (total max of this collateral)        
        // }

        address fakeToken = address(Core._newToken());
        uint256 stableMode = Core.COL_MODE_STABLE;
        address[] memory fakeFeeds = new address[](3);
        fakeFeeds[0] = address(0xA);
        fakeFeeds[1] = address(0xB);
        fakeFeeds[2] = address(0xC); 

        protocol.updateGlobalCollateral(CollateralInput({
            tokenAddress: fakeToken,    //must update
            mode: stableMode,           // do not change
            oracleFeeds : fakeFeeds,    // must update
            LTV: 0,                     // irrelevant for hard peg (ex: 100)
            liquidityThreshold: 0,      // irrelevant for hard peg(ex: 0)
            debtCap: 200_000 ether      // a big number, proportional to global debt cap
        }));

        // 4. (todo) | Update timelock to point to protocol 
        // timelock.setProtocol(address(protocol));

        // 5. Finish setup + transfer ownership to multisig
        protocol.finishSetUp(owner);

        vm.stopBroadcast();
    }
}
