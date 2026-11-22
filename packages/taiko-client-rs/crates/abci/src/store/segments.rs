//! Append-only segment logs: one kind of per-height record, [`SEGMENT_HEIGHTS`] heights per file.
//!
//! The store keeps its per-height records from about the committed anchor's checkpoint s to the
//! head, which back-pressure keeps within U heights of s (1 ≤ U ≤ 262,144; the target deployment
//! uses U = 151,200). One file per height would be up to U + 1 files of each kind. Segments,
//! pruned whole below s (the validator records below the newest snapshot under s), are at most
//! U / [`SEGMENT_HEIGHTS`] + 3 files of each kind: 150 at U = 151,200.
//!
//! The records of the heights `f..f + SEGMENT_HEIGHTS`, `f` a multiple of [`SEGMENT_HEIGHTS`],
//! live in the file `<kind>-<f, 20 digits>.log`, in the order they were appended, each
//! `u64_be(height) ‖ u32_be(len) ‖ keccak256(body) ‖ body` and fsynced once written. A crash
//! during an append leaves a torn tail: the bytes after the last complete record (a cut header,
//! a body shorter than its length, or a header naming a height outside the segment), and the
//! complete records just before them whose checksums fail, such as a record a crash left
//! zero-filled. Reads ignore the bytes after the last complete record, and the next append
//! truncates the whole tail first. A complete record whose checksum fails is corrupt: a read
//! finds no body of its height there, and an append of its height supersedes it.

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

/// The fixed prefix of a record: its height, its body length and the body's keccak256.
const HEADER_LEN: u64 = 8 + 4 + 32;

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

/// A complete record [`scan`] found.
struct Entry {
    /// The height it records.
    height: u64,
    /// Where its body starts in the file.
    offset: u64,
    /// The body length.
    len: u32,
    /// The keccak256 its header claims for the body.
    checksum: [u8; 32],
}

/// The complete records of a segment, in file order, and where they end: any bytes after `end`
/// are a torn tail.
struct Scan {
    /// The complete records.
    entries: Vec<Entry>,
    /// The end of the last complete record.
    end: u64,
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
    /// crash); one holding another body is the kind's conflict error and nothing is written. The
    /// torn tail is truncated before the record is written, and a corrupt record of `height` is
    /// superseded by the new one. The record and the segment's size are fsynced before this
    /// returns, and so is the directory when the append creates the segment.
    pub(crate) fn append(&self, height: u64, body: &[u8]) -> Result<(), StoreError> {
        let first = first_height(height);
        let path = self.path(first);
        let len = u32::try_from(body.len()).map_err(|_| {
            io_err("append", &path, io::Error::new(io::ErrorKind::InvalidInput, "body over 4 GiB"))
        })?;
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
        let (scan, size) =
            scan(&mut file, first).map_err(|source| io_err("read", &path, source))?;
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
        let mut end = scan.end;
        for entry in scan.entries.iter().rev() {
            if read_body(&mut file, entry)
                .map_err(|source| io_err("read", &path, source))?
                .is_some()
            {
                break;
            }
            end = entry.offset - HEADER_LEN;
        }
        if end < size {
            tracing::warn!(
                file = %path.display(),
                from = end,
                bytes = size - end,
                "truncating a torn segment tail"
            );
            file.set_len(end).map_err(|source| io_err("truncate", &path, source))?;
        }
        let mut record = Vec::with_capacity(HEADER_LEN as usize + body.len());
        record.extend_from_slice(&height.to_be_bytes());
        record.extend_from_slice(&len.to_be_bytes());
        record.extend_from_slice(keccak256(body).as_slice());
        record.extend_from_slice(body);
        file.seek(SeekFrom::Start(end))
            .and_then(|_| file.write_all(&record))
            .map_err(|source| io_err("write", &path, source))?;
        if self.durable {
            file.sync_all().map_err(|source| io_err("fsync", &path, source))?;
            if created {
                sync_dir(&self.dir)?;
            }
        }
        Ok(())
    }

