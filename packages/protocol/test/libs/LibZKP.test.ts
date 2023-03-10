// eslint-disable-next-line import/no-named-default
import { expect } from "chai";
import hre, { ethers } from "hardhat";
import * as utils from "../../tasks/utils";
const testProof = require("../data/test_proof.json");

describe("LibZKP", function () {
    let libZKP: any;
    let plonkVerifierAddress: any;
    before(async function () {
        libZKP = await (await ethers.getContractFactory("TestLibZKP")).deploy();
        plonkVerifierAddress = await utils.deployBytecode(
            hre,
            utils.compileYulContract(
                "../contracts/libs/yul/PlonkVerifier_10_txs.yulp"
            ),
            "PlonkVerifier_10_txs"
        );
    });

    it("should successfully verifiy the given zkp and instance", async function () {
        const result = await libZKP.verify(
            plonkVerifierAddress,
            testProof.result.circuit.proof,
            ethers.utils.hexConcat([
                testProof.result.circuit.instance[0],
                testProof.result.circuit.instance[1],
            ])
        );

        expect(result).to.be.true;
    });

    it("should not successfully verifiy the given zkp and instance when the given contract address is not PlonkVerifier", async function () {
        // random EOA address
        let result = await libZKP.verify(
            ethers.Wallet.createRandom().address,
            testProof.result.circuit.proof,
            ethers.utils.hexConcat([
                testProof.result.circuit.instance[0],
                testProof.result.circuit.instance[1],
            ])
        );

        expect(result).to.be.false;

        // another smart contract
        const testERC20 = await utils.deployContract(hre, "TestERC20", {}, [
            1024,
        ]);
        result = await libZKP.verify(
            testERC20.address,
            testProof.result.circuit.proof,
            ethers.utils.hexConcat([
                testProof.result.circuit.instance[0],
                testProof.result.circuit.instance[1],
            ])
        );

        expect(result).to.be.false;
    });
});
