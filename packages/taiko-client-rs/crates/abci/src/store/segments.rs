//! Append-only segment logs: one kind of per-height record, [`SEGMENT_HEIGHTS`] heights per file.
//!
//! The store keeps its per-height records from about the committed anchor's checkpoint s to the
//! head, which back-pressure keeps within U heights of s (1 ≤ U ≤ 262,144; the target deployment
//! uses U = 151,200). One file per height would be up to U + 1 files of each kind. Segments,
//! pruned whole below s (the validator records below the newest snapshot under s), are at most
//! U / [`SEGMENT_HEIGHTS`] + 3 files of each kind: 150 at U = 151,200.
//!
//! The records of the heights `f..f + SEGMENT_HEIGHTS`, `f` a multiple of [`SEGMENT_HEIGHTS`],
//! live in the file `<kind>-<f, 20 digits>.log`, in the order they were appended, each fsynced
//! once written:
//!
//! ```text
//! u64_be(height) ‖ u32_be(len) ‖ keccak256(body) ‖ u64_be(fnv1a64(those 44 bytes)) ‖ body
//! ```
//!
//! The header check covers the height, the length and the body hash, so a scan checks every
//! header without reading the bodies, and a header it accepts frames its record and names its
//! height exactly. The body hash is checked when the body is read. The header check is FNV-1a 64
//! ([`header_check`]) rather than keccak256 because every scan computes it for every header:
//! every step of it is a bijection of its state, so a change confined to one byte always changes
//! it, and other damage escapes it with odds of about 2^-64.
//!
//! - A crash can tear only the last append: a cut header, or an accepted header whose body runs
//!   past the end of the file. That torn tail is no record; the next append truncates it.
//! - A complete header that fails its check or names a height outside the segment is a damaged
//!   region, wherever it lies. The scan resumes at the next accepted header, so later records stay
//!   readable, and nothing truncates it. Its height cannot be known, so a read of any height the
//!   segment holds no valid record of is [`Record::Corrupt`], never [`Record::Missing`].
//! - A record whose header is accepted but whose body fails its hash is a corrupt record of that
//!   height: a read of it is [`Record::Corrupt`], and an append of its height supersedes it.

use std::{
    fs::{self, File, OpenOptions},
    io::{self, BufReader, Read, Seek, SeekFrom, Write},
    path::PathBuf,
};

use alloy_primitives::keccak256;

use super::{Record, StoreError, io_err, sync_dir};

/// The heights one segment file holds. It is also the validator-state snapshot interval: Commit
/// records the full validator state at every height divisible by it.
pub(crate) const SEGMENT_HEIGHTS: u64 = 1_024;

/// The bytes a record's header check covers: its height, its body length and its body hash.
const FRAME_LEN: usize = 8 + 4 + 32;

/// A record's header: the [`FRAME_LEN`] framed bytes and their [`header_check`].
const HEADER_LEN: u64 = FRAME_LEN as u64 + 8;

/// The append-only segment files of one kind of per-height record in a store directory.
#[derive(Clone, Debug)]
pub(crate) struct SegmentLog {
    /// The store directory holding the segments.
    dir: PathBuf,
    /// The kind: the file name prefix before `-<first height>.log`.
    kind: &'static str,
    /// Whether an append fsyncs its segment, and the directory when it creates the segment.
    durable: bool,
    /// The error of an append meeting a valid record of another body at its height.
    conflict: fn(u64) -> StoreError,
}

/// A record whose header [`scan`] accepted.
struct Entry {
    /// The height it records.
    height: u64,
    /// Where its body starts in the file.
    offset: u64,
    /// The body length.
    len: u32,
    /// The keccak256 its header records for the body.
    body_hash: [u8; 32],
}

impl Entry {
    /// Where the record ends.
    fn end(&self) -> u64 {
        self.offset + u64::from(self.len)
    }
}

/// What [`scan`] finds in a segment.
struct Scan {
    /// The records with accepted headers, in file order.
    entries: Vec<Entry>,
    /// Where the first damaged region, a complete header the scan rejected, starts.
    damaged: Option<u64>,
    /// Where the torn tail, a cut last record, starts.
    torn: Option<u64>,
    /// The file size.
    size: u64,
}

