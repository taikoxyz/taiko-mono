// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IFunctionSupport {
    function supportsFunction(bytes4 functionSelector) external view returns (bool);
}
