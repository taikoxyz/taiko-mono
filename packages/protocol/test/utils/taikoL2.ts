import { ethers } from "ethers";
import { ethers as hardhatEthers } from "hardhat";
import { TaikoL2 } from "../../typechain";

async function deployTaikoL2(
    signer: ethers.Signer,
    gasLimit: number | undefined = undefined
): Promise<TaikoL2> {
    const taikoL2 = await (
        await hardhatEthers.getContractFactory("TestTaikoL2")
    )
        .connect(signer)
        .deploy({ gasLimit });

    return taikoL2 as TaikoL2;
}

export { deployTaikoL2 };
