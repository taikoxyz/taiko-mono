import { BigNumber } from "ethers";
import { ethers } from "hardhat";

const sendTransaction = async (signer: any) => {
    signer.sendTransaction({
        to: ethers.constants.AddressZero,
        value: BigNumber.from(1),
    });
};

export default sendTransaction;
