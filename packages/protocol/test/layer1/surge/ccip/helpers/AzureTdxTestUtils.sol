// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    EnclaveIdentityJsonObj,
    IAutomataEnclaveIdentityDao,
    IEnclaveIdentityHelper,
    IFmspcTcbDao,
    IdentityObj,
    TcbInfoJsonObj
} from "./AutomataInterfaces.sol";

/// @title AzureTDXTestUtils
/// @notice Helper library for setting up Azure TDX test environment
library AzureTDXTestUtils {
    /// @notice Sets up Automata mainnet collaterals for TDX verification
    function setUpAutomataMainnetCollaterals() internal {
        // solhint-disable-next-line max-line-length
        EnclaveIdentityJsonObj memory identityJson = EnclaveIdentityJsonObj(
            // solhint-disable-next-line max-line-length, quotes
            '{"id":"TD_QE","version":2,"issueDate":"2026-01-03T04:48:12Z","nextUpdate":"2026-02-02T04:48:12Z","tcbEvaluationDataNumber":18,"miscselect":"00000000","miscselectMask":"FFFFFFFF","attributes":"11000000000000000000000000000000","attributesMask":"FBFFFFFFFFFFFFFF0000000000000000","mrsigner":"DC9E2A7C6F948F17474E34A7FC43ED030F7C1563F1BABDDF6340C82E0E54A8C5","isvprodid":2,"tcbLevels":[{"tcb":{"isvsvn":4},"tcbDate":"2024-11-13T00:00:00Z","tcbStatus":"UpToDate"}]}',
            // solhint-disable-next-line max-line-length
            hex"60bb8c454c35cf3d5ae5e90ac791e1753c2b2052ed64df3c82d3507da9aa60d15fb521dfad69b5264696cd5632592424753462c490c7537212b6fdf3ba817352"
        );
        (IdentityObj memory identity,) = IEnclaveIdentityHelper(
                0x635A8A01e84cDcE1475FCeB7D57FEcadD3d1a0A0
            ).parseIdentityString(identityJson.identityStr);
        IAutomataEnclaveIdentityDao(0xc3ea5Ff40263E16cD2f4413152A77e7A6b10B0C9)
            .upsertEnclaveIdentity(uint256(identity.id), 4, identityJson);

        IFmspcTcbDao(0x63eF330eAaadA189861144FCbc9176dae41A5BAf)
            .upsertFmspcTcb(
                TcbInfoJsonObj(
                    // solhint-disable-next-line max-line-length, quotes
                    '{"id":"TDX","version":3,"issueDate":"2026-01-03T05:16:25Z","nextUpdate":"2026-02-02T05:16:25Z","fmspc":"90c06f000000","pceId":"0000","tcbType":0,"tcbEvaluationDataNumber":18,"tdxModule":{"mrsigner":"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000","attributes":"0000000000000000","attributesMask":"FFFFFFFFFFFFFFFF"},"tdxModuleIdentities":[{"id":"TDX_03","mrsigner":"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000","attributes":"0000000000000000","attributesMask":"FFFFFFFFFFFFFFFF","tcbLevels":[{"tcb":{"isvsvn":3},"tcbDate":"2024-11-13T00:00:00Z","tcbStatus":"UpToDate"}]},{"id":"TDX_01","mrsigner":"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000","attributes":"0000000000000000","attributesMask":"FFFFFFFFFFFFFFFF","tcbLevels":[{"tcb":{"isvsvn":6},"tcbDate":"2024-11-13T00:00:00Z","tcbStatus":"UpToDate"},{"tcb":{"isvsvn":4},"tcbDate":"2024-03-13T00:00:00Z","tcbStatus":"OutOfDate","advisoryIDs":["INTEL-SA-01036","INTEL-SA-01099"]},{"tcb":{"isvsvn":2},"tcbDate":"2023-08-09T00:00:00Z","tcbStatus":"OutOfDate","advisoryIDs":["INTEL-SA-01036","INTEL-SA-01099"]}]}],"tcbLevels":[{"tcb":{"sgxtcbcomponents":[{"svn":3,"category":"BIOS","type":"Early Microcode Update"},{"svn":3,"category":"OS/VMM","type":"SGX Late Microcode Update"},{"svn":2,"category":"OS/VMM","type":"TXT SINIT"},{"svn":2,"category":"BIOS"},{"svn":4,"category":"BIOS"},{"svn":1,"category":"BIOS"},{"svn":0},{"svn":5,"category":"OS/VMM","type":"SEAMLDR ACM"},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0}],"pcesvn":13,"tdxtcbcomponents":[{"svn":5,"category":"OS/VMM","type":"TDX Module"},{"svn":0,"category":"OS/VMM","type":"TDX Module"},{"svn":3,"category":"OS/VMM","type":"TDX Late Microcode Update"},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0}]},"tcbDate":"2024-11-13T00:00:00Z","tcbStatus":"UpToDate"},{"tcb":{"sgxtcbcomponents":[{"svn":2,"category":"BIOS","type":"Early Microcode Update"},{"svn":2,"category":"OS/VMM","type":"SGX Late Microcode Update"},{"svn":2,"category":"OS/VMM","type":"TXT SINIT"},{"svn":2,"category":"BIOS"},{"svn":3,"category":"BIOS"},{"svn":1,"category":"BIOS"},{"svn":0},{"svn":5,"category":"OS/VMM","type":"SEAMLDR ACM"},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0}],"pcesvn":13,"tdxtcbcomponents":[{"svn":5,"category":"OS/VMM","type":"TDX Module"},{"svn":0,"category":"OS/VMM","type":"TDX Module"},{"svn":2,"category":"OS/VMM","type":"TDX Late Microcode Update"},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0}]},"tcbDate":"2024-03-13T00:00:00Z","tcbStatus":"OutOfDate","advisoryIDs":["INTEL-SA-01036","INTEL-SA-01079","INTEL-SA-01099","INTEL-SA-01103","INTEL-SA-01111"]},{"tcb":{"sgxtcbcomponents":[{"svn":2,"category":"BIOS","type":"Early Microcode Update"},{"svn":2,"category":"OS/VMM","type":"SGX Late Microcode Update"},{"svn":2,"category":"OS/VMM","type":"TXT SINIT"},{"svn":2,"category":"BIOS"},{"svn":3,"category":"BIOS"},{"svn":1,"category":"BIOS"},{"svn":0},{"svn":5,"category":"OS/VMM","type":"SEAMLDR ACM"},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0}],"pcesvn":5,"tdxtcbcomponents":[{"svn":5,"category":"OS/VMM","type":"TDX Module"},{"svn":0,"category":"OS/VMM","type":"TDX Module"},{"svn":2,"category":"OS/VMM","type":"TDX Late Microcode Update"},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0},{"svn":0}]},"tcbDate":"2018-01-04T00:00:00Z","tcbStatus":"OutOfDate","advisoryIDs":["INTEL-SA-00106","INTEL-SA-00115","INTEL-SA-00135","INTEL-SA-00203","INTEL-SA-00220","INTEL-SA-00233","INTEL-SA-00270","INTEL-SA-00293","INTEL-SA-00320","INTEL-SA-00329","INTEL-SA-00381","INTEL-SA-00389","INTEL-SA-00477","INTEL-SA-00837","INTEL-SA-01036","INTEL-SA-01079","INTEL-SA-01099","INTEL-SA-01103","INTEL-SA-01111"]}]}',
                    // solhint-disable-next-line max-line-length
                    hex"e1bed059301e50a4c92a0657fc8733ad8cc7632da47bf7cc1cc2fd8646e271e1f5641af2280397ce9af1f78a6e7e3ef0782f004874154d5afe4526929973ad17"
                )
            );
    }
}
