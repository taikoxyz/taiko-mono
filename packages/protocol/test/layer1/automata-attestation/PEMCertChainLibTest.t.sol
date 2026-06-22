// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import "src/layer1/automata-attestation/lib/PEMCertChainLib.sol";
import "src/layer1/automata-attestation/lib/interfaces/IPEMCertChainLib.sol";

/// @title TestPEMCertChainLib
/// @notice Unit tests for PEMCertChainLib.decodeCert covering the SGX PCK
/// certificate extension parsing (`_findTcb`) and the X509 validity date-tag check.
/// @custom:security-contact security@taiko.xyz
contract TestPEMCertChainLib is Test {
    PEMCertChainLib internal lib;

    // A real Intel SGX PCK certificate (DER), extracted from the sample DCAP v3
    // quote used by the existing attestation tests.
    //
    // Relevant offsets inside this DER (verified against the ASN.1 structure):
    //  - [164]      notBefore UTCTime tag (0x17)
    //  - [685..703] first SGX TCB component sub-sequence (OID ...1.2.1), 18 bytes
    //  - [975..993] PCESVN sub-sequence (OID ...1.2.17),                 18 bytes
    bytes internal constant PCK_DER =
        hex"308204f330820499a003020102021500bcfe8d88f1717f9f26898051b089aa089f22897a300a06082a8648ce3d04030230703122302006035504030c19496e74656c205347582050434b20506c6174666f726d204341311a3018060355040a0c11496e74656c20436f72706f726174696f6e3114301206035504070c0b53616e746120436c617261310b300906035504080c024341310b3009060355040613025553301e170d3233303832383131313330355a170d3330303832383131313330355a30703122302006035504030c19496e74656c205347582050434b204365727469666963617465311a3018060355040a0c11496e74656c20436f72706f726174696f6e3114301206035504070c0b53616e746120436c617261310b300906035504080c024341310b30090603550406130255533059301306072a8648ce3d020106082a8648ce3d0301070342000432b004ab4baae47a3d781dfd494a9b8f3b5343515cb35c10afa75878d85d74514d001545a0d58e3ca1e060eedbcde57d884c6101e731c18f38eff64b96c948d4a382030e3082030a301f0603551d23041830168014956f5dcdbd1be1e94049c9d4f433ce01570bde54306b0603551d1f046430623060a05ea05c865a68747470733a2f2f6170692e7472757374656473657276696365732e696e74656c2e636f6d2f7367782f63657274696669636174696f6e2f76342f70636b63726c3f63613d706c6174666f726d26656e636f64696e673d646572301d0603551d0e041604145357a665cf5bc991849f9098fc3627f3aa06b058300e0603551d0f0101ff0404030206c0300c0603551d130101ff040230003082023b06092a864886f84d010d010482022c30820228301e060a2a864886f84d010d01010410fe46ae011cce8a4d6e8334b08d1bb40130820165060a2a864886f84d010d0102308201553010060b2a864886f84d010d01020102010b3010060b2a864886f84d010d01020202010b3010060b2a864886f84d010d0102030201033010060b2a864886f84d010d0102040201033011060b2a864886f84d010d010205020200ff3011060b2a864886f84d010d010206020200ff3010060b2a864886f84d010d0102070201003010060b2a864886f84d010d0102080201003010060b2a864886f84d010d0102090201003010060b2a864886f84d010d01020a0201003010060b2a864886f84d010d01020b0201003010060b2a864886f84d010d01020c0201003010060b2a864886f84d010d01020d0201003010060b2a864886f84d010d01020e0201003010060b2a864886f84d010d01020f0201003010060b2a864886f84d010d0102100201003010060b2a864886f84d010d01021102010d301f060b2a864886f84d010d01021204100b0b0303ffff000000000000000000003010060a2a864886f84d010d0103040200003014060a2a864886f84d010d0104040600606a000000300f060a2a864886f84d010d01050a0101301e060a2a864886f84d010d010604104589ccebf2644f0ade48ff1e15c46bfb3044060a2a864886f84d010d010730363010060b2a864886f84d010d0107010101ff3010060b2a864886f84d010d0107020101ff3010060b2a864886f84d010d0107030101ff300a06082a8648ce3d040302034800304502201ab7bf1d8335a99004599474c7be98f6040aef385e0a050a0230489578709693022100e37a7bb6bc01f34b3eda2c1a8660dd02708cc0954f2e2484bb00d017c544812c";

    uint256 internal constant COMP01_OFF = 685;
    uint256 internal constant PCESVN_OFF = 975;
    uint256 internal constant SUBSEQ_LEN = 18;
    uint256 internal constant NOT_BEFORE_TAG_OFF = 164;

    function setUp() public {
        lib = new PEMCertChainLib();
    }

    /// @dev Sanity check: the unmodified PCK certificate decodes successfully and
    /// the 16 TCB component SVNs plus PCESVN are parsed as expected.
    function test_decodeCert_parsesRealPckCertificate() public view {
        (bool ok, IPEMCertChainLib.ECSha256Certificate memory cert) = lib.decodeCert(PCK_DER, true);
        assertTrue(ok, "real PCK cert must decode");
        assertEq(cert.pck.sgxExtension.sgxTcbCompSvnArr.length, 16, "16 cpusvns");
        assertEq(cert.pck.sgxExtension.sgxTcbCompSvnArr[0], 11, "first comp svn");
        assertEq(cert.pck.sgxExtension.pcesvn, 13, "pcesvn");
    }

    /// @dev Regression test for the SGX-extension TCB parser (`_findTcb`).
    ///
    /// `_findTcb` iterates over the 17 leading entries of the TCB sequence (16
    /// component SVNs followed by PCESVN). A structurally valid PCK certificate
    /// whose PCESVN entry is not in the final position causes a component SVN to
    /// be written past the end of the fixed length-16 `cpusvns` array, panicking
    /// with an out-of-bounds access instead of failing gracefully like every
    /// other malformed-input path in `decodeCert`.
    ///
    /// We reproduce this by swapping the (equal length) PCESVN sub-sequence with
    /// the first component SVN sub-sequence; all DER length prefixes stay valid.
    function test_decodeCert_reorderedTcbExtension_doesNotPanic() public view {
        bytes memory der = PCK_DER;
        // Swap the two 18-byte sub-sequences in place.
        for (uint256 k; k < SUBSEQ_LEN; ++k) {
            (der[COMP01_OFF + k], der[PCESVN_OFF + k]) = (der[PCESVN_OFF + k], der[COMP01_OFF + k]);
        }

        // Must return gracefully (no array out-of-bounds panic).
        (bool ok,) = lib.decodeCert(der, true);
        assertTrue(ok, "reordered TCB extension must not panic");
    }

    /// @dev Regression test for the X509 validity date-tag check.
    ///
    /// The validity tags must be either UTCTime (0x17) or GeneralizedTime (0x18).
    /// An earlier version of this check accepted certain invalid notBefore tags;
    /// a certificate whose notBefore tag is neither 0x17 nor 0x18 must be rejected.
    function test_decodeCert_rejectsInvalidNotBeforeDateTag() public view {
        bytes memory der = PCK_DER;
        // 0x16 (IA5String) is not a valid X509 time tag.
        der[NOT_BEFORE_TAG_OFF] = 0x16;

        (bool ok,) = lib.decodeCert(der, true);
        assertFalse(ok, "invalid notBefore date tag must be rejected");
    }
}
