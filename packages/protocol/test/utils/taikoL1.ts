import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import { AddressManager, TaikoL1 } from "../../typechain";

const defaultFeeBase = BigNumber.from(10).pow(18);

async function deployTaikoL1(
    addressManager: AddressManager,
    genesisHash: string,
    enableTokenomics: boolean,
    feeBase?: BigNumber
): Promise<TaikoL1> {
    const libReceiptDecoder = await (
        await ethers.getContractFactory("LibReceiptDecoder")
    ).deploy();

    const libTxDecoder = await (
        await ethers.getContractFactory("LibTxDecoder")
    ).deploy();

    const libProposing = await (
        await ethers.getContractFactory("LibProposing")
    ).deploy();

    const testLibProving = await (
        await ethers.getContractFactory("TestLibProving", {
            libraries: {
                LibReceiptDecoder: libReceiptDecoder.address,
                LibTxDecoder: libTxDecoder.address,
            },
        })
    ).deploy();

    const libVerifying = await (
        await ethers.getContractFactory("LibVerifying")
    ).deploy();

    const taikoL1 = await (
        await ethers.getContractFactory(
            enableTokenomics ? "TestTaikoL1EnableTokenomics" : "TestTaikoL1",
            {
                libraries: {
                    LibVerifying: libVerifying.address,
                    LibProposing: libProposing.address,
                    LibProving: testLibProving.address,
                },
            }
        )
    ).deploy();

    await (
        await taikoL1.init(
            addressManager.address,
            genesisHash,
            feeBase ?? defaultFeeBase
        )
    ).wait(1);

    return taikoL1 as TaikoL1;
}

export { deployTaikoL1, defaultFeeBase };