    /// The body recorded for `height`: [`Record::Valid`] for the first record of that height
    /// whose checksum matches, [`Record::Corrupt`] when every record of it fails its checksum and
    /// [`Record::Missing`] when the segment holds no complete record of it (a torn tail is
    /// none). Filesystem errors other than an absent segment are [`StoreError::Io`].
    pub(crate) fn read(&self, height: u64) -> Result<Record<Vec<u8>>, StoreError> {
        let first = first_height(height);
        let path = self.path(first);
        let mut file = match File::open(&path) {
            Ok(file) => file,
            Err(error) if error.kind() == io::ErrorKind::NotFound => return Ok(Record::Missing),
            Err(source) => return Err(io_err("open", &path, source)),
        };
        let (scan, _) = scan(&mut file, first).map_err(|source| io_err("read", &path, source))?;
        let mut corrupt = false;
        for entry in scan.entries.iter().filter(|entry| entry.height == height) {
            match read_body(&mut file, entry).map_err(|source| io_err("read", &path, source))? {
                Some(body) => return Ok(Record::Valid(body)),
                None => corrupt = true,
            }
        }
        Ok(if corrupt {
            Record::Corrupt("the checksum does not match".into())
        } else {
            Record::Missing
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

    /// The heights of every complete record in every segment, ascending and without repeats,
    /// whether their checksums match or not. It reads every segment's headers, so it is for a
    /// kind recorded at few heights, such as the validator-state snapshots.
    pub(crate) fn heights(&self) -> Result<Vec<u64>, StoreError> {
        let mut heights = vec![];
        for first in self.segments()? {
            let path = self.path(first);
            let scanned = File::open(&path).and_then(|mut file| scan(&mut file, first));
            match scanned {
                Ok((scan, _)) => heights.extend(scan.entries.iter().map(|entry| entry.height)),
                Err(error) if error.kind() == io::ErrorKind::NotFound => {}
                Err(source) => return Err(io_err("read", &path, source)),
            }
        }
        heights.sort_unstable();
        heights.dedup();
        Ok(heights)
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

/// The complete records of the segment `file`, whose heights start at `first`, with the file's
/// size. Reading stops at the first header that is cut, names a height outside the segment or
/// claims a body past the end of the file. A segment that is no regular file is an error.
fn scan(file: &mut File, first: u64) -> io::Result<(Scan, u64)> {
    let metadata = file.metadata()?;
    if !metadata.is_file() {
        return Err(io::Error::other("the segment is not a regular file"));
    }
    let size = metadata.len();
    file.seek(SeekFrom::Start(0))?;
    let mut reader = BufReader::new(&*file);
    let mut entries = vec![];
    let mut end = 0;
    while size - end >= HEADER_LEN {
        let mut header = [0u8; HEADER_LEN as usize];
        reader.read_exact(&mut header)?;
        let (height, rest) = header.split_first_chunk::<8>().expect("eight bytes");
        let (len, checksum) = rest.split_first_chunk::<4>().expect("four bytes");
        let (height, len) = (u64::from_be_bytes(*height), u32::from_be_bytes(*len));
        let offset = end + HEADER_LEN;
        if height.checked_sub(first).is_none_or(|step| step >= SEGMENT_HEIGHTS) ||
            size - offset < u64::from(len)
        {
            break;
        }
        let checksum = checksum.try_into().expect("32 bytes");
        entries.push(Entry { height, offset, len, checksum });
        reader.seek_relative(i64::from(len))?;
        end = offset + u64::from(len);
    }
    Ok((Scan { entries, end }, size))
}

/// The body of `entry`, or `None` when it does not hash to the checksum its header claims.
fn read_body(file: &mut File, entry: &Entry) -> io::Result<Option<Vec<u8>>> {
    let mut body = vec![0; entry.len as usize];
    file.seek(SeekFrom::Start(entry.offset))?;
    file.read_exact(&mut body)?;
    Ok((keccak256(&body).0 == entry.checksum).then_some(body))
}

#[cfg(test)]
impl SegmentLog {
    /// Deletes every record of `height` from its segment, as if it had never been written;
    /// returns the body of the last one.
    pub(crate) fn remove(&self, height: u64) -> Option<Vec<u8>> {
        let mut removed = None;
        self.rewrite(height, |records| {
            records.retain(|(recorded, _, body)| {
                let keep = *recorded != height;
                if !keep {
                    removed = Some(body.clone());
                }
                keep
            })
        });
        removed
    }

    /// Replaces the body of every record of `height` with `body` under a matching checksum:
    /// coherent damage no checksum catches.
    pub(crate) fn replace(&self, height: u64, body: &[u8]) {
        self.rewrite(height, |records| {
            for (_, checksum, old) in records.iter_mut().filter(|(h, ..)| *h == height) {
                *checksum = keccak256(body).0;
                *old = body.to_vec();
            }
        });
    }

    /// Flips a checksum byte of every record of `height`, so that none of them matches.
    pub(crate) fn corrupt(&self, height: u64) {
        self.rewrite(height, |records| {
            for (_, checksum, _) in records.iter_mut().filter(|(h, ..)| *h == height) {
                checksum[0] ^= 1;
            }
        });
    }

    /// Rewrites `height`'s segment from its complete records, edited by `edit`.
    fn rewrite(&self, height: u64, edit: impl FnOnce(&mut Vec<(u64, [u8; 32], Vec<u8>)>)) {
        let first = first_height(height);
        let path = self.path(first);
        let mut file = File::open(&path).expect("the segment exists");
        let (scan, _) = scan(&mut file, first).unwrap();
        let mut records = vec![];
        for entry in &scan.entries {
            let mut body = vec![0; entry.len as usize];
            file.seek(SeekFrom::Start(entry.offset)).unwrap();
            file.read_exact(&mut body).unwrap();
            records.push((entry.height, entry.checksum, body));
        }
        edit(&mut records);
        let mut bytes = vec![];
        for (height, checksum, body) in records {
            bytes.extend_from_slice(&height.to_be_bytes());
            bytes.extend_from_slice(&u32::try_from(body.len()).unwrap().to_be_bytes());
            bytes.extend_from_slice(&checksum);
            bytes.extend_from_slice(&body);
        }
        fs::write(&path, bytes).unwrap();
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

    /// The record bytes of `body` at `height`.
    fn record(height: u64, body: &[u8]) -> Vec<u8> {
        let len = u32::try_from(body.len()).unwrap();
        [&height.to_be_bytes()[..], &len.to_be_bytes(), keccak256(body).as_slice(), body].concat()
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
        assert_eq!(fs::read_dir(dir.path()).unwrap().count(), 2);

        // A segment that is no regular file fails every access instead of reading as empty.
        fs::create_dir(segment(dir.path(), 2 * SEGMENT_HEIGHTS)).unwrap();
        let height = 2 * SEGMENT_HEIGHTS + 1;
        assert!(matches!(log.read(height), Err(StoreError::Io { .. })));
        assert!(matches!(log.append(height, b"x"), Err(StoreError::Io { .. })));
        assert!(matches!(log.heights(), Err(StoreError::Io { .. })));
    }

    /// Appending a height's body again changes nothing; another body for it conflicts and is
    /// not written. A record whose checksum fails is no body: reads find it corrupt, and an
    /// append of its height supersedes it.
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

        log.corrupt(7);
        assert!(matches!(log.read(7).unwrap(), Record::Corrupt(_)));
        assert_eq!(log.read(8).unwrap(), Record::Valid(b"eight".to_vec()));
        log.append(7, b"SEVEN").unwrap();
        assert_eq!(log.read(7).unwrap(), Record::Valid(b"SEVEN".to_vec()));
        log.append(7, b"SEVEN").unwrap();
        assert!(matches!(log.append(7, b"seven"), Err(StoreError::CometConflict(7))));
    }

    /// A crash during an append leaves a torn tail: a cut header, a cut body, a header naming a
    /// height outside the segment, or a record a crash left zero-filled past its header or
    /// entirely. No read finds the torn record, and the next append truncates the tail before
    /// writing, leaving the bytes an uninterrupted append writes.
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
        let outside = record(SEGMENT_HEIGHTS, b"three");
        let mut tails: Vec<Vec<u8>> = (1..record(3, b"three").len())
            .map(|cut| complete[..kept.len() + cut].to_vec())
            .collect();
        tails.push([kept.as_slice(), &outside].concat());
        let mut zeroed = complete.clone();
        zeroed[kept.len() + 12..].fill(0);
        tails.push(zeroed);
        tails.push([kept.as_slice(), &[0; 100]].concat());
        for torn in tails {
            fs::write(&path, &torn).unwrap();
            assert!(!matches!(log.read(3).unwrap(), Record::Valid(_)), "{} bytes", torn.len());
            assert_eq!(log.read(2).unwrap(), Record::Valid(b"two".to_vec()));
            log.append(3, b"three").unwrap();
            assert_eq!(fs::read(&path).unwrap(), complete, "{} bytes", torn.len());
            assert_eq!(log.heights().unwrap(), [1, 2, 3]);
        }
        fs::write(&path, &complete[..kept.len() + 10]).unwrap();
        log.append(4, b"four").unwrap();
        assert_eq!(fs::read(&path).unwrap(), [kept, record(4, b"four")].concat());
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
