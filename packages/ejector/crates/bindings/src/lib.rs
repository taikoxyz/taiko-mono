use alloy::sol;

sol! {
    #[sol(rpc)]
    interface IPreconfWhitelist {
        function getOperatorForCurrentEpoch() external view returns (address);
        function getOperatorForNextEpoch() external view returns (address);
        function removeOperator(address _proposer, bool _effectiveImmediately) external;
    }
}

sol! {
    #[sol(rpc)]
    interface TaikoWrapper {
        address public immutable preconfRouter;
    }
}