// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/governance/TaikoDAOController.sol";
import "src/shared/common/EssentialContract.sol";
import "script/BaseScript.sol";

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/EssentialContract.sol";

/// @title TaikoDAOController
/// @notice This contract maintains ownership of all contracts and assets, and is itself owned by
/// the TaikoDAO. This architecture allows the TaikoDAO to seamlessly transition from one DAO to
/// another by simply changing the owner of this contract. In essence, the TaikoDAO does not
/// directly own contracts or any assets.
/// @custom:security-contact security@taiko.xyz
contract FooUpgradeableV1 is EssentialContract {
    constructor() EssentialContract(address(0)) { }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    function hellTaiko() external pure virtual returns (string memory) {
        return "hello taiko v1";
    }
}

contract FooUpgradeableV2 is FooUpgradeableV1 {
    function hellTaiko() external pure override returns (string memory) {
        return "hello taiko v2";
    }
}

contract DanielWangDAOStandardProposalTest1 is BaseScript {
    address private constant TAIKO_DAO_CONTROLLER = 0xfC3C4ca95a8C4e5a587373f1718CD91301d6b2D3;

    address private constant FOO_UPGRADEABLE_PROXY = 0xD1Ed20C8fEc53db3274c2De09528f45dF6c06A65;
    address private constant FOO_UPGRADEABLE_V1 = 0xdC2FaA24e73207C32314E6E1595Da454F53c7f34;
    address private constant FOO_UPGRADEABLE_V2 = 0x4EBeC8a624ac6f01Bb6C7F13947E6Af3727319CA;

    function run() external broadcast { }
}
