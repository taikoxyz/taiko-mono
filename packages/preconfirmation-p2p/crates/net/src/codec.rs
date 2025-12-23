//! SSZ codecs and protocol identifiers for libp2p request/response handlers.

use async_trait::async_trait;
use futures::prelude::*;
use libp2p_request_response::Codec;
use preconfirmation_types::{MAX_COMMITMENTS_PER_RESPONSE, MAX_TXLIST_BYTES};
use ssz_rs::prelude::*;
use std::{io, marker::PhantomData};
use unsigned_varint as uvar;

/// SSZ codec that can encode and decode distinct request/response types for a protocol with
/// bounded frame sizes.
///
/// Each codec instance enforces a maximum encoded length for requests and responses to avoid
/// unbounded frame allocations. The bounds are derived from protocol-level caps in
/// `preconfirmation_types::constants` and tuned per message type.
pub struct SszCodec<Req, Resp, const MAX_REQ: usize, const MAX_RESP: usize> {
    /// Phantom data tracking request/response types.
    _marker: PhantomData<(Req, Resp)>,
}

impl<Req, Resp, const MAX_REQ: usize, const MAX_RESP: usize> Clone
    for SszCodec<Req, Resp, MAX_REQ, MAX_RESP>
{
    /// Returns a clone of the codec marker.
    fn clone(&self) -> Self {
        Self { _marker: PhantomData }
    }
}

impl<Req, Resp, const MAX_REQ: usize, const MAX_RESP: usize> Default
    for SszCodec<Req, Resp, MAX_REQ, MAX_RESP>
{
    /// Creates a default codec marker instance.
    fn default() -> Self {
        Self { _marker: PhantomData }
    }
}

/// Type alias for the `SszCodec` handling commitments requests and responses.
/// Maximum encoded size for commitments request/response frames.
/// Maximum encoded size for commitments request frames.
const COMMIT_REQ_MAX_BYTES: usize = 512; // block number + small fields
/// Maximum encoded size for commitments response frames.
const COMMIT_RESP_MAX_BYTES: usize = MAX_COMMITMENTS_PER_RESPONSE * 4096; // ~1 MiB upper bound
/// Type alias for the `SszCodec` handling commitments requests and responses.
pub type CommitmentsCodec = SszCodec<
    preconfirmation_types::GetCommitmentsByNumberRequest,
    preconfirmation_types::GetCommitmentsByNumberResponse,
    COMMIT_REQ_MAX_BYTES,
    COMMIT_RESP_MAX_BYTES,
>;
/// Type alias for the `SszCodec` handling raw transaction list requests and responses.
pub type RawTxListCodec = SszCodec<
    preconfirmation_types::GetRawTxListRequest,
    preconfirmation_types::GetRawTxListResponse,
    RAW_TXLIST_REQ_MAX_BYTES,
    RAW_TXLIST_RESP_MAX_BYTES,
>;
/// Type alias for the `SszCodec` handling head requests and responses.
pub type HeadCodec = SszCodec<
    preconfirmation_types::GetHeadRequest,
    preconfirmation_types::PreconfHead,
    HEAD_REQ_MAX_BYTES,
    HEAD_RESP_MAX_BYTES,
>;

/// Maximum encoded size for raw-txlist request frames.
const RAW_TXLIST_REQ_MAX_BYTES: usize = 256; // hash + small fields
/// Maximum encoded size for raw-txlist response frames.
const RAW_TXLIST_RESP_MAX_BYTES: usize = MAX_TXLIST_BYTES + 4096; // payload + slack
/// Maximum encoded size for head request frames.
const HEAD_REQ_MAX_BYTES: usize = 128;
/// Maximum encoded size for head response frames.
const HEAD_RESP_MAX_BYTES: usize = 64 * 1024;

