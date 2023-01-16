import { expect } from "chai";
import { ethers } from "hardhat";
import RLP from "rlp";
import { sendMessage } from "../utils/bridge";
import { Message } from "../utils/message";
import { EthGetProofResponse } from "../utils/rpc";
import { getSignalSlot } from "../utils/signal";

describe("integration:LibTrieProof", function () {
    async function deployLibTrieProofFixture() {
        const libTrieProof = await (
            await ethers.getContractFactory("LibTrieProof")
        ).deploy();

        const testLibTreProof = await (
            await ethers.getContractFactory("TestLibTrieProof", {
                libraries: {
                    LibTrieProof: libTrieProof.address,
                },
            })
        ).deploy();

        const addressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy();
        await addressManager.init();

        const { chainId } = await ethers.provider.getNetwork();

        const enabledDestChainId = chainId + 1;

        await addressManager.setAddress(
            `${chainId}.ether_vault`,
            "0xEA3dD11036f668F08940E13e3bcB097C93b09E07"
        );

        await addressManager.setAddress(
            `${enabledDestChainId}.bridge`,
            "0x0000000000000000000000000000000000000001" // dummy address so chain is "enabled"
        );

        const libBridgeRetry = await (
            await ethers.getContractFactory("LibBridgeRetry")
        ).deploy();

        const libBridgeProcess = await (
            await ethers.getContractFactory("LibBridgeProcess", {
                libraries: {
                    LibTrieProof: libTrieProof.address,
                },
            })
        ).deploy();

        const BridgeFactory = await ethers.getContractFactory("Bridge", {
            libraries: {
                LibBridgeProcess: libBridgeProcess.address,
                LibBridgeRetry: libBridgeRetry.address,
                LibTrieProof: libTrieProof.address,
            },
        });

        const bridge = await BridgeFactory.deploy();

        await bridge.init(addressManager.address);

        const [owner] = await ethers.getSigners();

        return { owner, testLibTreProof, bridge, enabledDestChainId };
    }
    describe("verify()", function () {
        it("verifies", async function () {
            const { owner, testLibTreProof, bridge, enabledDestChainId } =
                await deployLibTrieProofFixture();

            const { chainId } = await ethers.provider.getNetwork();
            const srcChainId = chainId;

            const message: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: srcChainId,
                destChainId: enabledDestChainId,
                owner: owner.address,
                to: owner.address,
                refundAddress: owner.address,
                depositValue: 1000,
                callValue: 1000,
                processingFee: 1000,
                gasLimit: 10000,
                data: ethers.constants.HashZero,
                memo: "",
            };

            const { tx, signal } = await sendMessage(bridge, message);

            await tx.wait();

            expect(signal).not.to.be.eq(ethers.constants.HashZero);

            const messageStatus = await bridge.getMessageStatus(signal);

            expect(messageStatus).to.be.eq(0);

            const key = getSignalSlot(bridge.address, signal);

            // use this instead of ethers.provider.getBlock() beccause it doesnt have stateRoot
            // in the response
            const block: { stateRoot: string; number: string; hash: string } =
                await ethers.provider.send("eth_getBlockByNumber", [
                    "latest",
                    false,
                ]);

            // get storageValue for the key
            const storageValue = await ethers.provider.getStorageAt(
                bridge.address,
                key,
                block.number
            );
            // make sure it equals 1 so our proof will pass
            expect(storageValue).to.be.eq(
                "0x0000000000000000000000000000000000000000000000000000000000000001"
            );
            // rpc call to get the merkle proof what value is at key on the bridge contract
            const proof: EthGetProofResponse = await ethers.provider.send(
                "eth_getProof",
                [bridge.address, [key], block.hash]
            );

            const stateRoot = block.stateRoot;

            // RLP encode the proof together for LibTrieProof to decode
            const encodedProof = ethers.utils.defaultAbiCoder.encode(
                ["bytes", "bytes"],
                [
                    RLP.encode(proof.accountProof),
                    RLP.encode(proof.storageProof[0].proof),
                ]
            );
            // proof verifies the storageValue at key is 1
            await testLibTreProof.verify(
                stateRoot,
                bridge.address,
                key,
                "0x0000000000000000000000000000000000000000000000000000000000000001",
                encodedProof
            );
        });
    });
});
