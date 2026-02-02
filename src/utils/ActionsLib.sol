// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library Actions {
    uint256 constant public MAX_ARRAY_LEN = 50;

    //groups
    uint256 constant public ONLY_APP = 0;
    uint256 constant public APP_AND_USER = 1;
    uint256 constant public ONLY_USER = 2;

    //actions
    uint256 constant public MINT = 1 << 0;
    uint256 constant public HOLD = 1 << 1;
    uint256 constant public TRANSFER_DEST = 1 << 2;

    function getGroupActions(
        bool canMint, 
        bool canHold, 
        bool canGetTransfer
        ) internal pure returns (uint256 actions){
        if (canMint) actions |= MINT;
        if (canHold) actions |= HOLD;
        if (canGetTransfer) actions |= TRANSFER_DEST;
    }

    function allowed(uint256 userActions, uint256 appActions) internal pure {
        transferMustHold(userActions);
        bool appTransfers = transferMustHold(appActions);
        if (appTransfers)
            require(userActions & HOLD != 0, "TRANSFERS require USERS");
        require(userActions & MINT != 0 || appActions & MINT != 0, "At least one MINTER");
        require(userActions & HOLD != 0 || appActions & HOLD != 0, "At least one HOLDER");
    }

    function transferMustHold(uint256 actions) internal pure returns (bool canTransfer){
        canTransfer = actions & TRANSFER_DEST != 0;
        if (canTransfer)
            require(actions & HOLD != 0, "TRANSFER_DEST roles must also be HOLDER");
    }
}