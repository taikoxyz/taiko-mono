// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Error Code:

// TEE - Unknown TEE type.
// OUTS - Invalid output size

// QHS - Quote length is not as expected.
// QHV - Quote Version mismatch.
// QHATTF - Quote Attestation Type not supported.
// QEVEN - Quote Enclave Vendor ID not supported.

// QBF - Quote body parsing failed because it doesn't match the expected format.
// QBS - Quote body parsing failed because of size mismatch.
// ADS - AuthData parsing failed because of size mismatch.
// ADF - AuthData parsing failed

// TD10F - Failed to parse TD10 report body.
// TD15F - Failed to parse TD15 report body.
// TDMF - TDX Module check failed.
// TDRF - TDX Relaunch check failed.

// TCBR - TCB status is revoked or missing.

// QEF - QE Report parsing failed
// QEVE - QE Report Verification error
// QEIDVE - QE Identity Verification error
// X509VE - X.509 Certificate Verification error
// ATTVE - Quote Attestation Verification error

// TCBCH - TCB Content Hash mismatch
// QEIDCH - QE Identity Content Hash mismatch
// ROOTH - Root CA hash mismtach
// SIGNH - TCB Signing CA hash mismatch
// ROOTCRLH - Root CA CRL hash mismatch
// PCKCRLM - PCK CA CRL missing
// PCKCRLH - PCK CA CRL hash mismatch

string constant TEE = "TEE";
string constant OUTS = "OUTS";
string constant QHS = "QHS";
string constant QHV = "QHV";
string constant QHATTF = "QHATTF";
string constant QEVEN = "QEVEN";
string constant QBF = "QBF";
string constant QBS = "QBS";
string constant ADS = "ADS";
string constant ADF = "ADF";
string constant TD10F = "TD10F";
string constant TD15F = "TD15F";
string constant TDMF = "TDMF";
string constant TDRF = "TDRF";
string constant TCBR = "TCBR";
string constant QEF = "QEF";
string constant QEVE = "QEVE";
string constant QEIDVE = "QEIDVE";
string constant X509VE = "X509VE";
string constant ATTVE = "ATTVE";
string constant TCBCH = "TCBCH";
string constant QEIDCH = "QEIDCH";
string constant ROOTH = "ROOTH";
string constant SIGNH = "SIGNH";
string constant ROOTCRLH = "ROOTCRLH";
string constant PCKCRLM = "PCKCRLM";
string constant PCKCRLH = "PCKCRLH";