/// What [`frame`] finds at an offset.
enum Frame {
    /// An accepted header of a complete record.
    Record(Entry),
    /// A cut header, or an accepted header whose body runs past the end of the file.
    Cut,
    /// A header that fails its check or names a height outside the segment.
    Rejected,
}

impl SegmentLog {
    /// The segments of `kind` in `dir`.
    pub(crate) fn new(
        dir: PathBuf,
        kind: &'static str,
        durable: bool,
        conflict: fn(u64) -> StoreError,
    ) -> Self {
        Self { dir, kind, durable, conflict }
    }

    /// Durably appends `body` as the record of `height`.
    ///
    /// A valid record of `height` holding the same body makes this a no-op (a replay after a
    /// crash); one holding another body is the kind's conflict error and nothing is written. A
    /// torn tail is truncated before the record is written; a corrupt record of `height` and a
    /// damaged region are kept, the new record written after them (it supersedes the corrupt
    /// record). The record and the segment's size are fsynced before this returns, and so is the
    /// directory when the append creates the segment.
    pub(crate) fn append(&self, height: u64, body: &[u8]) -> Result<(), StoreError> {
        let first = first_height(height);
        let path = self.path(first);
        if u32::try_from(body.len()).is_err() {
            let error = io::Error::new(io::ErrorKind::InvalidInput, "body over 4 GiB");
            return Err(io_err("append", &path, error));
        }
        fs::create_dir_all(&self.dir).map_err(|source| io_err("create", &self.dir, source))?;
        let mut open = OpenOptions::new();
        open.read(true).write(true);
        let (mut file, created) = match open.open(&path) {
            Ok(file) => (file, false),
            Err(error) if error.kind() == io::ErrorKind::NotFound => {
                let file = open.create(true).open(&path);
                (file.map_err(|source| io_err("create", &path, source))?, true)
            }
            Err(source) => return Err(io_err("open", &path, source)),
        };
        let scan = scan(&file, first).map_err(|source| io_err("read", &path, source))?;
        let mut superseded = false;
        for entry in scan.entries.iter().filter(|entry| entry.height == height) {
            match read_body(&mut file, entry).map_err(|source| io_err("read", &path, source))? {
                Some(previous) if previous == body => return Ok(()),
                Some(_) => return Err((self.conflict)(height)),
                None => superseded = true,
            }
        }
        if superseded {
            tracing::warn!(height, file = %path.display(), "superseding a corrupt record");
        }
        if let Some(offset) = scan.damaged {
            tracing::warn!(height, file = %path.display(), offset, "appending past a damaged region");
        }
        let end = match scan.torn {
            Some(torn) => {
                tracing::warn!(
                    file = %path.display(),
                    from = torn,
                    bytes = scan.size - torn,
                    "truncating a torn segment tail"
                );
                file.set_len(torn).map_err(|source| io_err("truncate", &path, source))?;
                torn
            }
            None => scan.size,
        };
        file.seek(SeekFrom::Start(end))
            .and_then(|_| file.write_all(&encode(height, body)))
            .map_err(|source| io_err("write", &path, source))?;
        if self.durable {
            file.sync_all().map_err(|source| io_err("fsync", &path, source))?;
            if created {
                sync_dir(&self.dir)?;
            }
        }
        Ok(())
    }

    /// The body recorded for `height`: [`Record::Valid`] for the record of that height whose
    /// body matches its hash. [`Record::Corrupt`] when its records all fail their body hash, or
    /// when there is none and the segment holds a damaged region, whose height cannot be known;
    /// [`Record::Missing`] when an intact segment holds no record of it (a torn tail is none).
    /// Filesystem errors other than an absent segment are [`StoreError::Io`].
    pub(crate) fn read(&self, height: u64) -> Result<Record<Vec<u8>>, StoreError> {
        let first = first_height(height);
        let path = self.path(first);
        let mut file = match File::open(&path) {
            Ok(file) => file,
            Err(error) if error.kind() == io::ErrorKind::NotFound => return Ok(Record::Missing),
            Err(source) => return Err(io_err("open", &path, source)),
        };
        let scan = scan(&file, first).map_err(|source| io_err("read", &path, source))?;
        let mut corrupt = false;
        for entry in scan.entries.iter().filter(|entry| entry.height == height) {
            match read_body(&mut file, entry).map_err(|source| io_err("read", &path, source))? {
                Some(body) => return Ok(Record::Valid(body)),
                None => corrupt = true,
            }
        }
        Ok(match scan.damaged {
            _ if corrupt => Record::Corrupt("the body does not match its hash".into()),
            Some(offset) => Record::Corrupt(format!("its segment is damaged at byte {offset}")),
            None => Record::Missing,
        })
    }

