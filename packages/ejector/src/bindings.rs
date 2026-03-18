use alloy::sol;

sol! {
    #[sol(rpc)]
    interface IPreconfWhitelist {
        /// @title IPreconfWhitelist
        /// @custom:security-contact security@taiko.xyz
        /// @notice Emitted when a new operator is added to the whitelist.
        /// @param proposer The proposer address of the operator that was added.
        /// @param sequencer The sequencer address of the operator that was added.
        /// @param activeSince The timestamp when the operator became active.
        event OperatorAdded(address indexed proposer, address indexed sequencer, uint256 activeSince);

        /// @notice Emitted when an operator is removed from the whitelist.
        /// @param proposer The proposer address of the operator that was removed.
        /// @param sequencer The sequencer address of the operator that was removed.
        /// @param inactiveSince The timestamp when the operator became inactive.
        event OperatorRemoved(
            address indexed proposer, address indexed sequencer, uint256 inactiveSince
        );

        /// @notice Emitted when an ejecter is updated.
        /// @param ejecter The address of the ejecter.
        /// @param isEjecter Whether the address is an ejecter.
        event EjecterUpdated(address indexed ejecter, bool isEjecter);

        /// @notice Adds a new operator to the whitelist.
        /// @param _proposer The proposer address of the operator to be added.
        /// @param _sequencer The sequencer address of the operator to be added.
        /// @dev Only callable by the owner or an authorized address.
        function addOperator(address _proposer, address _sequencer) external;

        /// @notice Removes an operator from the whitelist.
        /// @param _operatorId The ID of the operator to be removed.
        /// @dev Only callable by the owner or an authorized address.
        /// @dev Reverts if the operator ID does not exist.
        function removeOperator(uint256 _operatorId) external;

        /// @notice Removes an operator by proposer address.
        /// @param _proposer The proposer address of the operator to remove.
        function removeOperatorByAddress(address _proposer) external;

        /// @notice Retrieves the address of the operator for the current epoch.
        /// @dev Uses the beacon block root of the first block in the last epoch as the source
        ///      of randomness.
        /// @return The address of the operator.
        function getOperatorForCurrentEpoch() external view returns (address);

        /// @notice Retrieves the address of the operator for the next epoch.
        /// @dev Uses the beacon block root of the first block in the current epoch as the source
        ///      of randomness.
        /// @return The address of the operator.
        function getOperatorForNextEpoch() external view returns (address);

        function operatorCount() external view returns (uint8);
        function operatorMapping(uint256) view returns (address);
        function operators(address) view returns (uint32 activeSince, uint32 inactiveSince, uint8 index, address sequencerAddress);
    }
}

sol! {
    #[sol(rpc)]
    interface TaikoWrapper {
        address public immutable preconfRouter;
    }
}

sol! {
    #[sol(rpc)]
    interface PreconfRouter {
        // Note: returns tuple with a single uint256 field
        function getConfig() pure returns (uint256 handOverSlots);
    }
}

sol! {
    #[sol(rpc)]
    interface Anchor {
        struct BlockState {
            uint48 anchorBlockNumber;
            bytes32 ancestorsHash;
        }
        function getBlockState() external view returns (BlockState memory);
    }
}
