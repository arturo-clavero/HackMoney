// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract MockOracle {
    uint256 public price;       
    uint256 public volatilityBps;
    uint256 public seed;

    bool public frozen;

    event PriceUpdated(uint256 newPrice);

    constructor(
        uint256 initialPrice,
        uint256 _volatilityBps,
        uint256 _seed
    ) {
        price = initialPrice;
        volatilityBps = _volatilityBps;
        seed = _seed;
    }

    function update() external {
        require(!frozen, "oracle frozen");

        uint256 rand = _rand();

        // Map randomness to [-volatility, +volatility]
        int256 deltaBps = int256(rand % (2 * volatilityBps)) 
            - int256(volatilityBps);

        int256 delta = (int256(price) * deltaBps) / 10_000;

        int256 newPrice = int256(price) + delta;
        require(newPrice > 0, "price <= 0");

        price = uint256(newPrice);
        emit PriceUpdated(price);
    }

    function priceView() external view returns (uint256) {
        return price;
    }

    function setPrice(uint256 newPrice) external {
        price = newPrice;
        emit PriceUpdated(newPrice);
    }

    function setVolatility(uint256 bps) external {
        volatilityBps = bps;
    }

    function freeze(bool _frozen) external {
        frozen = _frozen;
    }

    function setSeed(uint256 newSeed) external {
        seed = newSeed;
    }

    function _rand() internal returns (uint256 r) {
        // deterministic but evolving randomness
        seed = uint256(
            keccak256(
                abi.encodePacked(
                    seed,
                    block.timestamp,
                    block.number
                )
            )
        );
        return seed;
    }
}
