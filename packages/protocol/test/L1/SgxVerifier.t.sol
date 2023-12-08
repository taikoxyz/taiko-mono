// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./TaikoL1TestBase.sol";

contract TestSgxVerifier is TaikoL1TestBase {
    function deployTaikoL1() internal override returns (TaikoL1) {
        return
            TaikoL1(payable(deployProxy({ name: "taiko", impl: address(new TaikoL1()), data: "" })));
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

    function test_addInstancesBySgxInstance() external {
        address[] memory _instances = new address[](2);
        _instances[0] = SGX_Y;
        _instances[1] = SGX_Z;

        bytes memory signature = _getSignature(_instances, 0x4);

        vm.prank(Bob, Bob);
        sv.addInstances(0, SGX_X_1, _instances, signature);
    }

    function test_SgxSignatureOnly() external {
        // This special testcase for Patryk is only to figure out the outputted signature(proof) by
        // the sgx instance is the one expected.
        // What is the scope of this test ?
        // Basically checking these 2 lines in SgxVerifier.sol:
        // line 113:  bytes memory signature = LibBytesUtils.slice(proof.data, 24);

        // line 115: address oldInstance =
        //     ECDSA.recover(getSignedHash(tran, newInstance, ctx.prover, ctx.metaHash), signature);

        //1. I'm creating now dummy variables, which will be hashed then signed. You can feed these
        // variables to the SGX instance, use it's private key to sign the same dummy data.
        // You can use these exact dummy variables in sgx OR you can give it just the hash to sign
        // (give it the hash from this test file's line 65)
        TaikoData.Transition memory tran = TaikoData.Transition({
            parentHash: bytes32(uint256(0x0)),
            blockHash: bytes32(uint256(0x1)),
            signalRoot: bytes32(uint256(0x2)),
            graffiti: bytes32(uint256(0x3))
        });
        address newInstance = address(0);
        address prover = address(0);
        bytes32 metaHash = bytes32(uint256(0x1));

        //2. Now calling the Verifier contract's getSignedHash function, to get the hash which needs
        // to be signed. Basically what you need to do is, to have this same data (the dummy one, as
        // mine above) and query the corresponding hash. Either via this function, or 'off-chain' in
        // javascript/typescript, like: ethers.utils.keccak256()
        // You can directly use this return value, in your SGX and simply sign it.
        bytes32 hashToBeSignedBySgx = sv.getSignedHash(tran, newInstance, prover, metaHash);
        console2.log("This is the hash to be signed by SGX:");
        console2.logBytes32(hashToBeSignedBySgx);

        //3. This is a random private key - from a newly generated ECDSA privatey public key pair,
        // but offline you shall use your SGX instance's one !! Important, because basically that is
        // the signer, which gives you the proof.
        uint256 signerPrivateKey =
            0x0f51fcdf6b1d40dbd08fc841bdf9052762c7e5d88f519d7b1a5a3b3047774c9b;
        // This privatey key above is representing this ethereum address below
        address ethereumAddress = 0xAD65E8b427Afce4A4DEe6593f14039962f23CE71;

        // Sign it
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, hashToBeSignedBySgx);
        bytes memory signature = abi.encodePacked(r, s, v);

        //4. This is the signature (proof) with that dummy data and the ECDSA signing gives:
        // This is what you need to compare with your own siganture. But if you: 1. use the same
        // data, 2. use the same private key, you need to get the same output.
        console2.log("Created signature:");
        console2.logBytes(signature);

        // And now verifying if we get back the same ethereum address
        address shouldBeMatchingEthereumAddress =
            ECDSA.recover(sv.getSignedHash(tran, newInstance, prover, metaHash), signature);

        // These addresses should be matching so you know you did it right.
        assertEq(shouldBeMatchingEthereumAddress, ethereumAddress);
    }

    function _getSignature(
        address[] memory _instances,
        uint256 privKey
    )
        private
        pure
        returns (bytes memory signature)
    {
        bytes32 digest = keccak256(abi.encode("ADD_INSTANCES", _instances));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, digest);
        signature = abi.encodePacked(r, s, v);
    }
}
