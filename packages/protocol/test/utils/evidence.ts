import { BlockMetadata } from "./block_metadata";
import { BlockHeader } from "./rpc";

type Evidence = {
    meta: BlockMetadata;
    header: BlockHeader;
    prover: string;
    proofs: string[];
    circuits: number[];
};

export default Evidence;
