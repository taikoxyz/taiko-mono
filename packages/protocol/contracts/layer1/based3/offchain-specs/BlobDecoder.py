from typing import List
from Data import ProposalData, Block

class BlobDecoder:
    """Handles decoding of proposal data from blobs."""
    
    def decode_proposal_data_from_blobs(self, blob_data: bytes) -> ProposalData:
        """
        Decode proposal data from blob data.
        If decoding fails, returns a default ProposalData with one empty block.
        """
        try:
            return self.decode_blob_data(blob_data)
        except Exception:
            # Return default proposal data with one empty block
            return ProposalData(
                gas_issuance_per_second=0,
                blocks=[Block(
                    timestamp=0, 
                    fee_recipient='0x0000000000000000000000000000000000000000', 
                    transactions=[]
                )]
            )
    
    def decode_blob_data(self, blob_data: bytes) -> ProposalData:
        """
        Decode blob data into ProposalData.
        This is an abstract method that must be implemented by node.
        """
        raise NotImplementedError("Must be implemented by node")