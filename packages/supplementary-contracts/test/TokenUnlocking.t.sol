// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/src/Test.sol";
import "forge-std/src/console2.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../contracts/TokenUnlocking.sol";

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
    address internal Owner = vm.addr(0x1);
    address internal Alice = vm.addr(0x2);
    address internal Bob = vm.addr(0x3);
    address internal Vault = vm.addr(0x4);

    ERC20 tko = new MyERC20(Vault);
    ERC20 usdc = new USDC(Alice);

    uint128 public constant ONE_TKO_UNIT = 1e18;

    TokenUnlocking tokenUnlocking;

    function setUp() public {
        tokenUnlocking = TokenUnlocking(
            deployProxy({
                impl: address(new TokenUnlocking()),
                data: abi.encodeCall(TokenUnlocking.init, (Owner, address(tko), Vault, Alice))
            })
        );
    }

    function test_example() public pure {
        console2.log("write_more_test");
    }

    function deployProxy(address impl, bytes memory data) public returns (address proxy) {
        proxy = address(new ERC1967Proxy(impl, data));

        console2.log("  proxy      :", proxy);
        console2.log("  impl       :", impl);
    }
}
