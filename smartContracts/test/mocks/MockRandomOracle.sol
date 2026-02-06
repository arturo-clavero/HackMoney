// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract MockOracle {
    struct Asset {
        uint256 price;       
        uint256 volatilityBps;
    }

    uint256 public seed;
    bool public frozen;
    mapping(address=>Asset) public assets;

    event PriceUpdated(address indexed asset, uint256 newPrice);

    constructor(
        // uint256 initialPrice,
        // uint256 _volatilityBps,
        uint256 _seed
    ) {
        // price = initialPrice;
        // volatilityBps = _volatilityBps;
        seed = _seed;
    }

    function setAsset(
        address asset,
        uint256 price,
        uint256 volBps
    ) external {
        assets[asset] = Asset(price, volBps);
    }

    function update(address asset) external {
        require(!frozen, "oracle frozen");

        Asset storage a = assets[asset];
        require(a.price > 0, "unknown asset");

        uint256 rand = _rand(asset);

        // Map randomness to [-volatility, +volatility]
        int256 deltaBps = int256(rand % (2 * a.volatilityBps)) 
            - int256(a.volatilityBps);

        int256 delta = (int256(a.price) * deltaBps) / 10_000;

        int256 newPrice = int256(a.price) + delta;
        require(newPrice > 0, "price <= 0");

        a.price = uint256(newPrice);
        emit PriceUpdated(asset, a.price);
    }

    function priceView(address asset) external view returns (uint256) {
        return  assets[asset].price;
    }

    function setPrice(address asset, uint256 newPrice) external {
         assets[asset].price = newPrice;
        emit PriceUpdated(asset, newPrice);
    }

    function setVolatility(address asset, uint256 bps) external {
         assets[asset].volatilityBps = bps;
    }

    function freeze(bool _frozen) external {
        frozen = _frozen;
    }

    function setSeed(uint256 newSeed) external {
        seed = newSeed;
    }

    function _rand(address asset) internal returns (uint256 r) {
        seed = uint256(
            keccak256(
                abi.encodePacked(
                    seed,
                    asset,
                    block.timestamp,
                    block.number
                )
            )
        );
        return seed;
    }
}
