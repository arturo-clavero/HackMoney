// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;


library Roles {
    /**
     * @dev COLLATERAL_MANAGER
     * Manages protocol-wide collateral configuration.
     *
     * Capabilities:
     * - Add or update supported collateral assets
     * - Modify global collateral parameters
     *
     * Note:
     * Applications may only use collateral that has been approved
     * and configured at the protocol level.
     */
    uint256 constant public COLLATERAL_MANAGER = 1 << 1;

    /**
     * @dev GOVERNOR
     * Emergency control role.
     *
     * Capabilities:
     * - Pause critical protocol actions
     *
     * Intended for risk mitigation and incident response.
     */
    uint256 constant public GOVERNOR = 1 << 3;
     /**
     * @dev LIQUIDATOR
     * Can liquidate positions.
     *
     * Capabilities:
     * - Mint and hold any app-sepcific stablecoin
     * - Liquidate single positions
     * - Batch liquidate positions in an app
     * - Participate in liquidation pool
     *
     * Intended for risk mitigation and incident response.
     */
    uint256 constant public LIQUIDATOR = 1 << 4;
}