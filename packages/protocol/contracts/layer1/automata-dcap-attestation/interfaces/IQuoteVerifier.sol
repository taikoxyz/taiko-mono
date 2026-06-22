//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IPCCSRouter} from "./IPCCSRouter.sol";
import {Header} from "../types/CommonStruct.sol";

/**
 * @title Automata DCAP Quote Verifier
 * @notice Provides the interface to implement version-specific verifiers
 */
interface IQuoteVerifier {
    /**
     * @dev this method must be immutable
     * @return an instance of the PCCSRouter interface
     */
    function pccsRouter() external view returns (IPCCSRouter);

    /**
     * @notice the quote version supported by this verifier
     */
    function quoteVersion() external view returns (uint16);

    function verifyQuote(Header calldata, bytes calldata, uint32 tcbEvalNumber)
        external
        view
        returns (bool, bytes memory);

    /**
     * @notice additional check on the public output obtained from the ZK Program execution
     */
    function verifyZkOutput(bytes calldata, uint32 tcbEvalNumber) external view returns (bool, bytes memory);
}
