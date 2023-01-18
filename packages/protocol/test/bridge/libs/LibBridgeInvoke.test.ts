import { expect } from "chai";
import { ethers } from "hardhat";
import { Message } from "../../utils/message";
import {
    TestLibBridgeData,
    TestLibBridgeInvoke,
    TestReceiver,
} from "../../../typechain";

// TODO(roger): we should deprecate these test and test Bridge.sol
// as a whole.
describe("LibBridgeInvoke", function () {
    let owner: any;
    let nonOwner: any;
    let libInvoke: TestLibBridgeInvoke;
    let libData: TestLibBridgeData;

    before(async function () {
        [owner, nonOwner] = await ethers.getSigners();
    });

    beforeEach(async function () {
        libInvoke = await (
            await ethers.getContractFactory("TestLibBridgeInvoke")
        ).deploy();

        libData = await (
            await ethers.getContractFactory("TestLibBridgeData")
        ).deploy();
    });

    describe("invokeMessageCall()", async function () {
        it("should throw when gasLimit <= 0", async function () {
            const message: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: 1,
                destChainId: 5,
                owner: owner.address,
                to: nonOwner.address,
                refundAddress: owner.address,
                depositValue: 1,
                callValue: 1,
                processingFee: 1,
                gasLimit: 0,
                data: ethers.constants.HashZero,
                memo: "",
            };

            const signal = await libData.hashMessage(message);

            await expect(
                libInvoke.invokeMessageCall(message, signal, message.gasLimit)
            ).to.be.revertedWith("B:gasLimit");
        });

        it("should emit event with success false if message does not actually invoke", async function () {
            const message: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: 1,
                destChainId: 5,
                owner: owner.address,
                to: nonOwner.address,
                refundAddress: owner.address,
                depositValue: 1,
                callValue: 1,
                processingFee: 1,
                gasLimit: 100,
                data: ethers.constants.HashZero,
                memo: "",
            };

            const signal = await libData.hashMessage(message);

            await expect(
                libInvoke.invokeMessageCall(message, signal, message.gasLimit)
            )
                .to.emit(libInvoke, "MessageInvoked")
                .withArgs(signal, false);
        });

        it("should emit event with success true if message invokes successfully", async function () {
            const testReceiver: TestReceiver = await (
                await ethers.getContractFactory("TestReceiver")
            ).deploy();

            await testReceiver.deployed();

            const ABI = ["function receiveTokens(uint256) payable"];
            const iface = new ethers.utils.Interface(ABI);
            const data = iface.encodeFunctionData("receiveTokens", [1]);

            const message: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: 1,
                destChainId: 5,
                owner: owner.address,
                to: testReceiver.address,
                refundAddress: owner.address,
                depositValue: 1,
                callValue: 1,
                processingFee: 1,
                gasLimit: 300000,
                data: data,
                memo: "",
            };

            const signal = await libData.hashMessage(message);

            await expect(
                libInvoke.invokeMessageCall(message, signal, message.gasLimit, {
                    value: message.callValue,
                })
            )
                .to.emit(libInvoke, "MessageInvoked")
                .withArgs(signal, true);
        });
    });
});
