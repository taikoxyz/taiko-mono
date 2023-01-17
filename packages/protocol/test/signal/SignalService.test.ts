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
