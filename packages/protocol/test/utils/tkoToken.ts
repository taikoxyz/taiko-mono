import { ethers } from "ethers";
import { ethers as hardhatEthers } from "hardhat";
import { AddressManager } from "../../typechain";

const deployTkoToken = async (
    signer: ethers.Signer,
    addressManager: AddressManager,
    protoBroker: string
) => {
    const token = await (await hardhatEthers.getContractFactory("TestTkoToken"))
        .connect(signer)
        .deploy();
    await token.init(addressManager.address);

    const network = await signer.provider?.getNetwork();

    await addressManager.setAddress(
        `${network?.chainId}.proto_broker`,
        protoBroker
    );

    return token;
};

export default deployTkoToken;
