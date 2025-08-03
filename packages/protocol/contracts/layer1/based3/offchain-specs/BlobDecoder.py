from typing import cast
from eth_typing import Address
from Types import Content, BlockArgs


class BlobDecoder:
    """Handles decoding of proposal data from blobs."""

    ADDRESS_ZERO = cast(Address, "0x0000000000000000000000000000000000000000")

    def decode_proposal_data_from_blobs(self, blob_data: bytes) -> Content:
        """
        Decode proposal data from blob data.
        If decoding fails, returns a default Content with one empty block.
        """
        try:
            return self.decode_blob_data(blob_data)
        except Exception:
            # Return default proposal data with one empty block
            return Content(
                gas_issuance_per_second=0,
                prover_fee=0,
                prover_signature="",
                block_argss=[
                    BlockArgs(
                        timestamp=0,
                        fee_recipient=self.ADDRESS_ZERO,
                        transactions=[],
                        anchor_block_number=0,
                    )
                ],
            )

    def decode_blob_data(self, blob_data: bytes) -> Content:
        """
        Decode blob data into Content.
        This is an abstract method that must be implemented by node.
        """
        raise NotImplementedError("Must be implemented by node")
