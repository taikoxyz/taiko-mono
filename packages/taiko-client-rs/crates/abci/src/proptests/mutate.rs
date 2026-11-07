//! Mutations of valid encodings: byte-level edits (bit flips, truncations, insertions, removals,
//! duplicated ranges, a replaced first byte) and RLP-aware rewrites of one item (a non-canonical
//! header, or a zero-padded string or an extra list element).

use alloy_rlp::PayloadView;
use proptest::{collection::vec, prelude::*, sample::Index};

/// A rewrite of one RLP item.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(super) enum Reframe {
    /// The same payload under a non-canonical header: the long length form for a payload under
    /// 56 bytes, a zero-padded length otherwise.
    LongLength,
    /// A single byte below `0x80` as a one-byte string (`0x81 b`) instead of itself; any other item
    /// as [`Reframe::LongLength`].
    SingleByte,
    /// A changed value under a canonical header: a string with a leading zero byte, or a list
    /// with an extra empty string at its end.
    Pad,
}

/// One edit of an encoding. Positions are [`Index`]es, resolved against the length at the time
/// the edit applies.
#[derive(Clone, Debug)]
pub(super) enum Mutation {
    /// Flips one bit (`0..8`) of the byte at a position.
    FlipBit(Index, u8),
    /// Keeps only the bytes before a position.
    Truncate(Index),
    /// Inserts bytes before a position (or at the end).
    Insert(Index, Vec<u8>),
    /// Removes up to the given number of bytes from a position.
    Remove(Index, usize),
    /// Repeats up to the given number of bytes from a position right after themselves.
    Duplicate(Index, usize),
    /// Replaces the first byte (an envelope's version byte, or an item's first header byte).
    FirstByte(u8),
    /// Rewrites the RLP item at a pre-order position; leaves bytes that are not one RLP item
    /// unchanged.
    Reframe(Index, Reframe),
}

/// An arbitrary [`Mutation`]; RLP-aware rewrites and bit flips are the most frequent.
pub(super) fn mutation() -> impl Strategy<Value = Mutation> {
    let reframe =
        prop_oneof![Just(Reframe::LongLength), Just(Reframe::SingleByte), Just(Reframe::Pad)];
    prop_oneof![
        3 => (any::<Index>(), 0u8..8).prop_map(|(at, bit)| Mutation::FlipBit(at, bit)),
        1 => any::<Index>().prop_map(Mutation::Truncate),
        1 => (any::<Index>(), vec(any::<u8>(), 1..=8)).prop_map(|(at, b)| Mutation::Insert(at, b)),
        1 => (any::<Index>(), 1usize..=64).prop_map(|(at, len)| Mutation::Remove(at, len)),
        1 => (any::<Index>(), 1usize..=64).prop_map(|(at, len)| Mutation::Duplicate(at, len)),
        1 => any::<u8>().prop_map(Mutation::FirstByte),
        4 => (any::<Index>(), reframe).prop_map(|(item, form)| Mutation::Reframe(item, form)),
    ]
}

/// `encoding` after each of `mutations` in turn. `rlp_start` is where the RLP item starts (1
/// after an envelope's version byte, else 0).
pub(super) fn mutate(encoding: &[u8], mutations: &[Mutation], rlp_start: usize) -> Vec<u8> {
    let mut bytes = encoding.to_vec();
    for mutation in mutations {
        mutation.apply(&mut bytes, rlp_start);
    }
    bytes
}

impl Mutation {
    /// Applies this edit to `bytes`, whose RLP item starts at `rlp_start`.
    fn apply(&self, bytes: &mut Vec<u8>, rlp_start: usize) {
        let len = bytes.len();
        match self {
            Self::Insert(at, inserted) => {
                let at = at.index(len + 1);
                bytes.splice(at..at, inserted.iter().copied());
            }
            Self::Reframe(item, form) => {
                let Some(tree) = bytes.get(rlp_start..).and_then(Item::parse) else { return };
                let mut out = bytes[..rlp_start].to_vec();
                tree.encode(item.index(tree.count()), *form, &mut 0, &mut out);
                *bytes = out;
            }
            _ if len == 0 => {}
            Self::FlipBit(at, bit) => bytes[at.index(len)] ^= 1 << *bit,
            Self::Truncate(at) => bytes.truncate(at.index(len)),
            Self::Remove(at, count) => {
                let at = at.index(len);
                bytes.drain(at..len.min(at + *count));
            }
            Self::Duplicate(at, count) => {
                let at = at.index(len);
                let end = len.min(at + *count);
                let copy = bytes[at..end].to_vec();
                bytes.splice(end..end, copy);
            }
            Self::FirstByte(byte) => bytes[0] = *byte,
        }
    }
}

/// One RLP item: a byte string or a list of items.
#[derive(Clone, Debug, PartialEq, Eq)]
enum Item {
    /// A byte string's payload.
    String(Vec<u8>),
    /// A list's items, in order.
    List(Vec<Item>),
}

