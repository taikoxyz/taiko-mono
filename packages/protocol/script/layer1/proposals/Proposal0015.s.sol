// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildProposal.sol";

// To print the proposal action data: `P=0015 pnpm proposal`
// To dryrun the proposal actions on L1: `P=0015 pnpm proposal:dryrun:l1`
//
// This proposal prunes stale SGX instances, rotates the trusted SGX MRSIGNER, and revokes
// previously trusted SGX MRENCLAVE values from the existing mainnet SGX attesters.
contract Proposal0015 is BuildProposal {
    // Mainnet SGX verifiers.
    address public constant SGXGETH_VERIFIER = 0x08568Df252ecf37D6C3eFD24f6ca3688118697F1;
    address public constant SGXRETH_VERIFIER = 0xa1018Ba2e22139076f91dA2A856B2CAB22d968F6;

    // Mainnet SGX attesters.
    address public constant SGXGETH_ATTESTER = 0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261;
    address public constant SGXRETH_ATTESTER = 0x8d7C954960a36a7596d7eA4945dDf891967ca8A3;

    bytes32 public constant NEW_MR_SIGNER =
        bytes32(0xe08aef23d4357d47e5ac5f278ba5492a5f5fb145c4fc026995367210f21a333c);

    bytes32 public constant OLD_MR_SIGNER =
        bytes32(0xca0583a715534a8c981b914589a7f0dc5d60959d9ae79fb5353299a4231673d5);

    // Current nextInstanceId values observed before proposal preparation.
    uint256 public constant SGXGETH_NEXT_INSTANCE_ID = 6;
    uint256 public constant SGXRETH_NEXT_INSTANCE_ID = 7;

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        require(NEW_MR_SIGNER != bytes32(0), "replace NEW_MR_SIGNER");

        bytes32[] memory sgxGethRetiredMrEnclaves = _sgxGethRetiredMrEnclaves();
        bytes32[] memory sgxRethRetiredMrEnclaves = _sgxRethRetiredMrEnclaves();

        uint256 actionCount = 6 + sgxGethRetiredMrEnclaves.length + sgxRethRetiredMrEnclaves.length;
        actions = new Controller.Action[](actionCount);

        uint256 cursor;

        // Enable the new signer before revoking the old signer.
        actions[cursor++] = Controller.Action({
            target: SGXGETH_ATTESTER,
            value: 0,
            data: abi.encodeWithSignature("setMrSigner(bytes32,bool)", NEW_MR_SIGNER, true)
        });
        actions[cursor++] = Controller.Action({
            target: SGXRETH_ATTESTER,
            value: 0,
            data: abi.encodeWithSignature("setMrSigner(bytes32,bool)", NEW_MR_SIGNER, true)
        });
        actions[cursor++] = Controller.Action({
            target: SGXGETH_ATTESTER,
            value: 0,
            data: abi.encodeWithSignature("setMrSigner(bytes32,bool)", OLD_MR_SIGNER, false)
        });
        actions[cursor++] = Controller.Action({
            target: SGXRETH_ATTESTER,
            value: 0,
            data: abi.encodeWithSignature("setMrSigner(bytes32,bool)", OLD_MR_SIGNER, false)
        });

        for (uint256 i; i < sgxGethRetiredMrEnclaves.length; ++i) {
            actions[cursor++] = Controller.Action({
                target: SGXGETH_ATTESTER,
                value: 0,
                data: abi.encodeWithSignature(
                    "setMrEnclave(bytes32,bool)", sgxGethRetiredMrEnclaves[i], false
                )
            });
        }

        for (uint256 i; i < sgxRethRetiredMrEnclaves.length; ++i) {
            actions[cursor++] = Controller.Action({
                target: SGXRETH_ATTESTER,
                value: 0,
                data: abi.encodeWithSignature(
                    "setMrEnclave(bytes32,bool)", sgxRethRetiredMrEnclaves[i], false
                )
            });
        }

        // Delete every currently registered instance not explicitly allowed below.
        actions[cursor++] = Controller.Action({
            target: SGXGETH_VERIFIER,
            value: 0,
            data: abi.encodeWithSignature(
                "deleteInstances(uint256[])",
                _deleteIds(SGXGETH_NEXT_INSTANCE_ID, _sgxGethAllowedIds())
            )
        });
        actions[cursor++] = Controller.Action({
            target: SGXRETH_VERIFIER,
            value: 0,
            data: abi.encodeWithSignature(
                "deleteInstances(uint256[])",
                _deleteIds(SGXRETH_NEXT_INSTANCE_ID, _sgxRethAllowedIds())
            )
        });
    }

    function _sgxGethAllowedIds() private pure returns (uint256[] memory ids) {
        ids = new uint256[](1);
        ids[0] = 4;
    }

    function _sgxRethAllowedIds() private pure returns (uint256[] memory ids) {
        ids = new uint256[](1);
        ids[0] = 5;
    }

    function _sgxGethRetiredMrEnclaves() private pure returns (bytes32[] memory mrs) {
        mrs = new bytes32[](4);
        mrs[0] = bytes32(0x3e6113a23bbdf9231520153253047d02db8f1dd38a9b52914ab7943278f52db0);
        mrs[1] = bytes32(0x692c8624d30a327340b0dfbb67203e941175ac700d1a058c717e5269103d37e6);
        mrs[2] = bytes32(0xd1f43acede51c4eb2f66b86cce52682edad80b810b9d87fba3a9b67254c91b77);
        mrs[3] = bytes32(0xfda8bb1fc9938700c25353c0a5fabc96a238e69ce8e35f08e558831a20db33a6);
    }

    function _sgxRethRetiredMrEnclaves() private pure returns (bytes32[] memory mrs) {
        mrs = new bytes32[](25);
        mrs[0] = bytes32(0x13ea9869632ac20b176ae0fdc39998b2a644a695db024ef7fe0e4b3c59084160);
        mrs[1] = bytes32(0x3551faac39edee5abfaa19ab065c217db1485aebae255a9edddf6dfff6b29b52);
        mrs[2] = bytes32(0x3b589538b775ddbfc5fb028167ff846116159e6687aef9f849ca5a70a7871ea5);
        mrs[3] = bytes32(0x3f71cf178a032816c2731a43aef746c464a5326e891dc881773ec2b599b2cf0a);
        mrs[4] = bytes32(0x482b06132c4306ea55bc34ff90d46532ff4151f473dbfe4d2cb2442af2ff288b);
        mrs[5] = bytes32(0x59bf7d48610cc8a56ba8a390b68c31a1443297869b174aeacac67dc152820f0e);
        mrs[6] = bytes32(0x605ad10c1a56ed7289f198d64a39a952cd3b8a0bed3fcb19c8301c1847dc3a2f);
        mrs[7] = bytes32(0x631778b0d420d2d0bba4c730b0fd74857afeefb3429371ae97ab450e40ca127e);
        mrs[8] = bytes32(0x67742ab222790e20ba3656b3b294645a3384a5df5a770b86f8c06529523d990e);
        mrs[9] = bytes32(0x6e43c1d575b5b785d0f6259dfac44998c6f0c164864f9f98270fb740c14eb943);
        mrs[10] = bytes32(0x8f73135b83a84126c7fff37ea02f9363e134aea0f6446b13e198b20d94e75099);
        mrs[11] = bytes32(0x9546301721e2ea111ab0f79b6e529d6bb6c486ac98bcf7739429ad06c09db63d);
        mrs[12] = bytes32(0xa096348d480eb0474f5eab182671933c029545521960d87d4e49283005809be9);
        mrs[13] = bytes32(0xa4eedfc6484494d4c08bfb9b9dd887c6e0540ba9d8ee207fe0e16814852e3356);
        mrs[14] = bytes32(0xa5f741bfed254a1e21738d429e7bd074e25918af7f71fbe1e0135c3974b06e00);
        mrs[15] = bytes32(0xb09f9005e4612526e378466b5c16ab6028478e81c085812d6ed37166c4cda10e);
        mrs[16] = bytes32(0xbdec26abd36fde2cfbb8db7a0793a9346b11bd558b39890407d458500711c88c);
        mrs[17] = bytes32(0xc90e5d2e39d1d3f8397a6048c32ba50139d1577c28985e1f7638785935f41734);
        mrs[18] = bytes32(0xca349ba0dfeced0bd837a56c97417c11e51d490eec4ff08321dd130776a413bd);
        mrs[19] = bytes32(0xdcd483d3406d9b1871bb92420f5a080c4372e0d6b8522a4a2cb91a0f736669c6);
        mrs[20] = bytes32(0xddda8ba9c9153e3d2f680f2f53adbc774a9753cc55d40dde4cb02aef38c42109);
        mrs[21] = bytes32(0xdfcb4fca3073e3f3a90b05d328688c32619d56f26789c0a9797aa10e765a7807);
        mrs[22] = bytes32(0xe2375b778ee5700a73c7fcf449abb4a62e00127d324b6694898073ba5aff4f5c);
        mrs[23] = bytes32(0xe5774b71990b0d5f3eca8d4d22546764dd9549c743a1a6d4d4863d97f6b8c67a);
        mrs[24] = bytes32(0xf285b7cbd78d2b96cdc54cfea3e47d8f510a4b4f91b719c97f8bbb90974f805b);
    }

    function _deleteIds(
        uint256 nextInstanceId,
        uint256[] memory allowedIds
    )
        private
        pure
        returns (uint256[] memory ids)
    {
        uint256 count;
        for (uint256 id; id < nextInstanceId; ++id) {
            if (!_contains(allowedIds, id)) {
                ++count;
            }
        }

        ids = new uint256[](count);
        uint256 cursor;
        for (uint256 id; id < nextInstanceId; ++id) {
            if (!_contains(allowedIds, id)) {
                ids[cursor++] = id;
            }
        }
    }

    function _contains(uint256[] memory ids, uint256 id) private pure returns (bool) {
        for (uint256 i; i < ids.length; ++i) {
            if (ids[i] == id) {
                return true;
            }
        }
        return false;
    }
}
