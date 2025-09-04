use alloy_sol_macro::sol;

// Generate contract bindings from ABI JSON
sol!(
    #[allow(missing_docs)]
    #[sol(rpc)]
    #[derive(Debug)]
    InboxOptimized3,
    "abi/InboxOptimized3.json"
);
