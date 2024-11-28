# Test tree definitions

Below is the graphical definition of the contract tests implemented on [the test folder](./test)

```
TaikoL1Test
└── When a new TaikoL1 with 10 block slots and a sync interval of 5
    ├── When test1
    │   └── When case-1
    │       ├── It initializes the genesis block
    │       ├── It initializes the first transition
    │       ├── It finalizes the genesis block
    │       ├── It counts total blocks as 1
    │       ├── It retrieves correct data for the genesis block
    │       ├── It retrieves correct data for the genesis block's first transition
    │       ├── It fails to retrieve block 1, indicating block not found
    │       ├── It returns the genesis block and its first transition for getLastVerifiedTransitionV3
    │       └── It returns empty data for getLastSyncedTransitionV3 but does not revert
    ├── When proposing one more block with custom parameters
    │   └── When case-2
    │       ├── It places the block in the first slot
    │       ├── It sets the block's next transition id to 1
    │       ├── It the returned metahash should match the block's metahash
    │       ├── It matches the block's timestamp and anchor block id with the parameters
    │       ├── It total block count is 2
    │       └── It retrieves correct data for block 1
    ├── When proposing one more block with default parameters
    │   └── When case-3
    │       ├── It places the block in the first slot
    │       ├── It sets the block's next transition id to 1
    │       ├── It the returned metahash should match the block's metahash
    │       ├── It sets the block's timestamp to the current timestamp
    │       ├── It sets the block's anchor block id to block.number - 1
    │       ├── It total block count is 2
    │       └── It retrieves correct data for block 1
    ├── When proposing one more block with default parameters but nonzero parentMetaHash
    │   └── When case-4
    │       ├── It does not revert when the first block's parentMetaHash matches the genesis block's metahash
    │       └── It reverts when proposing a second block with a random parentMetaHash
    └── When proposing 9 blocks as a batch to fill all slots
        ├── When propose the 11th block before previous blocks are verified
        │   └── When case-5
        │       └── It reverts indicating no more slots available
        ├── When prove all existing blocks with correct first transitions
        │   ├── When proposing the 11th block after previous blocks are verified
        │   │   └── When case-6
        │   │       ├── It total block count is 12
        │   │       └── It getBlockV3(0) reverts indicating block not found
        │   └── When case-7
        │       ├── It total block count is 10
        │       ├── It returns the block 9 and its first transition for getLastVerifiedTransitionV3
        │       └── It returns the block 5 and its first transition for getLastSyncedTransitionV3
        ├── When prove all existing blocks with wrong first transitions
        │   ├── When prove all existing blocks with correct first transitions2
        │   │   └── When case-8
        │   │       ├── It total block count is 10
        │   │       ├── It returns the block 9 and its first transition for getLastVerifiedTransitionV3
        │   │       └── It returns the block 5 and its first transition for getLastSyncedTransitionV3
        │   └── When case-9
        │       ├── It total block count is 10
        │       ├── It returns the genesis block and its first transition for getLastVerifiedTransitionV3
        │       └── It returns empty data for getLastSyncedTransitionV3 but does not revert
        └── When case-10
            └── It total block count is 10
```
