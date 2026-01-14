#[test]
fn secondary_l2_env_is_configured() {
    let l2_http_1 = std::env::var("L2_HTTP_1").expect("L2_HTTP_1 env var should be set");
    let l2_ws_1 = std::env::var("L2_WS_1").expect("L2_WS_1 env var should be set");
    let l2_auth_1 = std::env::var("L2_AUTH_1").expect("L2_AUTH_1 env var should be set");

    assert!(l2_http_1.contains("38545"), "L2_HTTP_1 should target port 38545");
    assert!(l2_ws_1.contains("38546"), "L2_WS_1 should target port 38546");
    assert!(l2_auth_1.contains("38551"), "L2_AUTH_1 should target port 38551");
}