#[derive(Clone)]
/// Holds the protocol IDs for various request-response protocols.
pub struct Protocols {
    /// Protocol ID for commitments request-response.
    pub commitments: SszProtocol,
    /// Protocol ID for raw transaction list request-response.
    pub raw_txlists: SszProtocol,
    /// Protocol ID for get_head request-response.
    pub head: SszProtocol,
}

#[derive(Clone)]
/// A wrapper for a protocol ID string.
///
/// Implements `AsRef<str>` to allow easy conversion to `&str`.
pub struct SszProtocol(
    /// Protocol identifier string.
    pub String,
);

impl AsRef<str> for SszProtocol {
    /// Return the protocol identifier as a string slice.
    fn as_ref(&self) -> &str {
        &self.0
    }
}

#[async_trait]
impl<Req, Resp, const MAX_REQ: usize, const MAX_RESP: usize> Codec
    for SszCodec<Req, Resp, MAX_REQ, MAX_RESP>
where
    Req: SimpleSerialize + Clone + Send + Sync + 'static,
    Resp: SimpleSerialize + Clone + Send + Sync + 'static,
{
    type Protocol = SszProtocol;
    type Request = Req;
    type Response = Resp;

    /// Read and decode a request frame.
    async fn read_request<R>(&mut self, _: &SszProtocol, io: &mut R) -> io::Result<Self::Request>
    where
        R: AsyncRead + Unpin + Send,
    {
        read_ssz(io, MAX_REQ).await
    }

    /// Read and decode a response frame.
    async fn read_response<R>(&mut self, _: &SszProtocol, io: &mut R) -> io::Result<Self::Response>
    where
        R: AsyncRead + Unpin + Send,
    {
        read_ssz(io, MAX_RESP).await
    }

    /// Encode and write a request frame.
    async fn write_request<W>(
        &mut self,
        _: &SszProtocol,
        io: &mut W,
        req: Self::Request,
    ) -> io::Result<()>
    where
        W: AsyncWrite + Unpin + Send,
    {
        write_ssz(io, req, MAX_REQ).await
    }

    /// Encode and write a response frame.
    async fn write_response<W>(
        &mut self,
        _: &SszProtocol,
        io: &mut W,
        res: Self::Response,
    ) -> io::Result<()>
    where
        W: AsyncWrite + Unpin + Send,
    {
        write_ssz(io, res, MAX_RESP).await
    }
}

/// Reads an SSZ-serialized value from an asynchronous reader with a defensive length cap using
/// libp2p-style unsigned-varint framing.
///
/// The function reads a u32 length encoded as unsigned-varint, rejects frames larger than
/// `max_len`, then reads the payload and attempts SSZ deserialization.
async fn read_ssz<T: SimpleSerialize + Default, R: AsyncRead + Unpin + Send>(
    io: &mut R,
    max_len: usize,
) -> io::Result<T> {
    use futures::io::AsyncReadExt;
    let len = uvar::aio::read_u32(&mut *io)
        .await
        .map_err(|e| io::Error::new(io::ErrorKind::InvalidData, format!("varint len: {e}")))?
        as usize;
    if len > max_len {
        return Err(io::Error::new(
            io::ErrorKind::InvalidData,
            format!("frame too large: {len} > {max_len}"),
        ));
    }
    let mut buf = vec![0u8; len];
    io.read_exact(&mut buf).await?;
    T::deserialize(&buf)
        .map_err(|e| io::Error::new(io::ErrorKind::InvalidData, format!("ssz decode: {e}")))
}

