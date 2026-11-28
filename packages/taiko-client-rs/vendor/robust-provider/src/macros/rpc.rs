//! Macros for generating robust RPC method wrappers with retry and failover logic.

/// Generates a robust RPC method wrapper with retry and failover, with automatic documentation.
///
/// # Variants
///
/// ## Basic (no arguments)
/// ```ignore
/// robust_rpc!(
///     fn method_name() -> ReturnType
/// );
/// ```
///
/// ## With argument documentation
/// ```ignore
/// robust_rpc!(
///     doc_args = [(block_id, "The block identifier to fetch.")]
///     fn method_name(block_id: BlockId) -> ReturnType
/// );
///
/// robust_rpc!(
///     doc_args = [
///         (address, "The address of the account."),
///         (keys, "A vector of storage keys to include in the proof.")
///     ]
///     fn method_name(address: Address, keys: Vec<StorageKey>) -> ReturnType
/// );
/// ```
///
/// ## With additional error documentation
/// ```ignore
/// robust_rpc!(
///     doc_include_error = ["[`Error::BlockNotFound`] - if the block is not available."]
///     doc_args = [(block_id, "The block identifier.")]
///     fn method_name(block_id: BlockId) -> ReturnType; or BlockNotFound
/// );
/// ```
///
/// ## Clone arguments (specify which args to clone)
/// ```ignore
/// robust_rpc!(
///     doc_args = [(tx, "The transaction request.")]
///     @clone [tx]
///     fn method_name(tx: TransactionRequest) -> ReturnType
/// );
/// ```
///
/// ## With generics
/// ```ignore
/// robust_rpc!(
///     doc_args = [(filter_id, "The filter ID.")]
///     fn method_name<T: SomeTrait>(filter_id: U256) -> Vec<T>
/// );
/// ```
///
/// ## With where clause
/// ```ignore
/// robust_rpc!(
///     doc_args = [(tx, "The transaction request.")]
///     @clone [tx]
///     fn method_name(tx: TransactionRequest) -> ReturnType
///     where [SomeType: SomeTrait]
/// );
/// ```
macro_rules! robust_rpc {
    // NOTE: Comments have been generated with the help of AI to help break down how macro works
    //
    // ============================================================================
    // Main pattern: Handles methods with optional documentation, generics, and where clauses
    // ============================================================================
    // This pattern is for methods that don't need argument cloning (simple Copy types or no args).
    //
    // Pattern breakdown:
    // - `doc_include_error`: Optional additional error documentation
    // - `doc_args`: Optional argument descriptions for documentation
    // - `doc_alias`: Optional doc alias for the method
    // - Generic parameters: `<T: Bound, U>` - supports multiple generics with optional bounds
    // - Arguments: Can be zero or more arguments
    // - `; or $err`: Optional - if present, unwraps Option and returns specific error variant
    // - `where` clause: Optional - supports multiple trait bounds
    (
        $(doc_include_error = [$($error_doc:tt)+])?
        $(doc_args = [$(($arg_name:ident, $arg_desc:literal)),* $(,)?])?
        $(doc_alias = $alias:tt)?
        fn $method:ident $(<$($generic:ident $(: $bound:path)?),+ $(,)?>)? ($($($arg:ident: $arg_ty:ty),+ $(,)?)?) -> $ret:ty $(; or $err:ident)?
        $(where $($where_ty:ty: $where_bound:path),+ $(,)?)?
    ) => {
        // Generate documentation for the wrapped method
        #[doc = concat!("This is a wrapper function for [`Provider::", stringify!($method), "`].")]

        // Include argument documentation if provided
        $($(
        ///
        /// # Arguments
        ///
        #[doc = concat!("* `", stringify!($arg_name), "` - ", $arg_desc)]
        )*)?

        // Standard error documentation that applies to all robust RPC methods
        ///
        /// # Errors
        ///
        /// * [`Error::RpcError`] - if no fallback providers succeeded; contains the last error returned
        ///   by the last provider attempted on the last retry.
        /// * [`Error::Timeout`] - if the overall operation timeout elapses (i.e. exceeds
        ///   `call_timeout`).

        // Include any additional error documentation specific to this method
        $(
        #[doc = $($error_doc)+]
        )?

        // Add doc alias if provided (useful for discoverability)
        $(
        #[doc(alias = $alias)]
        )?

        // Generate the actual method signature
        // - Preserves all generic parameters and their bounds
        // - Preserves all where clause constraints
        pub async fn $method $(<$($generic $(: $bound)?),+>)? (&self $(, $($arg: $arg_ty),+)?) -> Result<$ret, Error>
        $(where $($where_ty: $where_bound),+)?
        {
            // Call the underlying provider method with retry and failover logic
            // The closure captures arguments by move (works for Copy types)
            let result = self
                .try_operation_with_failover(
                    move |provider| async move {
                        // Call the provider method with turbofish syntax if generics are present
                        provider.$method $(::<$($generic),+>)? ($($($arg),+)?).await
                    },
                )
                .await;

            // Unwrap the result, either as a simple Result or with Option handling
            robust_rpc!(@unwrap result $(, $err)?)
        }
    };

    // ============================================================================
    // Clone pattern: For methods that need to clone arguments into the async closure
    // ============================================================================
    // This pattern is identical to the main pattern but includes an `@clone` list.
    // Use this when:
    // - Arguments are not Copy
    // - Arguments need to be moved into the async closure
    // - The closure may be called multiple times during retries
    //
    // Example: `@clone [method, params]` will generate `let method = method.clone();`
    // before the async move block, ensuring each retry gets a fresh clone.
    (
        $(#[doc = $doc:literal])*  // Optional custom documentation
        $(doc_include_error = [$($error_doc:tt)+])?
        $(doc_args = [$(($arg_name:ident, $arg_desc:literal)),* $(,)?])?
        $(doc_alias = $alias:tt)?
        @clone [$($clone_arg:ident),+ $(,)?]  // List of arguments to clone
        fn $method:ident $(<$($generic:ident $(: $bound:path)?),+ $(,)?>)? (
            $($arg:ident: $arg_ty:ty),+ $(,)?
        ) -> $ret:ty
        $(where $($where_ty:ty: $where_bound:path),+ $(,)?)?
        $(; or $err:ident)?
    ) => {
        // Include custom documentation if provided
        $(#[doc = $doc])*
        ///
        #[doc = concat!("This is a wrapper function for [`Provider::", stringify!($method), "`].")]

        // Generate standard documentation (same as main pattern)
        $($(
        ///
        /// # Arguments
        ///
        #[doc = concat!("* `", stringify!($arg_name), "` - ", $arg_desc)]
        )*)?
        ///
        /// # Errors
        ///
        /// * [`Error::RpcError`] - if no fallback providers succeeded; contains the last error returned
        ///   by the last provider attempted on the last retry.
        /// * [`Error::Timeout`] - if the overall operation timeout elapses (i.e. exceeds
        ///   `call_timeout`).
        $(
        #[doc = $($error_doc)+]
        )?
        $(
        #[doc(alias = $alias)]
        )?

        // Generate method signature (same as main pattern)
        pub async fn $method $(<$($generic $(: $bound)?),+>)? (&self, $($arg: $arg_ty),+) -> Result<$ret, Error>
        $(where $($where_ty: $where_bound),+)?
        {
            let result = self
                .try_operation_with_failover(
                    move |provider| {
                        // Clone each specified argument before moving into the async block
                        // This ensures the closure is FnMut-compatible and can be called multiple times
                        $(let $clone_arg = $clone_arg.clone();)+

                        async move {
                            // Use the cloned arguments in the provider call
                            provider.$method $(::<$($generic),+>)? ($($arg),+).await
                        }
                    },
                )
                .await;

            robust_rpc!(@unwrap result $(, $err)?)
        }
    };

    // ============================================================================
    // Internal helpers: Result unwrapping patterns
    // ============================================================================

    // Standard unwrap: Convert TransportError to Error
    (@unwrap $result:expr) => {
        $result.map_err(Error::from)
    };

    // Option unwrap: Used when "; or ErrorVariant" is specified
    // First unwraps the Result, then unwraps the Option, converting None to the specified Error variant
    // Example: `Result<Option<Block>, TransportError>` becomes `Result<Block, Error>`
    (@unwrap $result:expr, $err:ident) => {
        $result?.ok_or(Error::$err)
    };
}

/// Documentation string for `BlockNotFound` errors, for use in `robust_rpc!` macro calls.
///
/// Usage: `error = block_not_found_doc!()`
#[macro_export]
macro_rules! block_not_found_doc {
    () => { "* [`Error::BlockNotFound`] - if the block is not available. This is verified on Anvil, Reth, and Geth; other clients may surface this condition as [`Error::RpcError`]." };
}
