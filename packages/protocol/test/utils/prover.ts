import { TaikoL1 } from "../../typechain";

class Prover {
    private readonly taikoL1: TaikoL1;
    constructor(taikoL1: TaikoL1) {
        this.taikoL1 = taikoL1;
    }

    async prove() {}
}

export default Prover;
