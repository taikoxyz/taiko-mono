use async_trait::async_trait;
use futures::prelude::*;
use libp2p_request_response::Codec;
use ssz_rs::prelude::*;
use std::io;

/// SSZ codec that can encode distinct request/response types for a protocol.
#[allow(dead_code)]
pub struct SszCodec<Req, Resp> {
    _marker: std::marker::PhantomData<(Req, Resp)>,
}

impl<Req, Resp> Clone for SszCodec<Req, Resp> {
    fn clone(&self) -> Self {
        Self { _marker: std::marker::PhantomData }
    }
}

impl<Req, Resp> Default for SszCodec<Req, Resp> {
    fn default() -> Self {
        Self { _marker: std::marker::PhantomData }
    }
}

pub type CommitmentsCodec = SszCodec<
    preconfirmation_types::GetCommitmentsByNumberRequest,
    preconfirmation_types::GetCommitmentsByNumberResponse,
>;
pub type RawTxListCodec = SszCodec<
    preconfirmation_types::GetRawTxListRequest,
    preconfirmation_types::GetRawTxListResponse,
>;
pub type HeadCodec = SszCodec<preconfirmation_types::GetHeadRequest, preconfirmation_types::PreconfHead>;

#[derive(Clone)]
pub struct Protocols {
    /// Protocol ID for commitments req/resp.
    pub commitments: SszProtocol,
    /// Protocol ID for raw-txlist req/resp.
    pub raw_txlists: SszProtocol,
    /// Protocol ID for get_head req/resp.
    pub head: SszProtocol,
}

#[derive(Clone)]
pub struct SszProtocol(pub String);

impl AsRef<str> for SszProtocol {
    fn as_ref(&self) -> &str {
        &self.0
    }
}

#[async_trait]
impl<Req, Resp> Codec for SszCodec<Req, Resp>
where
    Req: SimpleSerialize + Clone + Send + Sync + 'static,
    Resp: SimpleSerialize + Clone + Send + Sync + 'static,
{
    type Protocol = SszProtocol;
    type Request = Req;
    type Response = Resp;

    async fn read_request<R>(&mut self, _: &SszProtocol, io: &mut R) -> io::Result<Self::Request>
    where
        R: AsyncRead + Unpin + Send,
    {
        read_ssz(io).await
    }

    async fn read_response<R>(&mut self, _: &SszProtocol, io: &mut R) -> io::Result<Self::Response>
    where
        R: AsyncRead + Unpin + Send,
    {
        read_ssz(io).await
    }

    async fn write_request<W>(
        &mut self,
        _: &SszProtocol,
        io: &mut W,
        req: Self::Request,
    ) -> io::Result<()>
    where
        W: AsyncWrite + Unpin + Send,
    {
        write_ssz(io, req).await
    }

    async fn write_response<W>(
        &mut self,
        _: &SszProtocol,
        io: &mut W,
        res: Self::Response,
    ) -> io::Result<()>
    where
        W: AsyncWrite + Unpin + Send,
    {
        write_ssz(io, res).await
    }
}

#[allow(dead_code)]
async fn read_ssz<T: SimpleSerialize + Default, R: AsyncRead + Unpin + Send>(
    io: &mut R,
) -> io::Result<T> {
    use futures::io::AsyncReadExt;
    let mut len_bytes = [0u8; 4];
    io.read_exact(&mut len_bytes).await?;
    let len = u32::from_le_bytes(len_bytes) as usize;
    let mut buf = vec![0u8; len];
    io.read_exact(&mut buf).await?;
    T::deserialize(&buf)
        .map_err(|e| io::Error::new(io::ErrorKind::InvalidData, format!("ssz decode: {e}")))
}

#[allow(dead_code)]
async fn write_ssz<T: SimpleSerialize, W: AsyncWrite + Unpin + Send>(
    io: &mut W,
    value: T,
) -> io::Result<()> {
    use futures::io::AsyncWriteExt;
    let bytes = ssz_rs::serialize(&value)
        .map_err(|e| io::Error::new(io::ErrorKind::InvalidData, format!("ssz encode: {e}")))?;
    let len = bytes.len() as u32;
    io.write_all(&len.to_le_bytes()).await?;
    io.write_all(&bytes).await
}

#[cfg(test)]
mod tests {
    use super::*;
    use futures::io::Cursor;
    use preconfirmation_types::{
        GetCommitmentsByNumberRequest, GetCommitmentsByNumberResponse, Uint256,
    };

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
}