impl Item {
    /// Parses `bytes` as exactly one canonically framed RLP item.
    fn parse(bytes: &[u8]) -> Option<Self> {
        let mut buf = bytes;
        let item = match alloy_rlp::Header::decode_raw(&mut buf).ok()? {
            PayloadView::String(payload) => Self::String(payload.to_vec()),
            PayloadView::List(items) => {
                Self::List(items.into_iter().map(Self::parse).collect::<Option<_>>()?)
            }
        };
        buf.is_empty().then_some(item)
    }

    /// The number of items in this tree: itself and every descendant.
    fn count(&self) -> usize {
        match self {
            Self::String(_) => 1,
            Self::List(items) => 1 + items.iter().map(Self::count).sum::<usize>(),
        }
    }

    /// Appends this item's canonical encoding to `out`, except that the item at pre-order
    /// position `target` (counting from `position`, which advances past every encoded item) is
    /// rewritten as `form` says.
    fn encode(&self, target: usize, form: Reframe, position: &mut usize, out: &mut Vec<u8>) {
        let rewrite = (*position == target).then_some(form);
        *position += 1;
        match self {
            Self::String(payload) => match rewrite {
                None => out.extend(alloy_rlp::encode(payload.as_slice())),
                Some(Reframe::Pad) => {
                    out.extend(alloy_rlp::encode([&[0], payload.as_slice()].concat().as_slice()));
                }
                Some(Reframe::SingleByte) if payload.len() == 1 && payload[0] < 0x80 => {
                    out.extend([0x81, payload[0]]);
                }
                Some(Reframe::SingleByte | Reframe::LongLength) => {
                    long_header(false, payload.len(), out);
                    out.extend_from_slice(payload);
                }
            },
            Self::List(items) => {
                let mut payload = Vec::new();
                for item in items {
                    item.encode(target, form, position, &mut payload);
                }
                match rewrite {
                    None => {
                        alloy_rlp::Header { list: true, payload_length: payload.len() }.encode(out)
                    }
                    Some(Reframe::Pad) => {
                        payload.push(alloy_rlp::EMPTY_STRING_CODE);
                        alloy_rlp::Header { list: true, payload_length: payload.len() }.encode(out);
                    }
                    Some(Reframe::SingleByte | Reframe::LongLength) => {
                        long_header(true, payload.len(), out);
                    }
                }
                out.extend(payload);
            }
        }
    }
}

/// Appends a non-canonical header for a payload of `len` bytes: the long form with a one-byte
/// length below 56, otherwise the long form with a zero byte before the length.
fn long_header(list: bool, len: usize, out: &mut Vec<u8>) {
    let length = len.to_be_bytes();
    let significant = &length[length.iter().take_while(|byte| **byte == 0).count()..];
    let length = if len < 56 { vec![len as u8] } else { [&[0][..], significant].concat() };
    out.push(if list { 0xf7 } else { 0xb7 } + length.len() as u8);
    out.extend(length);
}

/// Each rewrite produces the intended bytes, and a position past the last item changes nothing.
#[test]
fn reframes_produce_the_intended_encodings() {
    // `[0x05, "ab"]`: the list is item 0, the single byte item 1, the string item 2.
    let list = super::strategies::rlp_list(&[vec![0x05], alloy_rlp::encode(&b"ab"[..])]);
    assert_eq!(list, [0xc4, 0x05, 0x82, b'a', b'b']);
    let reframe = |target, form| {
        let mut out = Vec::new();
        Item::parse(&list).unwrap().encode(target, form, &mut 0, &mut out);
        out
    };
    assert_eq!(reframe(9, Reframe::Pad), list, "no item at position 9");
    assert_eq!(reframe(0, Reframe::LongLength), [0xf8, 0x04, 0x05, 0x82, b'a', b'b']);
    assert_eq!(reframe(0, Reframe::Pad), [0xc5, 0x05, 0x82, b'a', b'b', 0x80]);
    assert_eq!(reframe(1, Reframe::SingleByte), [0xc5, 0x81, 0x05, 0x82, b'a', b'b']);
    assert_eq!(reframe(1, Reframe::Pad), [0xc6, 0x82, 0x00, 0x05, 0x82, b'a', b'b']);
    assert_eq!(reframe(2, Reframe::SingleByte), [0xc5, 0x05, 0xb8, 0x02, b'a', b'b']);
    // A 56-byte payload already uses the long form, so the rewrite zero-pads its length.
    let long = alloy_rlp::encode(&[7u8; 56][..]);
    let mut out = Vec::new();
    Item::parse(&long).unwrap().encode(0, Reframe::LongLength, &mut 0, &mut out);
    assert_eq!(out[..3], [0xb9, 0x00, 56]);
    assert_eq!(out[3..], [7; 56]);
}
