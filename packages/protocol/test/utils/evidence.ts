import { BlockMetadata } from "./block_metadata";
import { BlockHeader } from "./rpc";

type ProverWithNonce = {
    addr: string;
    nonce: number;
};

type Evidence = {
    meta: BlockMetadata;
    header: BlockHeader;
    prover: ProverWithNonce;
    proofs: string[];
    circuits: number[];
};

export {ProverWithNonce, Evidence};