    /// Deletes every segment whose heights all lie below `floor` and returns how many it
    /// removed; the segment holding `floor` and those above it are kept whole, so records below
    /// `floor` in it stay readable. Only canonical segment names of this kind are touched. A
    /// deletion lost to a crash leaves immutable records behind, which the next pruning removes,
    /// so the directory is not fsynced.
    pub(crate) fn prune_below(&self, floor: u64) -> Result<usize, StoreError> {
        let mut removed = 0;
        for first in self.segments()? {
            if floor.saturating_sub(first) < SEGMENT_HEIGHTS {
                break;
            }
            let path = self.path(first);
            match fs::remove_file(&path) {
                Ok(()) => removed += 1,
                Err(error) if error.kind() == io::ErrorKind::NotFound => {}
                Err(source) => return Err(io_err("remove", &path, source)),
            }
        }
        Ok(removed)
    }

    /// The heights of every record with an accepted header in every segment, ascending and
    /// without repeats, whether their bodies match their hashes or not. It reads every segment's
    /// headers, so it is for a kind recorded at few heights, such as the validator-state
    /// snapshots.
    pub(crate) fn heights(&self) -> Result<Vec<u64>, StoreError> {
        let mut heights = vec![];
        for (_, scan) in self.scan_all()? {
            heights.extend(scan.entries.iter().map(|entry| entry.height));
        }
        heights.sort_unstable();
        heights.dedup();
        Ok(heights)
    }

    /// The first damaged region of a segment holding heights at or below `height`, as the first
    /// height of its segment and its offset there: a record of any of those heights may lie in
    /// it.
    pub(crate) fn damaged_at_or_below(
        &self,
        height: u64,
    ) -> Result<Option<(u64, u64)>, StoreError> {
        Ok(self
            .scan_all()?
            .into_iter()
            .filter(|(first, _)| *first <= height)
            .find_map(|(first, scan)| scan.damaged.map(|offset| (first, offset))))
    }

    /// The scan of every segment, by first height, ascending.
    fn scan_all(&self) -> Result<Vec<(u64, Scan)>, StoreError> {
        let mut scans = vec![];
        for first in self.segments()? {
            let path = self.path(first);
            match File::open(&path).and_then(|file| scan(&file, first)) {
                Ok(scan) => scans.push((first, scan)),
                Err(error) if error.kind() == io::ErrorKind::NotFound => {}
                Err(source) => return Err(io_err("read", &path, source)),
            }
        }
        Ok(scans)
    }

    /// The first heights of this kind's canonical segment names in the directory, ascending.
    fn segments(&self) -> Result<Vec<u64>, StoreError> {
        let entries = match fs::read_dir(&self.dir) {
            Ok(entries) => entries,
            Err(error) if error.kind() == io::ErrorKind::NotFound => return Ok(vec![]),
            Err(source) => return Err(io_err("list", &self.dir, source)),
        };
        let mut firsts = vec![];
        for entry in entries {
            let entry = entry.map_err(|source| io_err("list", &self.dir, source))?;
            firsts.extend(entry.file_name().to_str().and_then(|name| self.first_of(name)));
        }
        firsts.sort_unstable();
        Ok(firsts)
    }

    /// The segment file whose heights start at `first`.
    fn path(&self, first: u64) -> PathBuf {
        self.dir.join(format!("{}-{first:020}.log", self.kind))
    }

    /// The first height a canonical segment name of this kind starts at: 20 decimal digits of a
    /// multiple of [`SEGMENT_HEIGHTS`].
    fn first_of(&self, name: &str) -> Option<u64> {
        let digits = name.strip_prefix(self.kind)?.strip_prefix('-')?.strip_suffix(".log")?;
        if digits.len() != 20 || !digits.bytes().all(|b| b.is_ascii_digit()) {
            return None;
        }
        digits.parse::<u64>().ok().filter(|first| first % SEGMENT_HEIGHTS == 0)
    }
}

/// The first height of the segment holding `height`.
fn first_height(height: u64) -> u64 {
    height - height % SEGMENT_HEIGHTS
}

