//! Shared JSON-RPC server registration macro with metrics/error wrapping.

/// Register a JSON-RPC method and apply common logging/metrics/error-mapping flow.
#[macro_export]
macro_rules! register_rpc_method {
    ($module:expr, $method:expr, $ctx_ty:ty, |$params:ident, $ctx:ident| $call:expr, $record_metrics:path, $map_error:path, $request_log:expr) => {
        $module
            .register_async_method(
                $method,
                |$params: jsonrpsee::types::Params<'static>, $ctx: std::sync::Arc<$ctx_ty>, _| async move {
                    let start = std::time::Instant::now();
                    tracing::debug!(method = $method, $request_log);
                    let result = $call;
                    $record_metrics($method, &result, start.elapsed().as_secs_f64());
                    result.map_err($map_error)
                },
            )
            .expect("method registration should succeed");
    };
    ($module:expr, $method:expr, $ctx_ty:ty, |$ctx:ident| $call:expr, $record_metrics:path, $map_error:path, $request_log:expr) => {
        $module
            .register_async_method(
                $method,
                |_: jsonrpsee::types::Params<'static>, $ctx: std::sync::Arc<$ctx_ty>, _| async move {
                    let start = std::time::Instant::now();
                    tracing::debug!(method = $method, $request_log);
                    let result = $call;
                    $record_metrics($method, &result, start.elapsed().as_secs_f64());
                    result.map_err($map_error)
                },
            )
            .expect("method registration should succeed");
    };
}
