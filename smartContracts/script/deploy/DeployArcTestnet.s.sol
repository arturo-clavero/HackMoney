// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../../src/core/HardPeg.sol";
import "../../../src/Y_Timelock.sol";
import "../../../src/core/shared/CollateralManager.sol";

/**
 * @notice Arc testnet deployment script.
 *
 * Uses the native USDC on Arc testnet (no mock tokens).
 *
 * Usage:
 *   source .env
 *   forge script script/deploy/HardPeg/DeployArcTestnet.s.sol:DeployArcTestnet \
 *     --rpc-url https://rpc.testnet.arc.network --broadcast
 */
contract DeployArcTestnet is Script {
    address constant ARC_USDC = 0x3600000000000000000000000000000000000000;

    function run() external {
        uint256 deployerPK = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPK);
        address multisigOwner = vm.envAddress("MULTISIG");

        vm.startBroadcast(deployerPK);

        // 1. Deploy timelock
        Timelock timelock = new Timelock();

        // 2. Deploy HardPeg with deployer as temporary owner
        uint256 globalDebtCap = 5_000_000 ether;
        uint256 mintCapPerTx  = 1_000 ether;
        HardPeg protocol = new HardPeg(
            deployer,
            address(timelock),
            globalDebtCap,
            mintCapPerTx
        );

        // 3. Register Arc native USDC as MODE_STABLE collateral
        address[] memory emptyFeeds = new address[](0);

        protocol.updateGlobalCollateral(CollateralInput({
            tokenAddress: ARC_USDC,
            mode: 1,                        // MODE_STABLE
            oracleFeeds: emptyFeeds,
            LTV: 0,
            liquidityThreshold: 0,
            debtCap: 2_000_000 ether
        }));

        // 4. Finish setup + transfer ownership
        protocol.finishSetUp(multisigOwner);

        vm.stopBroadcast();

        // Log deployed addresses for frontend config
        console.log("=== DEPLOYED ADDRESSES (Arc Testnet) ===");
        console.log("USDC (native):", ARC_USDC);
        console.log("Timelock:     ", address(timelock));
        console.log("HardPeg:      ", address(protocol));
        console.log("Deployer:     ", deployer);
        console.log("Owner:        ", multisigOwner);
        console.log("=========================================");
    }
}