/// The record bytes of `body` at `height`.
fn encode(height: u64, body: &[u8]) -> Vec<u8> {
    encode_with(height, body, keccak256(body).0)
}

/// The record bytes of `body` at `height` under the body hash `body_hash`.
fn encode_with(height: u64, body: &[u8], body_hash: [u8; 32]) -> Vec<u8> {
    let len = u32::try_from(body.len()).expect("the caller bounds the body");
    let mut record = Vec::with_capacity(HEADER_LEN as usize + body.len());
    record.extend_from_slice(&height.to_be_bytes());
    record.extend_from_slice(&len.to_be_bytes());
    record.extend_from_slice(&body_hash);
    let check = header_check(record.first_chunk().expect("the framed bytes"));
    record.extend_from_slice(&check.to_be_bytes());
    record.extend_from_slice(body);
    record
}

/// FNV-1a 64 of a header's framed bytes.
fn header_check(framed: &[u8; FRAME_LEN]) -> u64 {
    framed.iter().fold(0xcbf2_9ce4_8422_2325, |check, byte| {
        (check ^ u64::from(*byte)).wrapping_mul(0x0000_0100_0000_01b3)
    })
}

/// Reads the header at the start of `bytes`, found at `offset` of a segment of `size` bytes whose
/// heights start at `first`.
fn frame(bytes: &[u8], offset: u64, first: u64, size: u64) -> Frame {
    let Some((framed, rest)) = bytes.split_first_chunk::<FRAME_LEN>() else { return Frame::Cut };
    let Some(check) = rest.first_chunk::<8>() else { return Frame::Cut };
    let (height, rest) = framed.split_first_chunk::<8>().expect("eight bytes");
    let (len, body_hash) = rest.split_first_chunk::<4>().expect("four bytes");
    let (height, len) = (u64::from_be_bytes(*height), u32::from_be_bytes(*len));
    if height.checked_sub(first).is_none_or(|step| step >= SEGMENT_HEIGHTS) ||
        header_check(framed) != u64::from_be_bytes(*check)
    {
        return Frame::Rejected;
    }
    let entry = Entry {
        height,
        offset: offset + HEADER_LEN,
        len,
        body_hash: body_hash.try_into().expect("32 bytes"),
    };
    if entry.end() > size { Frame::Cut } else { Frame::Record(entry) }
}

/// Scans the segment `file`, whose heights start at `first`: walks the records from accepted
/// header to accepted header, and past a rejected header resumes at the next accepted one
/// ([`resume`]). A segment that is no regular file is an error.
fn scan(file: &File, first: u64) -> io::Result<Scan> {
    let metadata = file.metadata()?;
    if !metadata.is_file() {
        return Err(io::Error::other("the segment is not a regular file"));
    }
    let size = metadata.len();
    let mut scan = Scan { entries: vec![], damaged: None, torn: None, size };
    let mut reader = BufReader::new(file);
    reader.seek(SeekFrom::Start(0))?;
    let mut offset = 0;
    while offset < size {
        let mut header = [0; HEADER_LEN as usize];
        let header = &mut header[..(size - offset).min(HEADER_LEN) as usize];
        reader.read_exact(header)?;
        match frame(header, offset, first, size) {
            Frame::Record(entry) => {
                reader.seek_relative(i64::from(entry.len))?;
                offset = entry.end();
                scan.entries.push(entry);
            }
            // An accepted header's length is exact: nothing can follow a cut record.
            Frame::Cut => {
                scan.torn = Some(offset);
                break;
            }
            Frame::Rejected => {
                scan.damaged.get_or_insert(offset);
                let Some(next) = resume(file, first, offset + 1, size)? else { break };
                reader.seek(SeekFrom::Start(next))?;
                offset = next;
            }
        }
    }
    Ok(scan)
}

/// The offset of the first accepted header at or after `from` in a segment of `size` bytes
/// whose heights start at `first`, read in windows of 64 KiB.
fn resume(mut file: &File, first: u64, from: u64, size: u64) -> io::Result<Option<u64>> {
    const WINDOW: u64 = 1 << 16;
    let mut start = from;
    while size.saturating_sub(start) >= HEADER_LEN {
        let mut window = vec![0; (size - start).min(WINDOW + HEADER_LEN - 1) as usize];
        file.seek(SeekFrom::Start(start))?;
        file.read_exact(&mut window)?;
        let starts = window.len() - HEADER_LEN as usize + 1;
        for at in 0..starts {
            let offset = start + at as u64;
            if !matches!(frame(&window[at..], offset, first, size), Frame::Rejected) {
                return Ok(Some(offset));
            }
        }
        start += starts as u64;
    }
    Ok(None)
}

