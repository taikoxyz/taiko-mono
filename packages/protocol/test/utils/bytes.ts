import { ethers } from "hardhat";

function randomBytes32() {
    return ethers.utils.hexlify(ethers.utils.randomBytes(32));
}

export { randomBytes32 };
