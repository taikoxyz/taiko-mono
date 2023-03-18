import { expect } from "chai";
import { ethers } from "hardhat";
import { AddressManager, SignalService } from "../../typechain";
import { deploySignalService } from "../utils/signal";
import deployAddressManager from "../utils/addressManager";
// import {getBlockHeader } from "../utils/rpc";

// TODO(roger): convert to integration tests and add a test case for isSignalReceived.
describe("SignalService", function () {
    let owner: any;
    let addr1: any;
    let addr2: any;
    let signalService: SignalService;

    before(async () => {
        [owner, addr1, addr2] = await ethers.getSigners();
        const { chainId } = await ethers.provider.getNetwork();

        const addressManager: AddressManager = await deployAddressManager(
            owner
        );

        ({ signalService } = await deploySignalService(
            owner,
            addressManager,
            chainId
        ));
    });

    describe("getSignalSlot()", function () {
        it("should return different slots for same signal from different apps", async () => {
            const signal = ethers.utils.keccak256(
                ethers.utils.toUtf8Bytes("a random")
            );
            const slot1 = await signalService.getSignalSlot(
                addr1.address,
                signal
            );
            const slot2 = signalService.getSignalSlot(addr2.address, signal);

            await expect(slot1).to.be.not.equal(slot2);
        });
        it.only("should return expected slot", async () => {
            const want =
                "0x9b11525774df15071344c44c56f02418dd56a9050effcc5de3912e88ccf1b95d";

            const slot = await signalService.getSignalSlot(
                "0x2aB7C0ab9AB47fcF370d13058BfEE28f2Ec0940c",
                "0xf697cc0b80c778b40a4e863d2d2a723cc707bcdf2ba463bb1cd28aa2c888b229"
            );

            await expect(slot).to.be.equal(want);
        });
    });

    describe("isSignalSent()", function () {
        it("should return false for unsent signal and true for sent signal", async () => {
            const signal = ethers.utils.keccak256(
                ethers.utils.toUtf8Bytes("another random")
            );
            let isSent = await signalService.isSignalSent(
                addr1.address,
                signal
            );
            await expect(isSent).to.be.equal(false);

            await signalService.connect(addr1).sendSignal(signal);
            isSent = await signalService.isSignalSent(addr1.address, signal);
            await expect(isSent).to.be.equal(true);
        });
    });
});
