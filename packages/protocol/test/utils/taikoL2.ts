import { ethers } from "ethers";
import { ethers as hardhatEthers } from "hardhat";
import { AddressManager, TaikoL2 } from "../../typechain";

async function deployTaikoL2(
    signer: ethers.Signer,
    addressManager: AddressManager,
    enablePublicInputsCheck: boolean = true
): Promise<TaikoL2> {
    // Deploying TaikoL2 Contract linked with LibTxDecoder (throws error otherwise)
    const l2LibTxDecoder = await (
        await hardhatEthers.getContractFactory("LibTxDecoder")
    )
        .connect(signer)
        .deploy();

    const taikoL2 = await (
        await hardhatEthers.getContractFactory(
            enablePublicInputsCheck
                ? "TestTaikoL2EnablePublicInputsCheck"
                : "TestTaikoL2",
            {
                libraries: {
                    LibTxDecoder: l2LibTxDecoder.address,
                },
            }
        )
    )
        .connect(signer)
        .deploy(addressManager.address);

    return taikoL2 as TaikoL2;
}

export { deployTaikoL2 };
