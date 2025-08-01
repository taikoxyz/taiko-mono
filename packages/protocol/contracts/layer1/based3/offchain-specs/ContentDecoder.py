from typing import List
from IShasta import ProposalContent, Block

class ContentDecoder:
    """Handles decoding of proposal data from blobs."""
    
    def decode_proposal_data_from_blobs(self, blob_data: bytes) -> ProposalContent:
        """
        Decode proposal data from blob data.
        If decoding fails, returns a default ProposalContent with one empty block.
        """
        try:
            return self.decode_blob_data(blob_data)
        except Exception:
            # Return default proposal data with one empty block
            return ProposalContent(
                gas_issuance_per_second=0,
                blocks=[Block(
                    timestamp=0, 
                    fee_recipient='0x0000000000000000000000000000000000000000', 
                    transactions=[]
                )]
            )
    
    def decode_blob_data(self, blob_data: bytes) -> ProposalContent:
        """
        Decode blob data into ProposalContent.
        This is an abstract method that must be implemented by node.
        """
        raise NotImplementedError("Must be implemented by node")