// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {SoftPeg} from "../../src/core/SoftPeg.sol";
import {SoftPegAdapter} from "../../src/adapters/SoftPegAdapter.sol";
import "../../src/Timelock.sol";
import "../../src/core/shared/CollateralManager.sol";
import "../../src/utils/CollateralLib.sol";
import "../../src/utils/RolesLib.sol";


struct DeploymentInfo {
    address softPeg;
    address softPegAdapter;
}

contract DeploySoftPeg is Script {
    Timelock timelock;
    SoftPeg softPeg;
    SoftPegAdapter softPegAdapter;

    function run() external returns (DeploymentInfo memory info) {
        address owner = vm.envAddress("OWNER");
        uint256 deployerPK = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPK);

        vm.startBroadcast(deployerPK);

        timelock = new Timelock();
 
        softPeg = new SoftPeg(
            deployer,
            address(timelock),
            5_000_000 ether,    //global debt cap
            1_000 ether        //mint cap per tx
        );

        softPegAdapter = new SoftPegAdapter(address(softPeg));
        
        setTimelockedCalls();
        addGlobalCollateral();
        softPeg.finishSetUp(owner);

        vm.stopBroadcast();

        console.log("Deployment Info ");
        console.log("SoftPeg core contract:   ", address(softPeg));
        console.log("SoftPeg adapter:        ", address(softPegAdapter));
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
            feeds[0] = address(0x57020Ba11D61b188a1Fd390b108D233D87c06057);
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
            feeds[0] = address(0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E); 
            softPeg.updateGlobalCollateral(CollateralInput({
                tokenAddress: usdc,
                mode: Collateral.MODE_STABLE,
                oracleFeeds: feeds,
                LTV: 100,
                liquidityThreshold: 100,
                liquidationBonus: 5,
                debtCap: 200_000 ether
            }));

            address dai = address(0x776b6fC2eD15D6Bb5Fc32e0c89DE68683118c62A);
            feeds[0] = address(0x14866185B1962B63C3Ea9E03Bc1da838bab34C19);
            softPeg.updateGlobalCollateral(CollateralInput({
                tokenAddress: dai,
                mode: Collateral.MODE_STABLE,
                oracleFeeds: feeds,
                LTV: 100,
                liquidityThreshold: 100,
                liquidationBonus: 5,
                debtCap: 200_000 ether
            }));


            address weth = address(0xf531B8F309Be94191af87605CfBf600D71C2cFe0);
            feeds[0] = address(0x694AA1769357215DE4FAC081bf1f309aDC325306);
            softPeg.updateGlobalCollateral(CollateralInput({
                tokenAddress: weth,
                mode: Collateral.MODE_VOLATILE,
                oracleFeeds: feeds,
                LTV: 100,
                liquidityThreshold: 100,
                liquidationBonus: 5,
                debtCap: 200_000 ether
            }));

            address btc = address(0x66194F6C999b28965E0303a84cb8b797273B6b8b);
            feeds[0] = address(0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43);
            softPeg.updateGlobalCollateral(CollateralInput({
                tokenAddress: btc,
                mode: Collateral.MODE_VOLATILE,
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