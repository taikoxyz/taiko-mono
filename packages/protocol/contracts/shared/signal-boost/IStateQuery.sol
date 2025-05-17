// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

abstract contract IStateQuery {
    struct Query {
        // L1 contract to query
        address target;
        // Function selector and parameters of the view function
        bytes payload;
    }

    struct QueryResult {
        bool success;
        bytes output;
    }
}
