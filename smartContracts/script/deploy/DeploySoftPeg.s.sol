// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {MediumPeg} from "../../../src/core/MediumPeg.sol";
import {MediumPegAdapter} from "../../../src/adapters/MediumPegAdapter.sol";
import "../../../src/Timelock.sol";
import "../../../src/core/shared/CollateralManager.sol";
import "../../../src/utils/CollateralLib.sol";
import "../../../src/utils/RolesLib.sol";


struct DeploymentInfo {
    address softPeg;
    address softPegAdapter;
}

contract DeployMediumPeg is Script {
    Timelock timelock;
    MediumPeg softPeg;
    MediumPegAdapter softPegAdapter;

    function run() external returns (DeploymentInfo memory info) {
        address owner = vm.envAddress("OWNER");
        uint256 deployerPK = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPK);

        vm.startBroadcast(deployerPK);

        timelock = new Timelock();
 
        softPeg = new MediumPeg(
            deployer,
            address(timelock),
            5_000_000 ether,    //global debt cap
            1_000 ether        //mint cap per tx
        );

        softPegAdapter = new MediumPegAdapter(address(softPeg));
        
        setTimelockedCalls();
        addGlobalCollateral();
        softPeg.finishSetUp(owner);

        vm.stopBroadcast();

        console.log("Deployment Info ");
        console.log("MediumPeg core contract:   ", address(softPeg));
        console.log("MediumPeg adapter:        ", address(softPegAdapter));
        info = DeploymentInfo(address(softPeg), address(softPegAdapter));
    }

    function addGlobalCollateral() internal {

        address[] memory feeds = new address[](1);
        uint256 chainId = block.chainid;
        
        if (chainId == 5042002) {
            address usdcArc = address(0x3600000000000000000000000000000000000000);
            feeds[0] = address(0); 
            softPeg.updateGlobalCollateral(CollateralInput({
                tokenAddress: usdcArc,
                mode: Collateral.MODE_STABLE,
                oracleFeeds: feeds,
                LTV: 100,
                liquidityThreshold: 100,
                liquidationBonus: 5,
                debtCap: 200_000 ether
            }));
        }

        if (chainId == 11155111) {
            address pyusd = address(0xCaC524BcA292aaade2DF8A05cC58F0a65B1B3bB9);
            feeds[0] = address(0);
            softPeg.updateGlobalCollateral(CollateralInput({
                tokenAddress: pyusd,
                mode: Collateral.MODE_STABLE,
                oracleFeeds: feeds,
                LTV: 100,
                liquidityThreshold: 100,
                liquidationBonus: 5,
                debtCap: 200_000 ether
            }));

            address usdc = address(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238);
            feeds[0] = address(0); 
            softPeg.updateGlobalCollateral(CollateralInput({
                tokenAddress: usdc,
                mode: Collateral.MODE_STABLE,
                oracleFeeds: feeds,
                LTV: 100,
                liquidityThreshold: 100,
                liquidationBonus: 5,
                debtCap: 200_000 ether
            }));

            address dai = address(0);
            feeds[0] = address(0);
            softPeg.updateGlobalCollateral(CollateralInput({
                tokenAddress: dai,
                mode: Collateral.MODE_STABLE,
                oracleFeeds: feeds,
                LTV: 100,
                liquidityThreshold: 100,
                liquidationBonus: 5,
                debtCap: 200_000 ether
            }));
        }
        
    }


    function setTimelockedCalls() internal {
        
        timelock.setSelector(
            softPeg.updateGlobalCollateral.selector,
            CallConfig({
                role: Roles.COLLATERAL_MANAGER,
                delay: 1 days,
                gracePeriod: 3 days
            })
        );

        timelock.setSelector(
            softPeg.removeGlobalCollateral.selector,
            CallConfig({
                role: Roles.COLLATERAL_MANAGER,
                delay: 1 days,
                gracePeriod: 3 days
            })
        );

        timelock.setSelector(
            softPeg.pauseGlobalCollateral.selector,
            CallConfig({
                role: Roles.COLLATERAL_MANAGER,
                delay: 30 minutes,
                gracePeriod: 2 hours
            })
        );

        timelock.setSelector(
            softPeg.unpauseGlobalCollateral.selector,
            CallConfig({
                role: Roles.COLLATERAL_MANAGER,
                delay: 1 days,
                gracePeriod: 3 days
            })
        );

        timelock.setSelector(
            softPeg.unpauseMint.selector,
            CallConfig({
                role: Roles.OWNER,
                delay: 1 days,
                gracePeriod: 2 days
            })
        );

        timelock.setSelector(
            softPeg.unpauseWithdraw.selector,
            CallConfig({
                role: Roles.OWNER,
                delay: 1 days,
                gracePeriod: 2 days
            })
        );
        
        timelock.setSelector(
            softPeg.updateGlobalDebtCap.selector,
            CallConfig({
                role: Roles.GOVERNOR,
                delay: 1 days,
                gracePeriod: 3 days
            })
        );
        
        timelock.setSelector(
            softPeg.updateMintCapPerTx.selector,
            CallConfig({
                role: Roles.GOVERNOR,
                delay: 1 days,
                gracePeriod: 3 days
            })
        );
    } 
}