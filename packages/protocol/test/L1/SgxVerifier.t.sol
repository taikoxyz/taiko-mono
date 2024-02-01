// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TaikoL1TestBase.sol";
import "../automata-attestation/common/AttestationBase.t.sol";

contract TestSgxVerifier is TaikoL1TestBase, AttestationBase {
    address internal SGX_Y =
        vm.addr(0x9b1bb8cb3bdb539d0d1f03951d27f167f2d5443e7ef0d7ce745cd4ec619d3dd7);
    address internal SGX_Z = randAddress();

    function deployTaikoL1() internal override returns (TaikoL1) {
        return
            TaikoL1(payable(deployProxy({ name: "taiko", impl: address(new TaikoL1()), data: "" })));
    }

    function setUp() public override {
        // Call the TaikoL1TestBase setUp()
        super.setUp();

        // Call the AttestationBase init setup
        super.intialSetup();

        registerAddress("automata_dcap_attestation", address(attestation));
    }

    function test_addInstancesByOwner() external {
        address[] memory _instances = new address[](3);
        _instances[0] = SGX_X_1;
        _instances[1] = SGX_Y;
        _instances[2] = SGX_Z;
        sv.addInstances(_instances);
    }

    function test_addInstancesByOwner_WithoutOwnerRole() external {
        address[] memory _instances = new address[](3);
        _instances[0] = SGX_X_0;
        _instances[1] = SGX_Y;
        _instances[2] = SGX_Z;

        vm.expectRevert();
        vm.prank(Bob, Bob);
        sv.addInstances(_instances);
    }

    function test_deleteInstancesByOwner() external {
        uint256[] memory _ids = new uint[](1);
        _ids[0] = 0;
        
        address instance;
        (instance,) = sv.instances(0);
        assertEq(instance, SGX_X_0);

        sv.deleteInstances(_ids);

        (instance,) = sv.instances(0);
        assertEq(instance, address(0));
    }

    function test_registerInstanceWithAttestation() external {
        string memory v3QuoteJsonStr = vm.readFile(string.concat(vm.projectRoot(), v3QuotePath));
        bytes memory v3QuotePacked = vm.parseJson(v3QuoteJsonStr);

        (, V3Struct.ParsedV3QuoteStruct memory v3quote) = parseV3QuoteJson(v3QuotePacked);

        vm.prank(Bob, Bob);
        sv.registerInstance(v3quote);
    }

    function _getSignature(
        address _newInstance,
        address[] memory _instances,
        uint256 privKey
    )
        private
        view
        returns (bytes memory signature)
    {
        bytes32 digest = keccak256(
            abi.encode(
                "ADD_INSTANCES",
                ITaikoL1(L1).getConfig().chainId,
                address(sv),
                _newInstance,
                _instances
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, digest);
        signature = abi.encodePacked(r, s, v);
    }
}
