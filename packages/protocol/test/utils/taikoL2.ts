import { ethers } from "ethers";
import { ethers as hardhatEthers } from "hardhat";
import { AddressManager, TaikoL2 } from "../../typechain";

async function deployTaikoL2(
    signer: ethers.Signer,
    addressManager: AddressManager,
    enablePublicInputsCheck: boolean = true,
    gasLimit: number | undefined = undefined
): Promise<TaikoL2> {
    const taikoL2 = await (
        await hardhatEthers.getContractFactory(
            enablePublicInputsCheck
                ? "TestTaikoL2EnablePublicInputsCheck"
                : "TestTaikoL2"
        )
    )
        .connect(signer)
        .deploy(addressManager.address, { gasLimit });

    return taikoL2 as TaikoL2;
}

export { deployTaikoL2 };
