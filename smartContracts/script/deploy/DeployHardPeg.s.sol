// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {HardPeg} from "../../../src/core/HardPeg.sol";
import {HardPegAdapter} from "../../../src/adapters/HardPegAdapter.sol";
import "../../../src/Timelock.sol";
import "../../../src/core/shared/CollateralManager.sol";
import "../../../src/utils/CollateralLib.sol";
import "../../../src/utils/RolesLib.sol";

struct DeploymentInfo {
    address hardPeg;
    address hardPegAdapter;
}

contract DeployHardPeg is Script {
    Timelock timelock;
    HardPeg hardPeg;
    HardPegAdapter hardPegAdapter;

    function run() external returns (DeploymentInfo memory info) {
        address owner = vm.envAddress("OWNER");
        uint256 deployerPK = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPK);

        vm.startBroadcast(deployerPK);

        timelock = new Timelock();
 
        hardPeg = new HardPeg(
            deployer,
            address(timelock),
            5_000_000 ether,    //global debt cap
            1_000 ether         //mint cap per tx
        );

        hardPegAdapter = new HardPegAdapter(address(hardPeg));
        
        setTimelockedCalls();
        addGlobalCollateral();
        hardPeg.finishSetUp(owner);

        vm.stopBroadcast();

        console.log("Deployment Info ");
        console.log("HardPeg core contract:   ", address(hardPeg));
        console.log("HardPeg adapter:        ", address(hardPegAdapter));
        info = DeploymentInfo(address(hardPeg), address(hardPegAdapter));
    }

    function addGlobalCollateral() internal {
        address[] memory feeds = new address[](1);
        uint256 chainId = block.chainid;
        
        if (chainId == 5042002) {
            address usdcArc = address(0x3600000000000000000000000000000000000000);
            feeds[0] = address(0); 
            hardPeg.updateGlobalCollateral(CollateralInput({
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
            hardPeg.updateGlobalCollateral(CollateralInput({
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
            hardPeg.updateGlobalCollateral(CollateralInput({
                tokenAddress: usdc,
                mode: Collateral.MODE_STABLE,
                oracleFeeds: feeds,
                LTV: 100,
                liquidityThreshold: 100,
                liquidationBonus: 5,
                debtCap: 200_000 ether
            }));

            address dai = address(0x776b6fC2eD15D6Bb5Fc32e0c89DE68683118c62A);
            feeds[0] = address(0);
            hardPeg.updateGlobalCollateral(CollateralInput({
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
            hardPeg.updateGlobalCollateral.selector,
            CallConfig({
                role: Roles.COLLATERAL_MANAGER,
                delay: 1 days,
                gracePeriod: 3 days
            })
        );

        timelock.setSelector(
            hardPeg.removeGlobalCollateral.selector,
            CallConfig({
                role: Roles.COLLATERAL_MANAGER,
                delay: 1 days,
                gracePeriod: 3 days
            })
        );

        timelock.setSelector(
            hardPeg.pauseGlobalCollateral.selector,
            CallConfig({
                role: Roles.COLLATERAL_MANAGER,
                delay: 30 minutes,
                gracePeriod: 2 hours
            })
        );

        timelock.setSelector(
            hardPeg.unpauseGlobalCollateral.selector,
            CallConfig({
                role: Roles.COLLATERAL_MANAGER,
                delay: 1 days,
                gracePeriod: 3 days
            })
        );

        timelock.setSelector(
            hardPeg.unpauseMint.selector,
            CallConfig({
                role: Roles.OWNER,
                delay: 1 days,
                gracePeriod: 2 days
            })
        );

        timelock.setSelector(
            hardPeg.unpauseWithdraw.selector,
            CallConfig({
                role: Roles.OWNER,
                delay: 1 days,
                gracePeriod: 2 days
            })
        );
        
        timelock.setSelector(
            hardPeg.updateGlobalDebtCap.selector,
            CallConfig({
                role: Roles.GOVERNOR,
                delay: 1 days,
                gracePeriod: 3 days
            })
        );
        
        timelock.setSelector(
            hardPeg.updateMintCapPerTx.selector,
            CallConfig({
                role: Roles.GOVERNOR,
                delay: 1 days,
                gracePeriod: 3 days
            })
        );
    } 
}