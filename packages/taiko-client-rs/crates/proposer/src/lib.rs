/// Entry point type for the proposer crate.
#[derive(Debug, Default, PartialEq, Eq)]
pub struct Proposer {}

impl Proposer {
    /// Creates a new proposer instance.
    pub fn new() -> Self {
        Self {}
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn proposer_initializes() {
        let proposer = Proposer::new();
        assert_eq!(proposer, Proposer::default());
    }
}
