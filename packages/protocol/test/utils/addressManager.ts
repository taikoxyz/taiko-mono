import { ethers } from "ethers";
import { ethers as hardhatEthers } from "hardhat";
import { AddressManager } from "../../typechain";

const deployAddressManager = async (signer: ethers.Signer) => {
    const addressManager: AddressManager = await (
        await hardhatEthers.getContractFactory("AddressManager")
    )
        .connect(signer)
        .deploy();
    await addressManager.init();
    return addressManager;
};

export default deployAddressManager;
