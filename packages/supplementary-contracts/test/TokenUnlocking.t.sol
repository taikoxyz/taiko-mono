// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/src/Test.sol";

import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MyERC20 is ERC20 {
    constructor(address owner) ERC20("Taiko Token", "TKO") {
        _mint(owner, 1_000_000_000e18);
    }
}

contract USDC is ERC20 {
    constructor(address recipient) ERC20("USDC", "USDC") {
        _mint(recipient, 1_000_000_000e6);
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
}

contract TestTokenUnlocking is Test {
    address internal Vault = randAddress();

    ERC20 tko = new MyERC20(Vault);
    ERC20 usdc = new USDC(Alice);

    uint128 public constant ONE_TKO_UNIT = 1e18;

    // 0.01 USDC if decimals are 6 (as in our test)
    uint64 strikePrice1 = uint64(10 ** usdc.decimals() / 100);

    TimelockTokenPool pool;

    function setUp() public {
        pool = TimelockTokenPool(
            deployProxy({
                name: "time_lock_token_pool",
                impl: address(new TimelockTokenPool()),
                data: abi.encodeCall(
                    TimelockTokenPool.init, (address(0), address(tko), address(usdc), Vault)
                    )
            })
        );
    }

    function test_invalid_granting() public {
        vm.expectRevert(TimelockTokenPool.INVALID_GRANT.selector);
        pool.grant(Alice, TimelockTokenPool.Grant(0, 0, 0, 0, 0, 0, 0, 0));

        vm.expectRevert(TimelockTokenPool.INVALID_PARAM.selector);
        pool.grant(address(0), TimelockTokenPool.Grant(100e18, 0, 0, 0, 0, 0, 0, 0));
    }
}