/// The body of `entry`, or `None` when it does not match the hash its header records.
fn read_body(file: &mut File, entry: &Entry) -> io::Result<Option<Vec<u8>>> {
    let mut body = vec![0; entry.len as usize];
    file.seek(SeekFrom::Start(entry.offset))?;
    file.read_exact(&mut body)?;
    Ok((keccak256(&body).0 == entry.body_hash).then_some(body))
}

#[cfg(test)]
impl SegmentLog {
    /// Deletes every record of `height` from its intact segment, as if it had never been
    /// written; returns the body of the last one.
    pub(crate) fn remove(&self, height: u64) -> Option<Vec<u8>> {
        let mut removed = None;
        self.rewrite(height, |records| {
            records.retain(|(recorded, body, _)| {
                let keep = *recorded != height;
                if !keep {
                    removed = Some(body.clone());
                }
                keep
            })
        });
        removed
    }

    /// Replaces the body of every record of `height` with `body` under matching hashes:
    /// coherent damage no hash catches.
    pub(crate) fn replace(&self, height: u64, body: &[u8]) {
        self.rewrite(height, |records| {
            for (_, old, hash) in records.iter_mut().filter(|(recorded, ..)| *recorded == height) {
                *old = body.to_vec();
                *hash = keccak256(body).0;
            }
        });
    }

    /// Flips the last body byte of every record of `height`, so that none matches its hash.
    pub(crate) fn corrupt(&self, height: u64) {
        let path = self.path(first_height(height));
        let file = File::open(&path).expect("the segment exists");
        let scan = scan(&file, first_height(height)).unwrap();
        let mut bytes = fs::read(&path).unwrap();
        for entry in scan.entries.iter().filter(|entry| entry.height == height) {
            assert!(entry.len > 0, "an empty body cannot be corrupted");
            bytes[entry.end() as usize - 1] ^= 1;
        }
        fs::write(&path, bytes).unwrap();
    }

