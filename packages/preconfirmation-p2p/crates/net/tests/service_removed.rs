use std::path::Path;

#[test]
fn service_crate_removed() {
    let net_dir = Path::new(env!("CARGO_MANIFEST_DIR"));
    let service_dir = net_dir.join("..").join("service");
    assert!(!service_dir.exists(), "service crate should be removed: {}", service_dir.display());
}
