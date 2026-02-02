// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../../src/Core/shared/CollateralManager.sol";
import "../../../src/utils/ActionsLib.sol";
import "../../../src/PrivateCoin.sol";
import "../../../src/interfaces/IPrivateCoin.sol";

library Core {

//PC users ACTIONS
    uint256 constant defaultUserAction = Actions.HOLD | Actions.TRANSFER_DEST;
    uint256 constant defaultAppAction = Actions.MINT;


    //APP - COLLATERAL

    uint256 constant COL_MODE_STABLE   = 1 << 0;
    uint256 constant COL_MODE_VOLATILE = 1 << 1;
    uint256 constant COL_MODE_YIELD    = 1 << 2;
    uint256 constant COL_MODE_ACTIVE   = 1 << 3;

    uint256 constant PEG_HARD = 0;
    uint256 constant PEG_MED  = 1;
    uint256 constant PEG_SOFT = 2;



    function _collateralInput(address token, uint256 mode)
        internal
        pure
        returns (CollateralInput memory)
    {
        return CollateralInput({
            tokenAddress: token,
            mode: mode,
            oracleFeeds: new address[](3),
            LTV: 50,
            liquidityThreshold: 80,
            debtCap: 1000
        });
    }

    function _collateralInput(address token)
        internal
        pure
        returns (CollateralInput memory)
    {
        return CollateralInput({
            tokenAddress: token,
            mode: COL_MODE_STABLE,
            oracleFeeds: new address[](3),
            LTV: 50,
            liquidityThreshold: 80,
            debtCap: 1000
        });
    }

    function signPermit(
        address coin,
        address owner,
        uint256 ownerPk,
        address allowed,
        uint256 value,
        uint256 deadline
    ) internal view returns (bytes32 digest) {
        digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                IPrivateCoin(coin).DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256(
                            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                        ),
                        owner,
                        allowed,
                        value,
                        IPrivateCoin(coin).nonces(owner),
                        deadline
                    )
                )
            )
        );
    }

    function getDigest(
        PrivateCoin c,
        address owner,
        uint256 ownerPk,
        address allowed,
        uint256 value
    ) internal view returns (bytes32 digest) {
        digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                c.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256(
                            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                        ),
                        owner,
                        allowed,
                        value,
                        c.nonces(owner),
                        uint256(type(uint224).max)
                    )
                )
            )
        );
    }


}