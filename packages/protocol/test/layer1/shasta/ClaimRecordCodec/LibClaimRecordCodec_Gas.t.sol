// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibClaimRecordCodec } from "src/layer1/shasta/libs/LibClaimRecordCodec.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";
import { CommonTest } from "test/shared/CommonTest.sol";
import "forge-std/src/console2.sol";

/// @title LibClaimRecordCodec_Gas
/// @notice Gas comparison tests between optimized codec and abi.encode/decode baseline
/// @custom:security-contact security@taiko.xyz
contract LibClaimRecordCodec_Gas is CommonTest {
    event GasReport(string operation, uint256 baseline, uint256 optimized, int256 difference);

    function encodeBaseline(IInbox.ClaimRecord memory _claimRecord) private pure returns (bytes memory) {
        return abi.encode(_claimRecord);
    }

    function decodeBaseline(bytes memory _data)
        private pure
        returns (IInbox.ClaimRecord memory claimRecord_)
    {
        claimRecord_ = abi.decode(_data, (IInbox.ClaimRecord));
    }

    function test_gasComparison_standard() public {
        LibBonds.BondInstruction[] memory bondInstructions = new LibBonds.BondInstruction[](3);
        bondInstructions[0] = LibBonds.BondInstruction({
            proposalId: 12_345,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: address(0x1111111111111111111111111111111111111111),
            receiver: address(0x2222222222222222222222222222222222222222)
        });
        bondInstructions[1] = LibBonds.BondInstruction({
            proposalId: 12_346,
            bondType: LibBonds.BondType.LIVENESS,
            payer: address(0x3333333333333333333333333333333333333333),
            receiver: address(0x4444444444444444444444444444444444444444)
        });
        bondInstructions[2] = LibBonds.BondInstruction({
            proposalId: 12_347,
            bondType: LibBonds.BondType.NONE,
            payer: address(0x5555555555555555555555555555555555555555),
            receiver: address(0x6666666666666666666666666666666666666666)
        });

        IInbox.ClaimRecord memory claimRecord = IInbox.ClaimRecord({
            proposalId: 12_345,
            claim: IInbox.Claim({
                proposalHash: keccak256("proposal"),
                parentClaimHash: keccak256("parentClaim"),
                endBlockNumber: 999_999,
                endBlockHash: keccak256("endBlock"),
                endStateRoot: keccak256("endState"),
                designatedProver: address(0x7777777777777777777777777777777777777777),
                actualProver: address(0x8888888888888888888888888888888888888888)
            }),
            span: 5,
            bondInstructions: bondInstructions
        });

        uint256 gasStart;
        uint256 gasEnd;
        uint256 baselineEncodeGas;
        uint256 optimizedEncodeGas;
        uint256 baselineDecodeGas;
        uint256 optimizedDecodeGas;

        gasStart = gasleft();
        bytes memory baselineEncoded = encodeBaseline(claimRecord);
        gasEnd = gasleft();
        baselineEncodeGas = gasStart - gasEnd;

        gasStart = gasleft();
        bytes memory optimizedEncoded = LibClaimRecordCodec.encode(claimRecord);
        gasEnd = gasleft();
        optimizedEncodeGas = gasStart - gasEnd;

        gasStart = gasleft();
        decodeBaseline(baselineEncoded);
        gasEnd = gasleft();
        baselineDecodeGas = gasStart - gasEnd;

        gasStart = gasleft();
        LibClaimRecordCodec.decode(optimizedEncoded);
        gasEnd = gasleft();
        optimizedDecodeGas = gasStart - gasEnd;

        console2.log("");
        console2.log("Gas Comparison: Standard (3 bond instructions)");
        console2.log("| Operation | Baseline | Optimized | Difference |");
        console2.log("|-----------|----------|-----------|------------|");
        console2.log(
            string.concat(
                "| Encode    | ",
                vm.toString(baselineEncodeGas),
                "     | ",
                vm.toString(optimizedEncodeGas),
                "      | ",
                optimizedEncodeGas > baselineEncodeGas ? "+" : "-",
                vm.toString(
                    optimizedEncodeGas > baselineEncodeGas 
                        ? optimizedEncodeGas - baselineEncodeGas 
                        : baselineEncodeGas - optimizedEncodeGas
                ),
                "      |"
            )
        );
        console2.log(
            string.concat(
                "| Decode    | ",
                vm.toString(baselineDecodeGas),
                "     | ",
                vm.toString(optimizedDecodeGas),
                "      | ",
                optimizedDecodeGas > baselineDecodeGas ? "+" : "-",
                vm.toString(
                    optimizedDecodeGas > baselineDecodeGas 
                        ? optimizedDecodeGas - baselineDecodeGas 
                        : baselineDecodeGas - optimizedDecodeGas
                ),
                "      |"
            )
        );

        console2.log("");
        console2.log("Data size comparison:");
        console2.log(string.concat("Baseline: ", vm.toString(baselineEncoded.length), " bytes"));
        console2.log(string.concat("Optimized: ", vm.toString(optimizedEncoded.length), " bytes"));
        console2.log(string.concat("Size reduction: ", vm.toString((baselineEncoded.length - optimizedEncoded.length) * 100 / baselineEncoded.length), "%"));

        emit GasReport("encode_standard", baselineEncodeGas, optimizedEncodeGas, int256(optimizedEncodeGas) - int256(baselineEncodeGas));
        emit GasReport("decode_standard", baselineDecodeGas, optimizedDecodeGas, int256(optimizedDecodeGas) - int256(baselineDecodeGas));
    }

    function test_gasComparison_minimal() public {
        IInbox.ClaimRecord memory claimRecord = IInbox.ClaimRecord({
            proposalId: 1,
            claim: IInbox.Claim({
                proposalHash: bytes32(uint256(1)),
                parentClaimHash: bytes32(uint256(2)),
                endBlockNumber: 100,
                endBlockHash: bytes32(uint256(3)),
                endStateRoot: bytes32(uint256(4)),
                designatedProver: address(1),
                actualProver: address(2)
            }),
            span: 1,
            bondInstructions: new LibBonds.BondInstruction[](0)
        });

        uint256 gasStart;
        uint256 gasEnd;
        uint256 baselineEncodeGas;
        uint256 optimizedEncodeGas;
        uint256 baselineDecodeGas;
        uint256 optimizedDecodeGas;

        gasStart = gasleft();
        bytes memory baselineEncoded = encodeBaseline(claimRecord);
        gasEnd = gasleft();
        baselineEncodeGas = gasStart - gasEnd;

        gasStart = gasleft();
        bytes memory optimizedEncoded = LibClaimRecordCodec.encode(claimRecord);
        gasEnd = gasleft();
        optimizedEncodeGas = gasStart - gasEnd;

        gasStart = gasleft();
        decodeBaseline(baselineEncoded);
        gasEnd = gasleft();
        baselineDecodeGas = gasStart - gasEnd;

        gasStart = gasleft();
        LibClaimRecordCodec.decode(optimizedEncoded);
        gasEnd = gasleft();
        optimizedDecodeGas = gasStart - gasEnd;

        console2.log("");
        console2.log("Gas Comparison: Minimal (0 bond instructions)");
        console2.log("| Operation | Baseline | Optimized | Difference |");
        console2.log("|-----------|----------|-----------|------------|");
        console2.log(
            string.concat(
                "| Encode    | ",
                vm.toString(baselineEncodeGas),
                "     | ",
                vm.toString(optimizedEncodeGas),
                "      | ",
                optimizedEncodeGas > baselineEncodeGas ? "+" : "-",
                vm.toString(
                    optimizedEncodeGas > baselineEncodeGas 
                        ? optimizedEncodeGas - baselineEncodeGas 
                        : baselineEncodeGas - optimizedEncodeGas
                ),
                "      |"
            )
        );
        console2.log(
            string.concat(
                "| Decode    | ",
                vm.toString(baselineDecodeGas),
                "     | ",
                vm.toString(optimizedDecodeGas),
                "      | ",
                optimizedDecodeGas > baselineDecodeGas ? "+" : "-",
                vm.toString(
                    optimizedDecodeGas > baselineDecodeGas 
                        ? optimizedDecodeGas - baselineDecodeGas 
                        : baselineDecodeGas - optimizedDecodeGas
                ),
                "      |"
            )
        );

        console2.log("");
        console2.log("Data size comparison:");
        console2.log(string.concat("Baseline: ", vm.toString(baselineEncoded.length), " bytes"));
        console2.log(string.concat("Optimized: ", vm.toString(optimizedEncoded.length), " bytes"));
        console2.log(string.concat("Size reduction: ", vm.toString((baselineEncoded.length - optimizedEncoded.length) * 100 / baselineEncoded.length), "%"));

        emit GasReport("encode_minimal", baselineEncodeGas, optimizedEncodeGas, int256(optimizedEncodeGas) - int256(baselineEncodeGas));
        emit GasReport("decode_minimal", baselineDecodeGas, optimizedDecodeGas, int256(optimizedDecodeGas) - int256(baselineDecodeGas));
    }

    function test_gasComparison_maximum() public {
        LibBonds.BondInstruction[] memory bondInstructions = new LibBonds.BondInstruction[](127);
        for (uint256 i = 0; i < 127; i++) {
            bondInstructions[i] = LibBonds.BondInstruction({
                proposalId: uint48(i),
                bondType: LibBonds.BondType(i % 3),
                payer: address(uint160(i + 1)),
                receiver: address(uint160(i + 2))
            });
        }

        IInbox.ClaimRecord memory claimRecord = IInbox.ClaimRecord({
            proposalId: type(uint48).max,
            claim: IInbox.Claim({
                proposalHash: bytes32(type(uint256).max),
                parentClaimHash: bytes32(type(uint256).max - 1),
                endBlockNumber: type(uint48).max,
                endBlockHash: bytes32(type(uint256).max - 2),
                endStateRoot: bytes32(type(uint256).max - 3),
                designatedProver: address(type(uint160).max),
                actualProver: address(type(uint160).max - 1)
            }),
            span: type(uint8).max,
            bondInstructions: bondInstructions
        });

        uint256 gasStart;
        uint256 gasEnd;
        uint256 baselineEncodeGas;
        uint256 optimizedEncodeGas;
        uint256 baselineDecodeGas;
        uint256 optimizedDecodeGas;

        gasStart = gasleft();
        bytes memory baselineEncoded = encodeBaseline(claimRecord);
        gasEnd = gasleft();
        baselineEncodeGas = gasStart - gasEnd;

        gasStart = gasleft();
        bytes memory optimizedEncoded = LibClaimRecordCodec.encode(claimRecord);
        gasEnd = gasleft();
        optimizedEncodeGas = gasStart - gasEnd;

        gasStart = gasleft();
        decodeBaseline(baselineEncoded);
        gasEnd = gasleft();
        baselineDecodeGas = gasStart - gasEnd;

        gasStart = gasleft();
        LibClaimRecordCodec.decode(optimizedEncoded);
        gasEnd = gasleft();
        optimizedDecodeGas = gasStart - gasEnd;

        console2.log("");
        console2.log("Gas Comparison: Maximum (127 bond instructions)");
        console2.log("| Operation | Baseline | Optimized | Difference |");
        console2.log("|-----------|----------|-----------|------------|");
        console2.log(
            string.concat(
                "| Encode    | ",
                vm.toString(baselineEncodeGas),
                "    | ",
                vm.toString(optimizedEncodeGas),
                "     | ",
                optimizedEncodeGas > baselineEncodeGas ? "+" : "-",
                vm.toString(
                    optimizedEncodeGas > baselineEncodeGas 
                        ? optimizedEncodeGas - baselineEncodeGas 
                        : baselineEncodeGas - optimizedEncodeGas
                ),
                "     |"
            )
        );
        console2.log(
            string.concat(
                "| Decode    | ",
                vm.toString(baselineDecodeGas),
                "    | ",
                vm.toString(optimizedDecodeGas),
                "    | ",
                optimizedDecodeGas > baselineDecodeGas ? "+" : "-",
                vm.toString(
                    optimizedDecodeGas > baselineDecodeGas 
                        ? optimizedDecodeGas - baselineDecodeGas 
                        : baselineDecodeGas - optimizedDecodeGas
                ),
                "    |"
            )
        );

        console2.log("");
        console2.log("Data size comparison:");
        console2.log(string.concat("Baseline: ", vm.toString(baselineEncoded.length), " bytes"));
        console2.log(string.concat("Optimized: ", vm.toString(optimizedEncoded.length), " bytes"));
        console2.log(string.concat("Size reduction: ", vm.toString((baselineEncoded.length - optimizedEncoded.length) * 100 / baselineEncoded.length), "%"));

        emit GasReport("encode_maximum", baselineEncodeGas, optimizedEncodeGas, int256(optimizedEncodeGas) - int256(baselineEncodeGas));
        emit GasReport("decode_maximum", baselineDecodeGas, optimizedDecodeGas, int256(optimizedDecodeGas) - int256(baselineDecodeGas));
    }

    function test_gasScaling() public {
        uint256[] memory sizes = new uint256[](5);
        sizes[0] = 1;
        sizes[1] = 10;
        sizes[2] = 25;
        sizes[3] = 50;
        sizes[4] = 100;

        console2.log("");
        console2.log("Gas Scaling with Bond Instructions:");
        console2.log("| Bond Count | Baseline Encode | Optimized Encode | Baseline Decode | Optimized Decode |");
        console2.log("|------------|-----------------|------------------|-----------------|------------------|");

        for (uint256 j = 0; j < sizes.length; j++) {
            uint256 bondCount = sizes[j];
            
            LibBonds.BondInstruction[] memory bondInstructions = new LibBonds.BondInstruction[](bondCount);
            for (uint256 i = 0; i < bondCount; i++) {
                bondInstructions[i] = LibBonds.BondInstruction({
                    proposalId: uint48(i),
                    bondType: LibBonds.BondType(i % 3),
                    payer: address(uint160(i + 1)),
                    receiver: address(uint160(i + 2))
                });
            }

            IInbox.ClaimRecord memory claimRecord = IInbox.ClaimRecord({
                proposalId: 12_345,
                claim: IInbox.Claim({
                    proposalHash: keccak256("proposal"),
                    parentClaimHash: keccak256("parentClaim"),
                    endBlockNumber: 999_999,
                    endBlockHash: keccak256("endBlock"),
                    endStateRoot: keccak256("endState"),
                    designatedProver: address(0x7777777777777777777777777777777777777777),
                    actualProver: address(0x8888888888888888888888888888888888888888)
                }),
                span: 5,
                bondInstructions: bondInstructions
            });

            uint256 gasStart;
            uint256 gasEnd;

            gasStart = gasleft();
            bytes memory baselineEncoded = encodeBaseline(claimRecord);
            gasEnd = gasleft();
            uint256 baselineEncodeGas = gasStart - gasEnd;

            gasStart = gasleft();
            bytes memory optimizedEncoded = LibClaimRecordCodec.encode(claimRecord);
            gasEnd = gasleft();
            uint256 optimizedEncodeGas = gasStart - gasEnd;

            gasStart = gasleft();
            decodeBaseline(baselineEncoded);
            gasEnd = gasleft();
            uint256 baselineDecodeGas = gasStart - gasEnd;

            gasStart = gasleft();
            LibClaimRecordCodec.decode(optimizedEncoded);
            gasEnd = gasleft();
            uint256 optimizedDecodeGas = gasStart - gasEnd;

            console2.log(
                string.concat(
                    "| ",
                    vm.toString(bondCount),
                    "        | ",
                    vm.toString(baselineEncodeGas),
                    "            | ",
                    vm.toString(optimizedEncodeGas),
                    "            | ",
                    vm.toString(baselineDecodeGas),
                    "            | ",
                    vm.toString(optimizedDecodeGas),
                    "           |"
                )
            );
        }
    }

    function test_validationOverhead() public {
        LibBonds.BondInstruction[] memory bondInstructions = new LibBonds.BondInstruction[](10);
        for (uint256 i = 0; i < 10; i++) {
            bondInstructions[i] = LibBonds.BondInstruction({
                proposalId: uint48(i),
                bondType: LibBonds.BondType.PROVABILITY,
                payer: address(uint160(i + 1)),
                receiver: address(uint160(i + 2))
            });
        }

        IInbox.ClaimRecord memory claimRecord = IInbox.ClaimRecord({
            proposalId: 12_345,
            claim: IInbox.Claim({
                proposalHash: keccak256("proposal"),
                parentClaimHash: keccak256("parentClaim"),
                endBlockNumber: 999_999,
                endBlockHash: keccak256("endBlock"),
                endStateRoot: keccak256("endState"),
                designatedProver: address(0x7777777777777777777777777777777777777777),
                actualProver: address(0x8888888888888888888888888888888888888888)
            }),
            span: 5,
            bondInstructions: bondInstructions
        });

        uint256 gasStart = gasleft();
        LibClaimRecordCodec.encode(claimRecord);
        uint256 gasEnd = gasleft();
        uint256 gasWithValidation = gasStart - gasEnd;

        console2.log("");
        console2.log("Validation Overhead Test:");
        console2.log(string.concat("Gas with validation: ", vm.toString(gasWithValidation)));
        console2.log("Note: Validation includes checking bond instruction count and bond types");
    }
}