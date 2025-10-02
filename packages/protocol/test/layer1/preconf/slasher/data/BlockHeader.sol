// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/preconf/libs/LibBlockHeader.sol";

library BlockHeader {
    /// @dev Data from Taiko mainnet block 1200403
    function getActualBlockHeader() internal pure returns (LibBlockHeader.BlockHeader memory) {
        LibBlockHeader.BlockHeader memory actualBlockHeader = LibBlockHeader.BlockHeader({
            parentHash: 0xd6d919eacb75ec22afc33a26391ca0db028d270d2515ee7bf20915531a40a881,
            ommersHash: 0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347,
            coinbase: 0x41F2F55571f9e8e3Ba511Adc48879Bd67626A2b6,
            stateRoot: 0xe28374d49a13eefe04b74319ddde3931b617a5b2456bf17746a6491e52fe5e2c,
            transactionsRoot: 0x5b97d7c721cea5c22173b00825558cbd098b71ee21ff2c9cc0245cf84c1be80f,
            receiptRoot: 0x52b13cb594bf2395122c303df0d47c9260eb92b127846dffbdd89d2bc3b2e085,
            bloom: hex"ebfef54d2ffedd2fcff7d8fb6eb77f777ebfbfefbfdecf3bddf1fff777a7b3fbaff5fdadee7d79d3deffe36deeff3d7ef73bdf3ffc793f7cf5cffffffe6d7deffd2ffdfe8fedd56addb0f9bfd773e68dfbf7ff6b0edfdf5fbb41efaedcd16fb7da66b7f2bf5f5b95fbdf37fe7f79eebffebfff5fcbefd7deffbaef1278ecead7feaefffcef1dffffefbfef3dd9cffd96f8eff3bfdf6d7bfc7ffbbffa4f539a727ffeffe7fff3ff6bdf4fe2f77cf7f7b397ffee9bbff7aff7feffba4fabad7fffffbff3affb6fff7fe9bfdeeefd67fafcd975effbfd3dbf6f6f6fefdeffbff45f5ed29fdd6dfffaf7ebdffbbb2f9fffd39cdbdbef9d7fc7fe3bfe7f7aefb6fe69",
            difficulty: 0,
            number: 0x125113,
            gasLimit: 0xe5d5e40,
            gasUsed: 0x3ab9680,
            timestamp: 0x68492357,
            extraData: hex"0000000000000000000000000000000000000000000000000000000000000032",
            prevRandao: 0xaafa35d898bd91c9a4bc9db02c47dd9cb8eeadffb3ee1cb7557e3b2f988835f4,
            nonce: 0x0000000000000000,
            baseFeePerGas: 0x989680,
            withdrawalsRoot: 0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421
        });

        return actualBlockHeader;
    }

    /// @dev Data from Taiko mainnet block 1200404
    function getVerifiedBlockHeader() internal pure returns (LibBlockHeader.BlockHeader memory) {
        LibBlockHeader.BlockHeader memory verifiedBlockHeader = LibBlockHeader.BlockHeader({
            parentHash: 0x0f7c9f6fcde5e1a3c2983db4513b21844c8101e4150eee907103b01dc2ba17fa,
            ommersHash: 0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347,
            coinbase: 0x41F2F55571f9e8e3Ba511Adc48879Bd67626A2b6,
            stateRoot: 0xd15ecf051407a54eaf684440a3fdd75a48afa685060e70f8e558394470a7491b,
            transactionsRoot: 0xdf4d01e37a07495a65a57fcc6dedbcddad01511ad0fa0d61598aa2fa3edf7397,
            receiptRoot: 0xb7d6ed1cad9e7b309a5f1fc370045cf04705cb771c28fa114494e8bbcc59d57e,
            bloom: hex"0238208000091853e180c80b12062e4100e462c83a12070b180823c272042d9c060900201ac0d8060c40004583140402062ec03060203f0632009032802421d5158000f18c6814a88810c01a040222c02442011618c448402010008e845468b0c8048260875dacc514c014081908092f90918020400adee80532a61a28612c930aa001c1a20232088080178440a24410098480d1083542240e490ad01f0880986ba0887ee0ac86821220888d940f340080284c38002a22243105a0406a0883060042a4ca10c549006acd00ec081ac5602d06128c008a0143214c6146a62162a012ba410004252080040088081003e00020044b28004503509430615c44121b24",
            difficulty: 0,
            number: 0x125114,
            gasLimit: 0xe5d5e40,
            gasUsed: 0xa45d19,
            timestamp: 0x6849237b,
            extraData: hex"0000000000000000000000000000000000000000000000000000000000000032",
            prevRandao: 0xc9b497c39d35269062f3ee8af427522b1502593809d313ebeb67af52d169f02e,
            nonce: 0x0000000000000000,
            baseFeePerGas: 0x989680,
            withdrawalsRoot: 0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421
        });

        return verifiedBlockHeader;
    }
}
