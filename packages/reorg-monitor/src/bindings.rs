use alloy::sol;

sol! {
    #[sol(rpc)]
    interface IPreconfWhitelist {
        function getOperatorForCurrentEpoch() external view returns (address);
    }
}
