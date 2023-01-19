import { expect } from "chai";
import { ethers } from "hardhat";
import { TestLibBridgeData } from "../../../typechain";
import { K_BRIDGE_MESSAGE } from "../../constants/messages";
import { Message, MessageStatus } from "../../utils/message";

// TODO(roger): we should deprecate these test and test Bridge.sol
// as a whole.
describe("LibBridgeData", function () {
    let owner: any;
    let nonOwner: any;
    let testMessage: Message;
    let testTypes: any;
    let testVar: any;
    let libData: TestLibBridgeData;

    before(async function () {
        [owner, nonOwner] = await ethers.getSigners();

        testMessage = {
            id: 1,
            sender: owner.address,
            srcChainId: 1,
            destChainId: 2,
            owner: owner.address,
            to: nonOwner.address,
            refundAddress: owner.address,
            depositValue: 0,
            callValue: 0,
            processingFee: 0,
            gasLimit: 0,
            data: ethers.constants.HashZero,
            memo: "",
        };
        testTypes = [
            "string",
            "tuple(uint256 id, address sender, uint256 srcChainId, uint256 destChainId, address owner, address to, address refundAddress, uint256 depositValue, uint256 callValue, uint256 processingFee, uint256 gasLimit, bytes data, string memo)",
        ];

        testVar = [K_BRIDGE_MESSAGE, testMessage];
    });

    beforeEach(async function () {
        libData = await (
            await ethers.getContractFactory("TestLibBridgeData")
        ).deploy();
    });

    describe("hashMessage()", async function () {
        it("should return properly hashed message", async function () {
            const hashed = await libData.hashMessage(testMessage);
            const expectedEncoded = ethers.utils.defaultAbiCoder.encode(
                testTypes,
                testVar
            );

            const expectedHash = await ethers.utils.keccak256(expectedEncoded);

            expect(expectedHash).to.be.eq(hashed);
        });

        it("should return properly hashed message from actual bridge message", async function () {
            const testMessage: Message = {
                id: 0,
                sender: "0xDA1Ea1362475997419D2055dD43390AEE34c6c37",
                srcChainId: 31336,
                destChainId: 167001,
                owner: "0x4Ec242468812B6fFC8Be8FF423Af7bd23108d991",
                to: "0xF58b02228125baF4B232FF3F2f66F8b9229d5177",
                refundAddress: "0x4Ec242468812B6fFC8Be8FF423Af7bd23108d991",
                depositValue: 0,
                callValue: 0,
                processingFee: 0,
                gasLimit: 1000000,
                data: "0x0c6fab8200000000000000000000000000000000000000000000000000000000000000800000000000000000000000004ec242468812b6ffc8be8ff423af7bd23108d9910000000000000000000000004ec242468812b6ffc8be8ff423af7bd23108d99100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000007a68000000000000000000000000e48a03e23449975df36603c93f59a15e2de75c74000000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000004544553540000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000095465737445524332300000000000000000000000000000000000000000000000",
                memo: "CronJob SendTokens",
            };

            const hashed = await libData.hashMessage(testMessage);

            expect(
                "0xea159ca9f8fa8d139853755222c652413568310fab38095f5700286155a5179b"
            ).to.be.eq(hashed);
        });
    });

    describe("updateMessageStatus()", async function () {
        it("should emit upon successful change, and value should be changed correctly", async function () {
            const signal = await libData.hashMessage(testMessage);

            expect(
                await libData.updateMessageStatus(signal, MessageStatus.NEW)
            ).to.emit(libData, "MessageStatusChanged");

            const messageStatus = await libData.getMessageStatus(signal);

            expect(messageStatus).to.eq(MessageStatus.NEW);
        });

        it("unchanged MessageStatus should not emit event", async function () {
            const signal = await libData.hashMessage(testMessage);

            await libData.updateMessageStatus(signal, MessageStatus.NEW);

            expect(
                await libData.updateMessageStatus(signal, MessageStatus.NEW)
            ).to.not.emit(libData, "MessageStatusChanged");

            expect(await libData.getMessageStatus(signal)).to.eq(
                MessageStatus.NEW
            );
        });
    });
});
