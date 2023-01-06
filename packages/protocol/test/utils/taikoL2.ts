import { ethers } from "hardhat";
import { TaikoL2 } from "../../typechain";

async function deployTaikoL2(signer: any): Promise<TaikoL2> {
    const addressManager = await (
        await ethers.getContractFactory("AddressManager")
    ).deploy();
    await addressManager.init();

    const l2AddressManager = await (
        await ethers.getContractFactory("AddressManager")
    )
        .connect(signer)
        .deploy();
    await l2AddressManager.init();

    // Deploying TaikoL2 Contract linked with LibTxDecoder (throws error otherwise)
    const l2LibTxDecoder = await (
        await ethers.getContractFactory("LibTxDecoder")
    )
        .connect(signer)
        .deploy();

    const taikoL2: TaikoL2 = await (
        await ethers.getContractFactory("TaikoL2", {
            libraries: {
                LibTxDecoder: l2LibTxDecoder.address,
            },
        })
    )
        .connect(signer)
        .deploy(l2AddressManager.address);

    return taikoL2;
}

export { deployTaikoL2 };
