------------------------ MODULE EtnaTimestampSafety ------------------------
EXTENDS EtnaTimestampRecoveryProduct

\* Only the ordinary safety profiles use this view. Call still assigns the
\* full actual receipt and all observations used by the original product.
SafetyView == <<s,bad>>
=============================================================================
