import { BaseTrie, SecureTrie } from "merkle-patricia-tree";
import { ethers } from "ethers";
import * as rlp from "rlp";
import { randomBytes } from "crypto";

type Node = {
    key: Buffer;
    value: Buffer;
};

type Root = {
    root: Buffer;
};

type Proof = {
    proof: string;
};

type Test = {
    node: Node;
    root: Root;
    proof: Proof;
};

class MerkleTrie<T extends BaseTrie | SecureTrie> {
    public trie: T;
    public nodes: Node[] = [];
    private nodeLength: number;
    private amountOfNodes: number;

    constructor(amountOfNodes: number, nodeLength: number, f: () => T) {
        this.amountOfNodes = amountOfNodes;
        this.nodeLength = nodeLength;
        this.trie = f();
    }

    async init() {
        this.nodes = [];
        for (let i = 0; i < this.amountOfNodes; i++) {
            this.nodes.push(this.newRandomNode());
        }
        await this.build(this.nodes);
    }

    newRandomNode(): Node {
        return {
            key: randomBytes(this.nodeLength),
            value: randomBytes(this.nodeLength),
        };
    }

    async build(nodes: Node[]): Promise<void> {
        nodes.map(async (n) => await this.trie.put(n.key, n.value));
    }

    async makeTest(key: Buffer): Promise<Test> {
        const trie = this.trie.copy();
        const value = await trie.get(key);
        const proof = await BaseTrie.createProof(trie, key);

        return {
            node: {
                key: key,
                value: value as Buffer,
            },
            proof: {
                proof: ethers.utils.hexlify(rlp.encode(proof)),
            },
            root: {
                root: trie.root,
            },
        };
    }
}
export { MerkleTrie };