/// Writes an SSZ-serializable value to an asynchronous writer with a defensive length cap using
/// libp2p-style unsigned-varint framing.
async fn write_ssz<T: SimpleSerialize, W: AsyncWrite + Unpin + Send>(
    io: &mut W,
    value: T,
    max_len: usize,
) -> io::Result<()> {
    use futures::io::AsyncWriteExt;
    let bytes = ssz_rs::serialize(&value)
        .map_err(|e| io::Error::new(io::ErrorKind::InvalidData, format!("ssz encode: {e}")))?;
    if bytes.len() > max_len {
        return Err(io::Error::new(
            io::ErrorKind::InvalidData,
            format!("frame too large: {} > {max_len}", bytes.len()),
        ));
    }
    let len = bytes.len() as u32;
    // Prefix with unsigned-varint length so the receiver can bound reads and avoid framing
    // ambiguity; matches docs/specification.md req/resp framing.
    let mut buf = uvar::encode::u32_buffer();
    let len_bytes = uvar::encode::u32(len, &mut buf);
    io.write_all(len_bytes).await?;
    io.write_all(&bytes).await
}

#[cfg(test)]
mod tests {
    use super::*;
    use futures::io::Cursor;
    use preconfirmation_types::{
        Bytes32, GetCommitmentsByNumberRequest, GetCommitmentsByNumberResponse,
        GetRawTxListResponse, Uint256,
    };

    /// Commitments codec roundtrips requests and responses within bounds.
    #[tokio::test]
    async fn commitments_codec_roundtrip() {
        let mut codec = CommitmentsCodec::default();
        let proto = SszProtocol("/taiko/test/commitments/1".into());

        let req =
            GetCommitmentsByNumberRequest { start_block_number: Uint256::from(1u64), max_count: 5 };
        let mut buf = Cursor::new(Vec::new());
        codec.write_request(&proto, &mut buf, req.clone()).await.unwrap();
        buf.set_position(0);
        let decoded = codec.read_request(&proto, &mut buf).await.unwrap();
        assert_eq!(req, decoded);

        let resp = GetCommitmentsByNumberResponse { commitments: Default::default() };
        let mut buf = Cursor::new(Vec::new());
        codec.write_response(&proto, &mut buf, resp.clone()).await.unwrap();
        buf.set_position(0);
        let decoded = codec.read_response(&proto, &mut buf).await.unwrap();
        assert_eq!(resp, decoded);
    }

    /// Responses exceeding the configured cap are rejected on decode.
    #[tokio::test]
    async fn oversized_response_is_rejected_on_read() {
        let mut codec = RawTxListCodec::default();
        let proto = SszProtocol("/taiko/test/rawtx/1".into());

        // Craft a frame with a length one byte over the allowed bound.
        let over = RAW_TXLIST_RESP_MAX_BYTES + 1;
        let mut buf = Cursor::new(Vec::new());
        let mut len_buf = uvar::encode::u32_buffer();
        let len_bytes = uvar::encode::u32(over as u32, &mut len_buf);
        buf.get_mut().extend_from_slice(len_bytes);
        buf.get_mut().resize(len_bytes.len() + over, 0u8);
        buf.set_position(0);

        let err = codec.read_response(&proto, &mut buf).await.unwrap_err();
        assert_eq!(err.kind(), io::ErrorKind::InvalidData);
    }

    /// Encoding fails when a frame would exceed its max length.
    #[tokio::test]
    async fn write_errors_when_frame_exceeds_cap() {
        // Use a deliberately tiny cap to force an error on write.
        type TinyCodec = SszCodec<
            preconfirmation_types::GetRawTxListRequest,
            preconfirmation_types::GetRawTxListResponse,
            64,
            16,
        >;
        let mut codec = TinyCodec::default();
        let proto = SszProtocol("/taiko/test/rawtx/1".into());

        let txlist = preconfirmation_types::TxListBytes::try_from(vec![0u8; 32]).unwrap();
        let resp = GetRawTxListResponse {
            raw_tx_list_hash: Bytes32::try_from(vec![1u8; 32]).unwrap(),
            txlist,
        };

        let mut buf = Cursor::new(Vec::new());
        let err = codec.write_response(&proto, &mut buf, resp).await.unwrap_err();
        assert_eq!(err.kind(), io::ErrorKind::InvalidData);
    }
}