    /// Rewrites `height`'s intact segment from its records (height, body and recorded body
    /// hash), edited by `edit`.
    fn rewrite(&self, height: u64, edit: impl FnOnce(&mut Vec<(u64, Vec<u8>, [u8; 32])>)) {
        let first = first_height(height);
        let path = self.path(first);
        let mut file = File::open(&path).expect("the segment exists");
        let scan = scan(&file, first).unwrap();
        assert!(scan.damaged.is_none() && scan.torn.is_none(), "an intact segment");
        let mut records = vec![];
        for entry in &scan.entries {
            let mut body = vec![0; entry.len as usize];
            file.seek(SeekFrom::Start(entry.offset)).unwrap();
            file.read_exact(&mut body).unwrap();
            records.push((entry.height, body, entry.body_hash));
        }
        edit(&mut records);
        let bytes =
            records.iter().flat_map(|(height, body, hash)| encode_with(*height, body, *hash));
        fs::write(&path, bytes.collect::<Vec<_>>()).unwrap();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A durable log of a test kind in `dir`, whose conflicts are Comet-hash conflicts.
    fn log(dir: &std::path::Path) -> SegmentLog {
        SegmentLog::new(dir.into(), "test", true, StoreError::CometConflict)
    }

    /// The file holding the segment that starts at `first`.
    fn segment(dir: &std::path::Path, first: u64) -> PathBuf {
        dir.join(format!("test-{first:020}.log"))
    }

    /// The record bytes of `body` at `height`, built from the documented layout.
    fn record(height: u64, body: &[u8]) -> Vec<u8> {
        let len = u32::try_from(body.len()).unwrap();
        let framed =
            [&height.to_be_bytes()[..], &len.to_be_bytes(), keccak256(body).as_slice()].concat();
        let check = header_check(framed.as_slice().try_into().unwrap());
        [framed.as_slice(), &check.to_be_bytes(), body].concat()
    }

    /// The header check is FNV-1a 64: its published test vectors, and a change of any single
    /// byte of a header to any other value changes it.
    #[test]
    fn header_check_is_fnv1a64_and_catches_every_one_byte_change() {
        let fnv = |bytes: &[u8]| {
            bytes.iter().fold(0xcbf2_9ce4_8422_2325_u64, |check, byte| {
                (check ^ u64::from(*byte)).wrapping_mul(0x0000_0100_0000_01b3)
            })
        };
        assert_eq!(fnv(b""), 0xcbf2_9ce4_8422_2325);
        assert_eq!(fnv(b"a"), 0xaf63_dc4c_8601_ec8c);
        assert_eq!(fnv(b"foobar"), 0x8594_4171_f739_67e8);
        let framed: [u8; FRAME_LEN] = record(7, b"seven")[..FRAME_LEN].try_into().unwrap();
        assert_eq!(header_check(&framed), fnv(&framed));
        for at in 0..FRAME_LEN {
            for value in 0..=u8::MAX {
                let mut changed = framed;
                changed[at] = value;
                assert_eq!(header_check(&changed) == header_check(&framed), value == framed[at]);
            }
        }
    }

    /// Bodies appended in any order, across two segments and an empty one included, read back
    /// by height; a height never appended and a segment never created read as missing. A segment
    /// is the concatenation of its records in append order.
    #[test]
    fn segment_append_read_round_trip() {
        let dir = tempfile::tempdir().unwrap();
        let log = log(dir.path());
        assert_eq!(log.read(5).unwrap(), Record::Missing, "no directory yet");
        let appended: [(u64, &[u8]); 5] = [
            (5, b"five"),
            (3, b""),
            (SEGMENT_HEIGHTS - 1, b"last of the first"),
            (SEGMENT_HEIGHTS, b"first of the second"),
            (0, &[0xab; 300]),
        ];
        for (height, body) in appended {
            log.append(height, body).unwrap();
        }
        for (height, body) in appended {
            assert_eq!(log.read(height).unwrap(), Record::Valid(body.to_vec()), "{height}");
        }
        for absent in [1, 4, SEGMENT_HEIGHTS + 1, 5 * SEGMENT_HEIGHTS, u64::MAX] {
            assert_eq!(log.read(absent).unwrap(), Record::Missing, "{absent}");
        }
        let first =
            [(5, b"five".as_slice()), (3, b""), (SEGMENT_HEIGHTS - 1, b"last of the first")]
                .into_iter()
                .chain([(0, [0xab; 300].as_slice())])
                .flat_map(|(height, body)| record(height, body))
                .collect::<Vec<_>>();
        assert_eq!(fs::read(segment(dir.path(), 0)).unwrap(), first);
        assert_eq!(
            fs::read(segment(dir.path(), SEGMENT_HEIGHTS)).unwrap(),
            record(SEGMENT_HEIGHTS, b"first of the second")
        );
        assert_eq!(log.heights().unwrap(), [0, 3, 5, SEGMENT_HEIGHTS - 1, SEGMENT_HEIGHTS]);
        assert_eq!(log.damaged_at_or_below(u64::MAX).unwrap(), None);
        assert_eq!(fs::read_dir(dir.path()).unwrap().count(), 2);

        // A segment that is no regular file fails every access instead of reading as empty.
        fs::create_dir(segment(dir.path(), 2 * SEGMENT_HEIGHTS)).unwrap();
        let height = 2 * SEGMENT_HEIGHTS + 1;
        assert!(matches!(log.read(height), Err(StoreError::Io { .. })));
        assert!(matches!(log.append(height, b"x"), Err(StoreError::Io { .. })));
        assert!(matches!(log.heights(), Err(StoreError::Io { .. })));
    }

    /// Appending a height's body again changes nothing; another body for it conflicts and is
    /// not written. A record whose body fails its hash is no body: reads find it corrupt, and an
    /// append of its height supersedes it without touching the other records.
    #[test]
    fn equal_reappend_is_a_noop_and_a_different_body_conflicts() {
        let dir = tempfile::tempdir().unwrap();
        let log = log(dir.path());
        log.append(7, b"seven").unwrap();
        log.append(8, b"eight").unwrap();
        let path = segment(dir.path(), 0);
        let written = fs::read(&path).unwrap();

        log.append(7, b"seven").unwrap();
        let reopened = SegmentLog::new(dir.path().into(), "test", true, StoreError::CometConflict);
        reopened.append(8, b"eight").unwrap();
        assert_eq!(fs::read(&path).unwrap(), written, "equal re-appends write nothing");
        for (height, other) in [(7, b"SEVEN".as_slice()), (8, b"")] {
            let error = reopened.append(height, other).unwrap_err();
            assert!(matches!(error, StoreError::CometConflict(h) if h == height), "{error:?}");
        }
        assert_eq!(fs::read(&path).unwrap(), written, "a conflict writes nothing");

        log.corrupt(8);
        let corrupted = fs::read(&path).unwrap();
        assert!(matches!(log.read(8).unwrap(), Record::Corrupt(_)));
        assert_eq!(log.read(7).unwrap(), Record::Valid(b"seven".to_vec()));
        assert_eq!(log.read(9).unwrap(), Record::Missing, "the corrupt record is of height 8");
        log.append(8, b"EIGHT").unwrap();
        assert_eq!(log.read(8).unwrap(), Record::Valid(b"EIGHT".to_vec()));
        assert_eq!(fs::read(&path).unwrap(), [corrupted, record(8, b"EIGHT")].concat());
        log.append(8, b"EIGHT").unwrap();
        assert!(matches!(log.append(8, b"eight"), Err(StoreError::CometConflict(8))));
    }

    /// A crash can tear only the last append: a cut header or a cut body. No read finds the
    /// torn record, and the next append truncates the tail before writing, leaving the bytes an
    /// uninterrupted append writes; the torn height can be appended again.
    #[test]
    fn torn_tail_is_truncated() {
        let dir = tempfile::tempdir().unwrap();
        let log = log(dir.path());
        let path = segment(dir.path(), 0);
        log.append(1, b"one").unwrap();
        log.append(2, b"two").unwrap();
        let kept = fs::read(&path).unwrap();
        log.append(3, b"three").unwrap();
        let complete = fs::read(&path).unwrap();
        for cut in 1..record(3, b"three").len() {
            fs::write(&path, &complete[..kept.len() + cut]).unwrap();
            assert_eq!(log.read(3).unwrap(), Record::Missing, "cut at {cut}");
            assert_eq!(log.read(4).unwrap(), Record::Missing, "cut at {cut}");
            assert_eq!(log.read(2).unwrap(), Record::Valid(b"two".to_vec()));
            assert_eq!(log.heights().unwrap(), [1, 2]);
            log.append(3, b"three").unwrap();
            assert_eq!(fs::read(&path).unwrap(), complete, "cut at {cut}");
        }
        fs::write(&path, &complete[..kept.len() + 10]).unwrap();
        log.append(4, b"four").unwrap();
        assert_eq!(fs::read(&path).unwrap(), [kept, record(4, b"four")].concat());
    }

    /// A header whose height byte flipped fails its check: the record is never read as the
    /// height it now names, and its own height reads as corrupt, not as another height's value
    /// or as absent.
    #[test]
    fn flipped_header_height_is_corruption() {
        let dir = tempfile::tempdir().unwrap();
        let log = log(dir.path());
        let path = segment(dir.path(), 0);
        log.append(7, b"seven").unwrap();
        log.append(6, b"six").unwrap();
        let mut bytes = fs::read(&path).unwrap();
        bytes[7] ^= 1; // 7 becomes 6
        fs::write(&path, &bytes).unwrap();
        assert_eq!(log.read(6).unwrap(), Record::Valid(b"six".to_vec()));
        assert!(matches!(log.read(7).unwrap(), Record::Corrupt(_)));
        assert!(matches!(log.read(8).unwrap(), Record::Corrupt(_)), "it may hold any height");
        assert_eq!(log.heights().unwrap(), [6]);
        assert_eq!(log.damaged_at_or_below(0).unwrap(), Some((0, 0)));
    }

    /// A rejected header with records after it is a damaged region, whatever damaged it: a
    /// flipped length, a height outside the segment or bytes zeroed in place. The records
    /// after it stay readable, every height the segment holds no valid record of reads as
    /// corrupt, and an append keeps the damaged bytes and writes after them.
    #[test]
    fn corrupt_middle_record_is_corruption_and_later_records_survive() {
        /// Damages the record at an offset of a segment's bytes.
        type Damage = fn(&mut [u8], usize);
        let outside = record(SEGMENT_HEIGHTS + 2, b"two");
        let damage: [(&str, Damage); 3] = [
            ("length", |bytes, at| bytes[at + 11] ^= 0x10),
            ("height", |bytes, at| bytes[at + 6] ^= 0x04),
            ("zeroed", |bytes, at| bytes[at..at + HEADER_LEN as usize].fill(0)),
        ];
        for (name, damage) in damage {
            let dir = tempfile::tempdir().unwrap();
            let log = log(dir.path());
            let path = segment(dir.path(), 0);
            for (height, body) in [(1, b"one".as_slice()), (2, b"two"), (3, b"three"), (4, b"four")]
            {
                log.append(height, body).unwrap();
            }
            let mut bytes = fs::read(&path).unwrap();
            let at = record(1, b"one").len();
            damage(&mut bytes, at);
            fs::write(&path, &bytes).unwrap();

            assert_eq!(log.read(1).unwrap(), Record::Valid(b"one".to_vec()), "{name}");
            assert!(matches!(log.read(2).unwrap(), Record::Corrupt(_)), "{name}");
            assert_eq!(log.read(3).unwrap(), Record::Valid(b"three".to_vec()), "{name}");
            assert_eq!(log.read(4).unwrap(), Record::Valid(b"four".to_vec()), "{name}");
            assert!(matches!(log.read(5).unwrap(), Record::Corrupt(_)), "{name}: never absent");
            assert_eq!(log.heights().unwrap(), [1, 3, 4], "{name}");

            log.append(5, b"five").unwrap();
            assert_eq!(fs::read(&path).unwrap(), [bytes.clone(), record(5, b"five")].concat());
            assert_eq!(log.read(5).unwrap(), Record::Valid(b"five".to_vec()), "{name}");
            assert_eq!(log.read(4).unwrap(), Record::Valid(b"four".to_vec()), "{name}");
            assert!(matches!(log.read(2).unwrap(), Record::Corrupt(_)), "{name}");
        }

        // A last header that names a height outside the segment, or one zeroed in place, is no
        // cut record: it is kept, and later appends are written after it.
        for tail in [outside, vec![0; 100]] {
            let dir = tempfile::tempdir().unwrap();
            let log = log(dir.path());
            let path = segment(dir.path(), 0);
            log.append(1, b"one").unwrap();
            let bytes = [fs::read(&path).unwrap(), tail].concat();
            fs::write(&path, &bytes).unwrap();
            assert!(matches!(log.read(2).unwrap(), Record::Corrupt(_)));
            log.append(2, b"two").unwrap();
            assert_eq!(fs::read(&path).unwrap(), [bytes, record(2, b"two")].concat());
            assert_eq!(log.read(2).unwrap(), Record::Valid(b"two".to_vec()));
            assert_eq!(log.read(1).unwrap(), Record::Valid(b"one".to_vec()));
        }
    }

    /// Pruning deletes the segments wholly below the floor, never the one holding it, and
    /// touches no other name.
    #[test]
    fn prune_deletes_whole_segments_below_the_floor() {
        let dir = tempfile::tempdir().unwrap();
        let log = log(dir.path());
        for height in (0..4).map(|k| k * SEGMENT_HEIGHTS + 3) {
            log.append(height, b"x").unwrap();
        }
        let unrelated =
            ["test-0.log", "test-00000000000000000001.log", "other-00000000000000000000.log"];
        for name in unrelated {
            fs::write(dir.path().join(name), b"kept").unwrap();
        }
        assert_eq!(log.prune_below(2 * SEGMENT_HEIGHTS - 1).unwrap(), 1);
        assert_eq!(log.read(3).unwrap(), Record::Missing);
        assert_eq!(log.read(SEGMENT_HEIGHTS + 3).unwrap(), Record::Valid(b"x".to_vec()));
        assert_eq!(log.prune_below(2 * SEGMENT_HEIGHTS).unwrap(), 1);
        assert_eq!(log.prune_below(2 * SEGMENT_HEIGHTS).unwrap(), 0, "pruning again finds none");
        assert_eq!(log.heights().unwrap(), [2 * SEGMENT_HEIGHTS + 3, 3 * SEGMENT_HEIGHTS + 3]);
        assert_eq!(log.prune_below(u64::MAX).unwrap(), 2);
        for name in unrelated {
            assert!(dir.path().join(name).exists(), "{name} is no segment of this kind");
        }
    }
}
