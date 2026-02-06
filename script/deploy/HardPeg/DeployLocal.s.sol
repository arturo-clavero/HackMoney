// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../../src/Core/HardPeg.sol";
import "../../../src/Y_Timelock.sol";
import "../../../src/Core/shared/CollateralManager.sol";
import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";

/// @notice ERC20 with public mint and custom decimals, for local testing only.
contract NamedMockToken is ERC20 {
    uint8 private immutable _dec;

    constructor(string memory name_, string memory symbol_, uint8 decimals_)
        ERC20(name_, symbol_)
    {
        _dec = decimals_;
    }

    function decimals() public view override returns (uint8) { return _dec; }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @notice Local Anvil deployment script.
 *
 * Usage:
 *   anvil                        # terminal 1
 *   source .env                  # terminal 2
 *   forge script script/deploy/HardPeg/DeployLocal.s.sol:DeployLocal \
 *     --rpc-url http://127.0.0.1:8545 --broadcast
 */
contract DeployLocal is Script {
    function run() external {
        uint256 deployerPK = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPK);
        address multisigOwner = vm.envAddress("MULTISIG");

        vm.startBroadcast(deployerPK);

        // 1. Deploy mock stablecoins with proper names
        NamedMockToken usdc = new NamedMockToken("USD Coin", "USDC", 6);
        NamedMockToken dai  = new NamedMockToken("Dai Stablecoin", "DAI", 18);

        // Mint tokens to deployer for testing
        usdc.mint(deployer, 1_000_000 * 1e6);   // 1M USDC
        dai.mint(deployer,  1_000_000 * 1e18);   // 1M DAI

        // 2. Deploy timelock (placeholder)
        Timelock timelock = new Timelock();

        // 3. Deploy HardPeg with deployer as temporary owner
        uint256 globalDebtCap = 5_000_000 ether;
        uint256 mintCapPerTx  = 1_000 ether;
        HardPeg protocol = new HardPeg(
            deployer,
            address(timelock),
            globalDebtCap,
            mintCapPerTx
        );

        // 4. Register collateral (owner can do this before finishSetUp)
        address[] memory emptyFeeds = new address[](0);

        protocol.updateGlobalCollateral(CollateralInput({
            tokenAddress: address(usdc),
            mode: 1,                        // MODE_STABLE
            oracleFeeds: emptyFeeds,
            LTV: 0,
            liquidityThreshold: 0,
            debtCap: 2_000_000 ether
        }));

        protocol.updateGlobalCollateral(CollateralInput({
            tokenAddress: address(dai),
            mode: 1,                        // MODE_STABLE
            oracleFeeds: emptyFeeds,
            LTV: 0,
            liquidityThreshold: 0,
            debtCap: 2_000_000 ether
        }));

        // 5. Finish setup + transfer ownership
        protocol.finishSetUp(multisigOwner);

        vm.stopBroadcast();

        // Log deployed addresses for frontend config
        console.log("=== DEPLOYED ADDRESSES ===");
        console.log("USDC (mock):", address(usdc));
        console.log("DAI  (mock):", address(dai));
        console.log("Timelock:   ", address(timelock));
        console.log("HardPeg:    ", address(protocol));
        console.log("Deployer:   ", deployer);
        console.log("Owner:      ", multisigOwner);
        console.log("==========================");
    }
}
