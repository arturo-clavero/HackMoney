export const hardPegAbi = [
  {
    type: "function",
    name: "newInstance",
    inputs: [
      {
        name: "config",
        type: "tuple",
        components: [
          { name: "name", type: "string" },
          { name: "symbol", type: "string" },
          { name: "appActions", type: "uint256" },
          { name: "userActions", type: "uint256" },
          { name: "users", type: "address[]" },
          { name: "tokens", type: "address[]" },
        ],
      },
    ],
    outputs: [{ name: "id", type: "uint256" }],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "getGlobalCollateralList",
    inputs: [],
    outputs: [{ name: "", type: "address[]" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getGlobalCollateral",
    inputs: [{ name: "token", type: "address" }],
    outputs: [
      {
        name: "",
        type: "tuple",
        components: [
          { name: "id", type: "uint256" },
          { name: "tokenAddress", type: "address" },
          { name: "decimals", type: "uint256" },
          { name: "scale", type: "uint256" },
          { name: "mode", type: "uint256" },
          { name: "oracleFeeds", type: "address[]" },
          { name: "LTV", type: "uint256" },
          { name: "liquidityThreshold", type: "uint256" },
          { name: "debtCap", type: "uint256" },
        ],
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getAppCoin",
    inputs: [{ name: "id", type: "uint256" }],
    outputs: [{ name: "", type: "address" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getAppConfig",
    inputs: [{ name: "id", type: "uint256" }],
    outputs: [
      {
        name: "",
        type: "tuple",
        components: [
          { name: "owner", type: "address" },
          { name: "coin", type: "address" },
          { name: "tokensAllowed", type: "uint256" },
        ],
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "isAppCollateralAllowed",
    inputs: [
      { name: "appID", type: "uint256" },
      { name: "token", type: "address" },
    ],
    outputs: [{ name: "", type: "bool" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getVaultBalance",
    inputs: [
      { name: "id", type: "uint256" },
      { name: "user", type: "address" },
    ],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "updateUserList",
    inputs: [
      { name: "id", type: "uint256" },
      { name: "toAdd", type: "address[]" },
      { name: "toRevoke", type: "address[]" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "addAppCollateral",
    inputs: [
      { name: "appID", type: "uint256" },
      { name: "token", type: "address" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "removeAppCollateral",
    inputs: [
      { name: "appID", type: "uint256" },
      { name: "token", type: "address" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "deposit",
    inputs: [
      { name: "id", type: "uint256" },
      { name: "token", type: "address" },
      { name: "rawAmount", type: "uint256" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "mint",
    inputs: [
      { name: "id", type: "uint256" },
      { name: "to", type: "address" },
      { name: "rawAmount", type: "uint256" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "redeam",
    inputs: [
      { name: "token", type: "address" },
      { name: "rawAmount", type: "uint256" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "withdrawCollateral",
    inputs: [
      { name: "id", type: "uint256" },
      { name: "valueAmount", type: "uint256" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "event",
    name: "RegisteredApp",
    inputs: [
      { name: "owner", type: "address", indexed: true },
      { name: "id", type: "uint256", indexed: true },
      { name: "coin", type: "address", indexed: false },
    ],
  },
  {
    type: "event",
    name: "UserListUpdated",
    inputs: [
      { name: "id", type: "uint256", indexed: true },
      { name: "added", type: "address[]", indexed: false },
      { name: "removed", type: "address[]", indexed: false },
    ],
  },
] as const;
