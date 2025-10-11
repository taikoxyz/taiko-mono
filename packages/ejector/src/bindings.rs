use alloy::sol;

sol! {
    #[sol(rpc)]
    interface IPreconfWhitelist {
        uint8 public operatorCount;
        function getOperatorForCurrentEpoch() external view returns (address);
        function getOperatorForNextEpoch() external view returns (address);
        function removeOperator(address _proposer, bool _effectiveImmediately) external;
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
