import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import { AddressManager, TaikoL1 } from "../../typechain";

const defaultBasefee = BigNumber.from(10).pow(18);

async function deployTaikoL1(
    addressManager: AddressManager,
    genesisHash: string,
    basefee?: BigNumber
): Promise<TaikoL1> {
    // const libProposing = await (
    //     await ethers.getContractFactory("LibProposing")
    // ).deploy();

    // const libProving = await (
    //     await ethers.getContractFactory("LibProving")
    // ).deploy();

    // const libVerifying = await (
    //     await ethers.getContractFactory("LibVerifying")
    // ).deploy();

    const taikoL1 = await (
        await ethers.getContractFactory(
            "TestTaikoL1EnableTokenomics"
            // {
            //     libraries: {
            //         LibVerifying: libVerifying.address,
            //         LibProposing: libProposing.address,
            //         LibProving: libProving.address,
            //     },
            // }
        )
    ).deploy();

    await (
        await taikoL1.init(
            addressManager.address,
            genesisHash,
            basefee ?? defaultBasefee
        )
    ).wait(1);

    return taikoL1 as TaikoL1;
}

export { deployTaikoL1, defaultBasefee };
