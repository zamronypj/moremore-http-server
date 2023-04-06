/// low-level access to the SSPI/SChannel API for Win32/Win64
// - this unit is a part of the Open Source Synopse mORMot framework 2,
// licensed under a MPL/GPL/LGPL three license - see LICENSE.md
unit mormot.lib.sspi;


{
  *****************************************************************************

   Security Support Provider Interface (SSPI) Support on Windows
   - Low-Level SSPI/SChannel Functions
   - Middle-Level SSPI Wrappers
   - High-Level Client and Server Authentication using SSPI
   - Lan Manager Access Functions

  *****************************************************************************

}

interface

{$I ..\mormot.defines.inc}

{$ifdef OSPOSIX}

// do-nothing-unit on non Windows system

implementation

{$else}

uses
  sysutils,
  classes,
  mormot.core.base,
  mormot.core.os;
  // since we use it from mormot.net.sock, we avoid mormot.core.unicode


{ ****************** Low-Level SSPI/SChannel Functions }

type
  LONG_PTR = PtrInt;
  
  TTimeStamp = record
    dwLowDateTime: cardinal;
    dwHighDateTime: cardinal;
  end;
  PTimeStamp = ^TTimeStamp;


  ALG_ID = cardinal;
  TALG_IDs = array[word] of ALG_ID;
  PALG_IDs = ^TALG_IDs;

  /// SSPI context handle
  TSecHandle = record
    dwLower: LONG_PTR;
    dwUpper: LONG_PTR;
  end;
  PSecHandle = ^TSecHandle;

  // some context aliases, as defined in SSPI headers
  TCredHandle = type TSecHandle;
  PCredHandle = type PSecHandle;
  TCtxtHandle = type TSecHandle;
  PCtxtHandle = type PSecHandle;

  /// SSPI context
  TSecContext = record
    ID: Int64;
    CredHandle: TSecHandle;
    CtxHandle: TSecHandle;
    CreatedTick64: Int64;
  end;
  PSecContext = ^TSecContext;

  /// dynamic array of SSPI contexts
  // - used to hold information between calls to ServerSspiAuth
  TSecContextDynArray = array of TSecContext;

  /// defines a SSPI buffer
  {$ifdef USERECORDWITHMETHODS}
  TSecBuffer = record
  {$else}
  TSecBuffer = object
  {$endif USERECORDWITHMETHODS}
  public
    cbBuffer: cardinal;
    BufferType: cardinal;
    pvBuffer: pointer;
    procedure Init(aType: cardinal; aData: pointer; aSize: cardinal);
      {$ifdef HASINLINE} inline; {$endif}
  end;
  PSecBuffer = ^TSecBuffer;

  /// describes a SSPI buffer
  {$ifdef USERECORDWITHMETHODS}
  TSecBufferDesc = record
  {$else}
  TSecBufferDesc = object
  {$endif USERECORDWITHMETHODS}
  public
    ulVersion: cardinal;
    cBuffers: cardinal;
    pBuffers: PSecBuffer;
    procedure Init(aVersion: cardinal;
      aBuffers: PSecBuffer; aBuffersCount: cardinal);
      {$ifdef HASINLINE} inline; {$endif}
  end;
  PSecBufferDesc = ^TSecBufferDesc;

  /// store the name associated with the context
  SecPkgContext_NamesW = record
    sUserName: PWideChar;
  end;

  /// store information about a SSPI package
  TSecPkgInfoW = record
    fCapabilities: cardinal;
    wVersion: Word;
    wRPCID: Word;
    cbMaxToken: cardinal;
    Name: PWideChar;
    Comment: PWideChar;
  end;
  /// pointer to information about a SSPI package
  PSecPkgInfoW = ^TSecPkgInfoW;

  /// store negotation information about a SSPI package
  TSecPkgContext_NegotiationInfo = record
    PackageInfo: PSecPkgInfoW;
    NegotiationState: cardinal;
  end;

  /// store various working buffer sizes of a SSPI command
  TSecPkgContext_Sizes = record
    cbMaxToken: cardinal;
    cbMaxSignature: cardinal;
    cbBlockSize: cardinal;
    cbSecurityTrailer: cardinal;
  end;

  /// store various working buffer sizes of a SSPI stream
  TSecPkgContext_StreamSizes = record
    cbHeader: cardinal;
    cbTrailer: cardinal;
    cbMaximumMessage: cardinal;
    cBuffers: cardinal;
    cbBlockSize: cardinal;
  end;

  /// information about SSPI supported algorithm
  TSecPkgCred_SupportedAlgs = record
    cSupportedAlgs: cardinal;
    palgSupportedAlgs: pointer;
  end;
  /// pointer to SSPI supported algorithm
  PSecPkgCred_SupportedAlgs = ^TSecPkgCred_SupportedAlgs;

  /// information about a SSPI connection (XP's SECPKG_ATTR_CONNECTION_INFO)
  {$ifdef USERECORDWITHMETHODS}
  TSecPkgConnectionInfo = record
  {$else}
  TSecPkgConnectionInfo = object
  {$endif USERECORDWITHMETHODS}
    dwProtocol: cardinal;
    aiCipher: ALG_ID;
    dwCipherStrength: cardinal;
    aiHash: ALG_ID;
    dwHashStrength: cardinal;
    aiExch: ALG_ID;
    dwExchStrength: cardinal;
    /// retrieve some decoded text representation of this raw information
    // - typically 'ECDHE256-AES128-SHA256 TLSv1.2'
    function ToText: RawUtf8;
  end;
  PSecPkgConnectionInfo = ^TSecPkgConnectionInfo;

  TSecPkgCipherInfoText = array[0..63] of WideChar;

  /// information about a SSPI connection (Vista+ SECPKG_ATTR_CIPHER_INFO)
  TSecPkgCipherInfo = record
    /// should be set to SECPKGCONTEXT_CIPHERINFO_V1
    dwVersion: cardinal;
    dwProtocol: cardinal;
    dwCipherSuite: cardinal;
    dwBaseCipherSuite: cardinal;
    /// fully qualified connection name
    // - e.g. 'TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384_P384'
    szCipherSuite: TSecPkgCipherInfoText;
    szCipher: TSecPkgCipherInfoText;
    dwCipherLen: cardinal;
    dwCipherBlockLen: cardinal;    // in bytes
    szHash: TSecPkgCipherInfoText;
    dwHashLen: cardinal;
    szExchange: TSecPkgCipherInfoText;
    dwMinExchangeLen: cardinal;
    dwMaxExchangeLen: cardinal;
    szCertificate: TSecPkgCipherInfoText;  // e.g. 'RSA'
    dwKeyType: cardinal;
  end;

  /// information about SSPI Authority Identify
  TSecWinntAuthIdentityW = record
    User: PWideChar;
    UserLength: cardinal;
    Domain: PWideChar;
    DomainLength: cardinal;
    Password: PWideChar;
    PasswordLength: cardinal;
    Flags: cardinal
  end;
  /// pointer to SSPI Authority Identify
  PSecWinntAuthIdentityW = ^TSecWinntAuthIdentityW;

const
  SECBUFFER_VERSION = 0;

  SECBUFFER_EMPTY          = 0;
  SECBUFFER_DATA           = 1;
  SECBUFFER_TOKEN          = 2;
  SECBUFFER_EXTRA          = 5;
  SECBUFFER_STREAM_TRAILER = 6;
  SECBUFFER_STREAM_HEADER  = 7;
  SECBUFFER_PADDING        = 9;
  SECBUFFER_STREAM         = 10;
  SECBUFFER_ALERT          = 17;

  SECPKG_CRED_INBOUND  = 1;
  SECPKG_CRED_OUTBOUND = 2;

  SECPKG_ATTR_SIZES               = 0;
  SECPKG_ATTR_NAMES               = 1;
  SECPKG_ATTR_STREAM_SIZES        = 4;
  SECPKG_ATTR_NEGOTIATION_INFO    = 12;
  SECPKG_ATTR_REMOTE_CERT_CONTEXT = $53;
  SECPKG_ATTR_CONNECTION_INFO     = $5a;
  SECPKG_ATTR_CIPHER_INFO         = $64; // Vista+ new API

  SECPKGCONTEXT_CIPHERINFO_V1 = 1;

  SECURITY_NETWORK_DREP = 0;
  SECURITY_NATIVE_DREP  = $10;

  ISC_REQ_DELEGATE               = $00000001;
  ISC_REQ_MUTUAL_AUTH            = $00000002;
  ISC_REQ_REPLAY_DETECT          = $00000004;
  ISC_REQ_SEQUENCE_DETECT        = $00000008;
  ISC_REQ_CONFIDENTIALITY        = $00000010;
  ISC_REQ_USE_SESSION_KEY        = $00000020;
  ISC_REQ_PROMPT_FOR_CREDS       = $00000040;
  ISC_REQ_USE_SUPPLIED_CREDS     = $00000080;
  ISC_REQ_ALLOCATE_MEMORY        = $00000100;
  ISC_REQ_USE_DCE_STYLE          = $00000200;
  ISC_REQ_DATAGRAM               = $00000400;
  ISC_REQ_CONNECTION             = $00000800;
  ISC_REQ_CALL_LEVEL             = $00001000;
  ISC_REQ_FRAGMENT_SUPPLIED      = $00002000;
  ISC_REQ_EXTENDED_ERROR         = $00004000;
  ISC_REQ_STREAM                 = $00008000;
  ISC_REQ_INTEGRITY              = $00010000;
  ISC_REQ_IDENTIFY               = $00020000;
  ISC_REQ_NULL_SESSION           = $00040000;
  ISC_REQ_MANUAL_CRED_VALIDATION = $00080000;
  ISC_REQ_RESERVED1              = $00100000;
  ISC_REQ_FRAGMENT_TO_FIT        = $00200000;
  ISC_REQ_FLAGS = ISC_REQ_SEQUENCE_DETECT or
                  ISC_REQ_REPLAY_DETECT or
                  ISC_REQ_CONFIDENTIALITY or
                  ISC_REQ_EXTENDED_ERROR or
                  ISC_REQ_ALLOCATE_MEMORY or
                  ISC_REQ_STREAM;

  ASC_REQ_REPLAY_DETECT   = $00000004;
  ASC_REQ_SEQUENCE_DETECT = $00000008;
  ASC_REQ_CONFIDENTIALITY = $00000010;
  ASC_REQ_ALLOCATE_MEMORY = $00000100;
  ASC_REQ_EXTENDED_ERROR  = $00008000;
  ASC_REQ_STREAM          = $00010000;
  ASC_REQ_FLAGS = ASC_REQ_SEQUENCE_DETECT or
                  ASC_REQ_REPLAY_DETECT or
                  ASC_REQ_CONFIDENTIALITY or
                  ASC_REQ_EXTENDED_ERROR or
                  ASC_REQ_ALLOCATE_MEMORY or
                  ASC_REQ_STREAM;

  SEC_E_OK = 0;

  SEC_I_CONTINUE_NEEDED        = $00090312;
  SEC_I_COMPLETE_NEEDED        = $00090313;
  SEC_I_COMPLETE_AND_CONTINUE  = $00090314;
  SEC_I_CONTEXT_EXPIRED	       = $00090317;
  SEC_I_INCOMPLETE_CREDENTIALS = $00090320;
  SEC_I_RENEGOTIATE            = $00090321;
  
  SEC_E_UNSUPPORTED_FUNCTION   = $80090302;
  SEC_E_INVALID_TOKEN          = $80090308;
  SEC_E_MESSAGE_ALTERED        = $8009030F;
  SEC_E_INCOMPLETE_MESSAGE     = $80090318;
  SEC_E_BUFFER_TOO_SMALL       = $80090321;
  SEC_E_ILLEGAL_MESSAGE        = $80090326;
  SEC_E_CERT_UNKNOWN           = $80090327;
  SEC_E_CERT_EXPIRED           = $80090328;
  SEC_E_ALGORITHM_MISMATCH     = $80090331;

  SEC_WINNT_AUTH_IDENTITY_UNICODE = $02;

  SCHANNEL_SHUTDOWN = 1;
  SCHANNEL_CRED_VERSION = 4;

  SCH_CRED_NO_SYSTEM_MAPPER                    = $00000002;
  SCH_CRED_NO_SERVERNAME_CHECK                 = $00000004;
  SCH_CRED_MANUAL_CRED_VALIDATION              = $00000008;
  SCH_CRED_NO_DEFAULT_CREDS                    = $00000010;
  SCH_CRED_AUTO_CRED_VALIDATION                = $00000020;
  SCH_CRED_USE_DEFAULT_CREDS                   = $00000040;
  SCH_CRED_DISABLE_RECONNECTS                  = $00000080;
  SCH_CRED_REVOCATION_CHECK_END_CERT           = $00000100;
  SCH_CRED_REVOCATION_CHECK_CHAIN              = $00000200;
  SCH_CRED_REVOCATION_CHECK_CHAIN_EXCLUDE_ROOT = $00000400;
  SCH_CRED_IGNORE_NO_REVOCATION_CHECK          = $00000800;
  SCH_CRED_IGNORE_REVOCATION_OFFLINE           = $00001000;
  SCH_CRED_RESTRICTED_ROOTS                    = $00002000;
  SCH_CRED_REVOCATION_CHECK_CACHE_ONLY         = $00004000;
  SCH_CRED_CACHE_ONLY_URL_RETRIEVAL            = $00008000;
  SCH_CRED_MEMORY_STORE_CERT                   = $00010000;
  SCH_CRED_CACHE_ONLY_URL_RETRIEVAL_ON_CREATE  = $00020000;
  SCH_SEND_ROOT_CERT                           = $00040000;

function SspiResToText(res: cardinal): TShort31;


// secur32.dll API calls

function QuerySecurityPackageInfoW(pszPackageName: PWideChar;
  var ppPackageInfo: PSecPkgInfoW): integer; stdcall;

function AcquireCredentialsHandleW(pszPrincipal, pszPackage: PWideChar;
  fCredentialUse: cardinal; pvLogonId: pointer; pAuthData: PSecWinntAuthIdentityW;
  pGetKeyFn: pointer; pvGetKeyArgument: pointer; phCredential: PSecHandle;
  ptsExpiry: PTimeStamp): integer; stdcall;

function InitializeSecurityContextW(phCredential: PSecHandle; phContext: PSecHandle;
  pszTargetName: PWideChar; fContextReq, Reserved1, TargetDataRep: cardinal;
  pInput: PSecBufferDesc; Reserved2: cardinal; phNewContext: PSecHandle;
  pOutput: PSecBufferDesc; var pfContextAttr: cardinal;
  ptsExpiry: PTimeStamp): integer; stdcall;

function AcceptSecurityContext(phCredential: PSecHandle; phContext: PSecHandle;
  pInput: PSecBufferDesc; fContextReq, TargetDataRep: cardinal;
  phNewContext: PSecHandle; pOutput: PSecBufferDesc; var pfContextAttr: cardinal;
  ptsExpiry: PTimeStamp): integer; stdcall;

function CompleteAuthToken(phContext: PSecHandle;
  pToken: PSecBufferDesc): integer; stdcall;

function QueryContextAttributesW(phContext: PSecHandle; ulAttribute: cardinal;
  pBuffer: pointer): integer; stdcall;

function ApplyControlToken(phContext: PCtxtHandle;
  pInput: PSecBufferDesc): cardinal; stdcall;

function QuerySecurityContextToken(phContext: PSecHandle;
  var Token: THandle): integer; stdcall;

function EncryptMessage(phContext: PSecHandle; fQOP: cardinal;
  pToken: PSecBufferDesc; MessageSeqNo: cardinal): integer; stdcall;

function DecryptMessage(phContext: PSecHandle; pToken: PSecBufferDesc;
  MessageSeqNo: cardinal; var fQOP: cardinal): integer; stdcall;

function FreeContextBuffer(pvContextBuffer: pointer): integer; stdcall;

function DeleteSecurityContext(phContext: PSecHandle): integer; stdcall;

function FreeCredentialsHandle(phCredential: PSecHandle): integer; stdcall;


type
  _HMAPPER = pointer;

  /// SChannel credential information
  TSChannelCred = record
    dwVersion: cardinal;
    cCreds: cardinal;
    paCred: PCCERT_CONTEXT;
    hRootStore: HCERTSTORE;
    cMappers: cardinal;
    aphMappers: _HMAPPER;
    cSupportedAlgs: cardinal;
    palgSupportedAlgs: PALG_IDs;
    grbitEnabledProtocols: cardinal;
    dwMinimumCipherStrength: cardinal;
    dwMaximumCipherStrength: cardinal;
    dwSessionLifespan: cardinal;
    dwFlags: cardinal;
    dwCredFormat: cardinal;
  end;
  /// pointer to SChannel credential information
  PSChannelCred = ^TSChannelCred;

  /// store a memory buffer during SChannel encryption
  TCryptDataBlob = record
    cbData: cardinal;
    pbData: Pointer;
  end;

  CTL_USAGE = record
    cUsageIdentifier: cardinal;
    rgpszUsageIdentifier: PPAnsiCharArray;
  end;
  PCERT_ENHKEY_USAGE = ^CTL_USAGE;

const
  UNISP_NAME = 'Microsoft Unified Security Protocol Provider';

  SP_PROT_TLS1          = $0C0;
  SP_PROT_TLS1_SERVER   = $040;
  SP_PROT_TLS1_CLIENT   = $080;
  SP_PROT_TLS1_1        = $300;
  SP_PROT_TLS1_1_SERVER = $100;
  SP_PROT_TLS1_1_CLIENT = $200;
  SP_PROT_TLS1_2        = $C00;
  SP_PROT_TLS1_2_SERVER = $400;
  SP_PROT_TLS1_2_CLIENT = $800;
  SP_PROT_TLS1_3        = $3000; // Windows Server 2022 ;)
  SP_PROT_TLS1_3_SERVER = $1000;
  SP_PROT_TLS1_3_CLIENT = $2000;

  PKCS12_INCLUDE_EXTENDED_PROPERTIES = $10;

  CERT_FIND_ANY = 0;

  // no check is made to determine whether memory for contexts remains allocated
  CERT_CLOSE_STORE_DEFAULT = 0;
  // force freeing all contexts associated with the store
  CERT_CLOSE_STORE_FORCE_FLAG = 1;
  // checks for nonfreed certificate, CRL, and CTL context to report an error on leak
  CERT_CLOSE_STORE_CHECK_FLAG = 2;

  CRYPT_ASN_ENCODING  = $00000001;
  CRYPT_NDR_ENCODING  = $00000002;
  X509_ASN_ENCODING   = $00000001;
  X509_NDR_ENCODING   = $00000002;
  PKCS_7_ASN_ENCODING = $00010000;
  PKCS_7_NDR_ENCODING = $00020000;
                                          // TCryptCertUsage mormot.crypt.secure
  CERT_OFFLINE_CRL_SIGN_KEY_USAGE  = $02; // cuCrlSign
  CERT_KEY_CERT_SIGN_KEY_USAGE     = $04; // cuKeyCertSign
  CERT_KEY_AGREEMENT_KEY_USAGE     = $08; // cuKeyAgreement
  CERT_DATA_ENCIPHERMENT_KEY_USAGE = $10; // cuDataEncipherment
  CERT_KEY_ENCIPHERMENT_KEY_USAGE  = $20; // cuKeyEncipherment
  CERT_NON_REPUDIATION_KEY_USAGE   = $40; // cuNonRepudiation
  CERT_DIGITAL_SIGNATURE_KEY_USAGE = $80; // cuDigitalSignature

  CERT_KEY_PROV_INFO_PROP_ID = 2;
  CERT_HASH_PROP_ID          = 3;
  CERT_FRIENDLY_NAME_PROP_ID = 11;

  CERT_SIMPLE_NAME_STR = 1;
  CERT_OID_NAME_STR    = 2;
  CERT_X500_NAME_STR   = 3;

  CRYPT_OID_INFO_OID_KEY   = 1;


// crypt32.dll API calls

function CertOpenStoreW(lpszStoreProvider: PWideChar; dwEncodingType: cardinal;
  hCryptProv: HCRYPTPROV; dwFlags: cardinal; pvPara: pointer): HCERTSTORE; stdcall;

function CertOpenSystemStoreW(hProv: HCRYPTPROV;
  szSubsystemProtocol: PWideChar): HCERTSTORE; stdcall;

function CertCloseStore(hCertStore: HCERTSTORE; dwFlags: cardinal): BOOL; stdcall;

function CertFindCertificateInStore(hCertStore: HCERTSTORE;
  dwCertEncodingType, dwFindFlags, dwFindType: cardinal; pvFindPara: pointer;
  pPrevCertContext: PCCERT_CONTEXT): PCCERT_CONTEXT; stdcall;

function PFXImportCertStore(pPFX: pointer; szPassword: PWideChar;
  dwFlags: cardinal): HCERTSTORE; stdcall;

function CertCreateCertificateContext(dwCertEncodingType: cardinal;
  pbCertEncoded: PByte; cbCertEncoded: cardinal): PCCERT_CONTEXT; stdcall;

function CertGetIntendedKeyUsage(dwCertEncodingType: cardinal; pCertInfo: PCERT_INFO;
  pbKeyUsage: PByte; cbKeyUsage: cardinal): BOOL; stdcall;

function CertGetEnhancedKeyUsage(pCertContext: PCCERT_CONTEXT; dwFlags: cardinal;
  pUsage: PCERT_ENHKEY_USAGE; var pcbUsage: cardinal): BOOL; stdcall;

function CertGetCertificateContextProperty(pCertContext: PCCERT_CONTEXT;
  dwPropId: cardinal; pvData: pointer; var pcbData: cardinal): BOOL; stdcall;

function CertFreeCertificateContext(pCertContext: PCCERT_CONTEXT): BOOL; stdcall;

function CertNameToStrW(dwCertEncodingType: cardinal; var pName: CERT_NAME_BLOB;
  dwStrType: cardinal; psz: PWideChar; csz: cardinal): cardinal; stdcall;

function CryptFindOIDInfo(dwKeyType: cardinal; pvKey: pointer;
  dwGroupId: cardinal): PCRYPT_OID_INFO; stdcall;


{ ****************** Middle-Level SSPI Wrappers }


type
  /// exception class raised during SSPI process
  ESynSspi = class(ExceptionWithProps)
  public
    constructor CreateLastOSError(const aContext: TSecContext);
  end;


/// set aSecHandle fields to empty state for a given connection ID
procedure InvalidateSecContext(var aSecContext: TSecContext;
  aConnectionID: Int64);

/// free aSecContext on client or server side
procedure FreeSecContext(var aSecContext: TSecContext);

/// Encrypts a message using 'sign and seal' (i.e. integrity and encryption)
// - aSecContext must be set e.g. from previous success call to ServerSspiAuth
// or ClientSspiAuth
// - aPlain contains data that must be encrypted
// - returns encrypted message
function SecEncrypt(var aSecContext: TSecContext;
  const aPlain: RawByteString): RawByteString;

/// decrypt a message
// - aSecContext must be set e.g. from previous success call to ServerSspiAuth
// or ClientSspiAuth
// - aEncrypted contains data that must be decrypted
// - returns decrypted message
// - warning: aEncrypted is modified in-place during the process
function SecDecrypt(var aSecContext: TSecContext;
  var aEncrypted: RawByteString): RawByteString;

/// retrieve the connection information text of a given TLS connection
function TlsConnectionInfo(var Ctxt: TCtxtHandle): RawUtf8;

type
  /// each possible key usage of a certificate, as decoded into TWinCertInfo
  // - match TCryptCertUsage from mormot.crypt.secure
  TWinCertUsage = (
    wkuCA,
    wkuEncipherOnly,
    wkuCrlSign,
    wkuKeyCertSign,
    wkuKeyAgreement,
    wkuDataEncipherment,
    wkuKeyEncipherment,
    wkuNonRepudiation,
    wkuDigitalSignature,
    wkuDecipherOnly,
    wkuTlsServer,
    wkuTlsClient,
    wkuEmail,
    wkuCodeSign,
    wkuOcspSign,
    wkuTimestamp);

  /// the key usages of a certificate, as decoded into TWinCertInfo
  // - match 16-bit TCryptCertUsages from mormot.crypt.secure
  TWinCertUsages = set of TWinCertUsage;

  /// a X509 certificate extension, as decoded into TWinCertInfo.Extension
  TWinCertExtension = record
    /// the OID of this extension
    OID: RawUtf8;
    /// if this extension was marked as "critical"
    Critical: boolean;
    /// the extension data, stored as 'xx:xx:xx:xx...' hexa text
    Value: RawUtf8;
  end;
  PWinCertExtension = ^TWinCertExtension;

  /// decoded information about a X509 certificate as returned by WinCertDecode
  TWinCertInfo = record
    /// the certificate Serial Number, stored as 'xx:xx:xx:xx...' hexa text
    Serial: RawUtf8;
    /// the main key usages of this certificate
    // - match 16-bit TCryptCertUsages from mormot.crypt.secure
    Usage: TWinCertUsages;
    /// the friendly name of this certificate
    // - will try subject CN= O= then CERT_FRIENDLY_NAME_PROP_ID property
    Name: RawUtf8;
    /// the certificate Issuer, decoded as RFC 1779 text, with X500 key names
    // - contains e.g. 'C=FR, O=Certplus, CN=Class 3P Primary CA'
    // - you can use ExtractX500() to retrieve one actual field value
    IssuerName: RawUtf8;
    /// the certificate Subject, decoded as RFC 1779 text, with X500 key names
    // - contains e.g. 'C=FR, O=Certplus, CN=Class 3P Primary CA'
    // - you can use ExtractX500() to retrieve one actual field value
    SubjectName: RawUtf8;
    /// the certificate Issuer ID, stored as 'xx:xx:xx:xx...' hexa text
    IssuerID: RawUtf8;
    /// the certificate Subject ID, stored as 'xx:xx:xx:xx...' hexa text
    SubjectID: RawUtf8;
    /// the certificate validity start date
    NotBefore: TDateTime;
    /// the certificate validity end date
    NotAfter: TDateTime;
    /// the certificate algorithm, as OID text
    // - e.g. '1.2.840.113549.1.1.5' for 'sha1RSA' AlgorithmName
    Algorithm: RawUtf8;
    /// the certificate algorithm name, as converted by WinCertAlgoName()
    // - typical values are 'md5RSA','sha1RSA','sha256RSA','sha384RSA','sha1ECC'
    AlgorithmName: RawUtf8;
    /// the certificate binary SHA1 fingerprint of 20 bytes
    Hash: RawUtf8;
    /// the certificate public key algorithm, as OID text
    // - e.g. ' 1.2.840.113549.1.1.1' for 'RSA' PublicKeyAlgorithmName
    PublicKeyAlgorithm: RawUtf8;
    /// the certificate public key algorithm name, converted by WinCertAlgoName()
    // - is most likely 'RSA', but could be e.g. 'ECC'
    PublicKeyAlgorithmName: RawUtf8;
    /// the certificate public key ASN1 raw binary as stored in the certificate
    // - for 'RSA', is a SEQUENCE of the two exponent + modulus INTEGER
    // - for 'ECC', is a BITSTRING with a $04 leading byte - see e.g. the
    // Ecc256r1CompressAsn1() decoder from mormot.crypt.ecc256r1.pas
    PublicKeyContent: RawByteString;
    /// the key container name
    KeyContainer: RawUtf8;
    /// the key container provider name
    KeyProvider: RawUtf8;
    /// the X509 extensions of this certificate
    Extension: array of TWinCertExtension;
  end;

const
  WIN_CERT_USAGE: array[wkuCrlSign .. wkuDigitalSignature] of byte = (
    CERT_OFFLINE_CRL_SIGN_KEY_USAGE,    // wkuCrlSign
    CERT_KEY_CERT_SIGN_KEY_USAGE,       // wkuKeyCertSign
    CERT_KEY_AGREEMENT_KEY_USAGE,       // wkuKeyAgreement
    CERT_DATA_ENCIPHERMENT_KEY_USAGE,   // wkuDataEncipherment
    CERT_KEY_ENCIPHERMENT_KEY_USAGE,    // wkuKeyEncipherment
    CERT_NON_REPUDIATION_KEY_USAGE,     // wkuNonRepudiation
    CERT_DIGITAL_SIGNATURE_KEY_USAGE);  // wkuDigitalSignature

/// return the whole algorithm name from a OID text
procedure WinCertAlgoName(OID: PAnsiChar; out Text: RawUtf8);

/// decode a CERT_NAME_BLOB binary blob into RFC 1779 text, with X500 key names
procedure WinCertName(var Name: CERT_NAME_BLOB; out Text: RawUtf8;
  StrType: cardinal = CERT_X500_NAME_STR);

/// decode an ASN-1 binary X509 certificate information using the WinCrypto API
function WinCertDecode(const Asn1: RawByteString; out Cert: TWinCertInfo;
  StrType: cardinal = CERT_X500_NAME_STR): boolean;

/// decode a raw WinCrypto API PCCERT_CONTEXT struct
function WinCertCtxtDecode(Ctxt: PCCERT_CONTEXT; out Cert: TWinCertInfo;
  StrType: cardinal = CERT_X500_NAME_STR): boolean;

/// could be used to extract CERT_X500_NAME_STR values
// - for instance, in TWinCertInfo Name := ExtractX500('CN=', SubjectName);
function ExtractX500(const Pattern, Text: RawUtf8): RawUtf8;

/// retrieve the end certificate information of a given TLS connection
function TlsCertInfo(var Ctxt: TCtxtHandle; out Info: TWinCertInfo): boolean;

/// return some multi-line text of the main TWinCertInfo fields
// - in a layout similar to X509_print() OpenSSL formatting
// - fully implemented by mormot.crypt.secure - a cut-down version is set by
// this unit
var
  WinCertInfoToText: function(const c: TWinCertInfo): RawUtf8;


{ ****************** High-Level Client and Server Authentication using SSPI }

/// client-side authentication procedure
// - aSecContext holds information between function calls
// - aInData contains data received from server
// - aSecKerberosSpn is the optional SPN domain name, e.g.
// 'mymormotservice/myserver.mydomain.tld'
// - aOutData contains data that must be sent to server
// - if function returns True, client must send aOutData to server
// and call function again with the data returned from servsr
function ClientSspiAuth(var aSecContext: TSecContext;
  const aInData: RawByteString; const aSecKerberosSpn: RawUtf8;
  out aOutData: RawByteString): boolean;

/// client-side authentication procedure with clear text password
//  - this function must be used when application need to use different
// user credentials (not credentials of logged-in user)
// - aSecContext holds information between function calls
// - aInData contains data received from server
// - aUserName is the domain and user name, in form of 'DomainName\UserName' -
// if no DomainName is set, it will be extracted from aSecKerberosSpn
// - aPassword is the user clear text password
// - aOutData contains data that must be sent to server
// - if function returns True, client must send aOutData to server
// and call function again with the data returned from server
function ClientSspiAuthWithPassword(var aSecContext: TSecContext;
  const aInData: RawByteString; const aUserName: RawUtf8;
  const aPassword: SpiUtf8;  const aSecKerberosSpn: RawUtf8;
  out aOutData: RawByteString): boolean;

/// server-side authentication procedure
// - aSecContext holds information between function calls
// - aInData contains data recieved from client
// - aOutData contains data that must be sent to client
// - if this function returns True, server must send aOutData to client
// and call function again with the data returned from client
function ServerSspiAuth(var aSecContext: TSecContext;
  const aInData: RawByteString; out aOutData: RawByteString): boolean;

/// Server-side function that returns authenticated user name
// - aSecContext must be received from a previous successful call to
// ServerSspiAuth()
// - aUserName contains authenticated user name
procedure ServerSspiAuthUser(var aSecContext: TSecContext;
  out aUserName: RawUtf8);

/// return the name of the security package that has been used
// during the negotiation process
// - aSecContext must be received from previous successful call to
// ServerSspiAuth() or ClientSspiAuth()
function SecPackageName(var aSecContext: TSecContext): RawUtf8;

/// force using a Kerberos SPN for server identification
// - aSecKerberosSpn is the Service Principal Name, as registered in domain,
// e.g. 'mymormotservice/myserver.mydomain.tld@MYDOMAIN.TLD'
procedure ClientForceSpn(const aSecKerberosSpn: RawUtf8);

/// high-level cross-platform initialization function
// - as called e.g. by mormot.rest.client/server.pas or mormot.net.client/ldap
function InitializeDomainAuth: boolean;


const
  /// character used as marker in user name to indicates the associated domain
  SSPI_USER_CHAR = '\';

var
  /// HTTP Challenge name for SSPI authentication, typically 'Negotiate'
  // - as computed by InitializeDomainAuth
  // - set SspiForceNtlmClient to specialize this value to 'NTLM' or 'Negotiate'
  SECPKGNAMEHTTP: RawUtf8;

  /// HTTP Challenge name, converted into uppercase for IdemPChar() pattern
  // - as computed by InitializeDomainAuth
  SECPKGNAMEHTTP_UPPER: RawUtf8;

  /// HTTP header to be set for SSPI authentication
  // - as computed by InitializeDomainAuth
  // - set SspiForceNtlmClient to specialize this value to either
  // 'WWW-Authenticate: NTLM' or 'WWW-Authenticate: Negotiate';
  SECPKGNAMEHTTPWWWAUTHENTICATE: RawUtf8;

  /// HTTP header pattern received for SSPI authentication
  // - as computed by InitializeDomainAuth
  // - set SspiForceNtlmClient to specialize this value to either
  // 'AUTHORIZATION: NTLM ' or 'AUTHORIZATION: NEGOTIATE '
  SECPKGNAMEHTTPAUTHORIZATION: RawUtf8;

  /// by default, this unit will use Negotiate/Kerberos for client authentication
  // - set this flag should be set BEFORE calling InitializeDomainAuth
  // - can be set to TRUE to use the deprecated and unsafe NTLM protocol instead
  // - use case: SPNs not configured properly in domain
  // - see for details https://synopse.info/forum/viewtopic.php?id=931&p=3
  SspiForceNtlmClient: boolean = false;


{ ****************** Lan Manager Access Functions }

// netapi32.dll API calls

const
  netapi32 = 'netapi32.dll';

  MAX_PREFERRED_LENGTH = cardinal(-1);
  LG_INCLUDE_INDIRECT = 1;
  NERR_Success = 0;

type
  TNetApiStatus = cardinal;

  // _USER_INFO_0, _LOCALGROUP_MEMBERS_INFO_3 and _LOCALGROUP_INFO_0 do match
  TGroupInfo0 = record
    name: PWideChar;
  end;
  PGroupInfo0 = ^TGroupInfo0;
  TGroupInfo0Array = array[0..MaxInt div SizeOf(TGroupInfo0) - 1] of TGroupInfo0;
  PGroupInfo0Array = ^TGroupInfo0Array;

  TGroupInfo1 = record
    name: PWideChar;
    comment: PWideChar;
  end;
  PGroupInfo1 = ^TGroupInfo1;

  TGroupInfo3 = record
    name: PWideChar;
    comment: PWideChar;
    group_sid: PSid;
    attributes: cardinal;
  end;
  PGroupInfo3 = ^TGroupInfo3;

function NetApiBufferAllocate(ByteCount: cardinal;
  var Buffer: pointer): TNetApiStatus; stdcall;

function NetApiBufferFree(Buffer: pointer): TNetApiStatus; stdcall;

function NetApiBufferReallocate(OldBuffer: pointer; NewByteCount: cardinal;
  var NewBuffer: pointer): TNetApiStatus; stdcall;

function NetApiBufferSize(Buffer: pointer;
  var ByteCount: cardinal): TNetApiStatus; stdcall;


function NetUserAdd(servername: PWideChar; level: cardinal;
  buf: PByte; parm_err: PCardinal): TNetApiStatus; stdcall;

function NetUserEnum(servername: PWideChar; level, filter: cardinal;
  var bufptr: pointer; prefmaxlen: cardinal;
  entriesread, totalentries: PCardinal;
  resumehandle: PPCardinal = nil): TNetApiStatus; stdcall;

function NetUserGetInfo(servername, username: PWideChar; level: cardinal;
  var bufptr: pointer): TNetApiStatus; stdcall;

function NetUserSetInfo(servername, username: PWideChar; level: cardinal;
  buf: pointer; parm_err: PCardinal): TNetApiStatus; stdcall;

function NetUserDel(servername: PWideChar; username: PWideChar): TNetApiStatus; stdcall;

function NetUserGetGroups(servername, username: PWideChar; level: cardinal;
  var bufptr: pointer; prefmaxlen: cardinal;
  entriesread, totalentries: PCardinal): TNetApiStatus; stdcall;

function NetUserSetGroups(servername, username: PWideChar; level: cardinal;
  buf: pointer; num_entries: cardinal): TNetApiStatus; stdcall;

function NetUserGetLocalGroups(servername, username: PWideChar;
  level, flags: cardinal; var bufptr: pointer; prefmaxlen: cardinal;
  entriesread, totalentries: PCardinal): TNetApiStatus; stdcall;

function NetUserModalsGet(servername: PWideChar; level: cardinal;
  var bufptr: pointer): TNetApiStatus; stdcall;

function NetUserModalsSet(servername: PWideChar; level: cardinal;
  buf: pointer; parm_err: PCardinal): TNetApiStatus; stdcall;

function NetUserChangePassword(domainname, username,
  oldpassword, newpassword: PWideChar): TNetApiStatus; stdcall;


function NetGroupEnum(servername: PWideChar; level: cardinal;
  var bufptr: pointer; prefmaxlen: cardinal; entriesread, totalentries: PCardinal;
  resume_handle: PPCardinal = nil): TNetApiStatus; stdcall;


function NetLocalGroupAdd(servername: PWideChar; level: cardinal;
  buf: pointer; parm_err: PCardinal): TNetApiStatus; stdcall;

function NetLocalGroupAddMember(servername, groupname: PWideChar;
  membersid: PSID): TNetApiStatus; stdcall;

function NetLocalGroupEnum(servername: PWideChar; level: cardinal;
  var bufptr: pointer; prefmaxlen: cardinal; entriesread, totalentries: PCardinal;
  resumehandle: PPCardinal = nil): TNetApiStatus; stdcall;

function NetLocalGroupGetInfo(servername, groupname: PWideChar;
  level: cardinal; var bufptr: pointer): TNetApiStatus; stdcall;

function NetLocalGroupSetInfo(servername, groupname: PWideChar;
  level: cardinal; buf: pointer; parm_err: PCardinal): TNetApiStatus; stdcall;

function NetLocalGroupDel(servername: PWideChar;
  groupname: PWideChar): TNetApiStatus; stdcall;

function NetLocalGroupDelMember(servername: PWideChar;
  groupname: PWideChar; membersid: PSID): TNetApiStatus; stdcall;

function NetLocalGroupGetMembers(servername, localgroupname: PWideChar;
  level: cardinal; var bufptr: pointer; prefmaxlen: cardinal;
  entriesread, totalentries: PCardinal; resumehandle: PPCardinal): TNetApiStatus; stdcall;

function NetLocalGroupSetMembers(servername, groupname: PWideChar;
  level: cardinal; buf: pointer; totalentries: cardinal): TNetApiStatus; stdcall;

function NetLocalGroupAddMembers(servername, groupname: PWideChar;
  level: cardinal; buf: pointer; totalentries: cardinal): TNetApiStatus; stdcall;

function NetLocalGroupDelMembers(servername, groupname: PWideChar;
  level: cardinal; buf: pointer; totalentries: cardinal): TNetApiStatus; stdcall;


/// retrieves global group names to which a specified user belongs
// - server is the DNS or NetBIOS name of the remote server to query (typically
// '\\MyDomainNameDns') - if server is '', the local computer is used
// - user is typically 'user.name' or 'DOMAIN\user.name'
// - call NetUserGetGroups() unless Local is true for NetUserGetLocalGroups()
// - will return only the groups explicitly assigned to the user, not the
// nested groups assigned to other local groups
function GetGroups(const server, user: RawUtf8;
  Local: boolean = false): TRawUtf8DynArray; overload;

/// retrieve information about each global group names on a given server
// - server is the DNS or NetBIOS name of the remote server to query (typically
// '\\MyDomainNameDns') - if server is '', the local computer is used
// - call NetGroupEnum() API
// - return the group names, and optionally the associated SID text
function GetGroups(const server: RawUtf8; sid: PRawUtf8DynArray = nil;
  Local: boolean = false): TRawUtf8DynArray; overload;

/// retrieve the textual SID of a group name on a given server
// - server is the DNS or NetBIOS name of the remote server to query (typically
// '\\MyDomainNameDns') - if server is '', the local computer is used
// - call NetGroupEnum() API then filter for the first supplied GroupName
function GetGroupSid(const Server, GroupName: RawUtf8;
  Local: boolean = false): RawUtf8;

type
  TGetUsersFilterAccount = set of (
    gufTempDuplicate,
    gufNormal,
    gufProxyAccount,
    gufInterdomainTrust,
    gufWorkstationTrust,
    gufServerTrust);

///  retrieves information about all user accounts on a server
// - server is the DNS or NetBIOS name of the remote server to query (typically
// '\\MyDomainNameDns') - if server is '', the local computer is used
// - call NetUserEnum()
function GetUsers(const server: RawUtf8 = '';
  filter: TGetUsersFilterAccount = []): TRawUtf8DynArray;

/// retrieves local group names to which the current user belongs
// - call NetLocalGroupEnum()
function GetLocalGroups(const server: RawUtf8 = ''): TRawUtf8DynArray;

/// retrieves a list of the members of a particular local group
// - server is the DNS or NetBIOS name of the remote server to query (typically
// '\\MyDomainNameDns') - if server is '', the local computer is used
// - return the account and domain names of the local group member
// - call NetLocalGroupGetMembers()
function GetLocalGroupMembers(const server, group: RawUtf8): TRawUtf8DynArray;


implementation


{ ****************** Low-Level SSPI/SChannel Functions }

function SspiResToText(res: cardinal): TShort31;
begin
  case res of
    SEC_E_OK:
      result := 'SEC_E_OK';
    SEC_I_CONTINUE_NEEDED:
      result := 'SEC_I_CONTINUE_NEEDED';
    SEC_I_CONTEXT_EXPIRED:
      result := 'SEC_I_CONTEXT_EXPIRED';
    SEC_I_INCOMPLETE_CREDENTIALS:
      result := 'SEC_I_INCOMPLETE_CREDENTIALS';
    SEC_I_RENEGOTIATE:
      result := 'SEC_I_RENEGOTIATE';
    SEC_E_INCOMPLETE_MESSAGE:
      result := 'SEC_E_INCOMPLETE_MESSAGE';
    SEC_E_INVALID_TOKEN:
      result := 'SEC_E_INVALID_TOKEN';
    SEC_E_ILLEGAL_MESSAGE:
      result := 'SEC_E_ILLEGAL_MESSAGE';
    SEC_E_CERT_UNKNOWN:
      result := 'SEC_E_CERT_UNKNOWN';
    SEC_E_CERT_EXPIRED:
      result := 'SEC_E_CERT_EXPIRED';
    SEC_E_ALGORITHM_MISMATCH:
      result := 'SEC_E_ALGORITHM_MISMATCH';
    SEC_E_UNSUPPORTED_FUNCTION:
      result := 'SEC_E_UNSUPPORTED_FUNCTION';
    SEC_E_MESSAGE_ALTERED:
      result := 'SEC_E_MESSAGE_ALTERED';
    SEC_E_BUFFER_TOO_SMALL:
      result := 'SEC_E_BUFFER_TOO_SMALL';
  else
    str(res, result);
  end;
end;


const
  secur32 = 'secur32.dll';

function QuerySecurityPackageInfoW;  external secur32;
function AcquireCredentialsHandleW;  external secur32;
function InitializeSecurityContextW; external secur32;
function AcceptSecurityContext;      external secur32;
function CompleteAuthToken;          external secur32;
function QueryContextAttributesW;    external secur32;
function ApplyControlToken;          external secur32;
function QuerySecurityContextToken;  external secur32;
function EncryptMessage;             external secur32;
function DecryptMessage;             external secur32;
function FreeContextBuffer;          external secur32;
function DeleteSecurityContext;      external secur32;
function FreeCredentialsHandle;      external secur32;

const
  crypt32 = 'crypt32.dll';

function CertOpenStoreW;                    external crypt32;
function CertOpenSystemStoreW;              external crypt32;
function CertCloseStore;                    external crypt32;
function CertFindCertificateInStore;        external crypt32;
function PFXImportCertStore;                external crypt32;
function CertCreateCertificateContext;      external crypt32;
function CertGetIntendedKeyUsage;           external crypt32;
function CertGetEnhancedKeyUsage;           external crypt32;
function CertGetCertificateContextProperty; external crypt32;
function CertFreeCertificateContext;        external crypt32;
function CertNameToStrW;                    external crypt32;
function CryptFindOIDInfo;                  external crypt32;


{ TSecBuffer }

procedure TSecBuffer.Init(aType: cardinal; aData: pointer;
  aSize: cardinal);
begin
  BufferType := aType;
  pvBuffer := aData;
  cbBuffer := aSize;
end;


{ TSecBufferDesc }

procedure TSecBufferDesc.Init(aVersion: cardinal; aBuffers: PSecBuffer;
  aBuffersCount: cardinal);
begin
  ulVersion := aVersion;
  pBuffers := aBuffers;
  cBuffers := aBuffersCount;
end;


{ TSecPkgConnectionInfo }

procedure FixProtocol(var dwProtocol: cardinal);
begin
  if dwProtocol and SP_PROT_TLS1 <> 0 then
    dwProtocol := 0
  else if dwProtocol and SP_PROT_TLS1_1 <> 0 then
    dwProtocol := 1
  else if dwProtocol and SP_PROT_TLS1_2 <> 0 then
    dwProtocol := 2
  else if dwProtocol and SP_PROT_TLS1_3 <> 0 then
    dwProtocol := 3;
end;

function TSecPkgConnectionInfo.ToText: RawUtf8;
var
  h: byte;
  alg, hsh, xch: string[5];
begin
  FixProtocol(dwProtocol);
  if aiCipher and $1f in [14..17] then
    alg := 'AES'
  else if aiCipher = $6801 then
    alg := 'RC4-'
  else
    str(aiCipher and $1f, alg);
  h := aiHash and $1f;
  case h of
    1..2:
      hsh := 'MD';
    3:
      hsh := 'MD5-';
    4, 12..14:
      begin
        hsh := 'SHA';
        if dwHashStrength = 0 then
          case h of
            4:
              dwHashStrength := 1;
            12:
              dwHashStrength := 256;
            13:
              dwHashStrength := 384;
            14:
              dwHashStrength := 512;
          end;
      end;
    9:
      hsh := 'HMAC';
  else
    str(h, hsh);
  end;
  if (aiExch = $a400) or
     (aiExch = $2400) then
    xch := 'RSA'
  else if aiExch = $aa02 then
    xch := 'DH'
  else if aiExch = $aa05 then
    xch := 'ECDH'
  else if aiExch = $ae06 then
    xch := 'ECDHE'
  else if aiExch = $2203 then
    xch := 'ECDSA'
  else
    str(aiExch, xch);
  result := RawUtf8(format('%s%d-%s%d-%s%d TLSv1.%d ',
    [xch, dwExchStrength, alg, dwCipherStrength, hsh, dwHashStrength, dwProtocol]));
end;



{ ****************** Middle-Level SSPI Wrappers }

{ ESynSspi }

constructor ESynSspi.CreateLastOSError(const aContext: TSecContext);
var
  error: integer;
begin
  error := GetLastError;
  CreateFmt('SSPI API Error %x [%s] for ConnectionID=%d',
    [error, string(GetErrorText(error)), aContext.ID]);
end;


procedure InvalidateSecContext(var aSecContext: TSecContext;
  aConnectionID: Int64);
begin
  aSecContext.ID := aConnectionID;
  aSecContext.CredHandle.dwLower := -1;
  aSecContext.CredHandle.dwUpper := -1;
  aSecContext.CtxHandle.dwLower := -1;
  aSecContext.CtxHandle.dwUpper := -1;
  aSecContext.CreatedTick64 := 0;
end;

procedure FreeSecurityContext(var handle: TSecHandle);
begin
  if (handle.dwLower <> -1) or
     (handle.dwUpper <> -1) then
  begin
    DeleteSecurityContext(@handle);
    handle.dwLower := -1;
    handle.dwUpper := -1;
  end;
end;

procedure FreeCredentialsContext(var handle: TSecHandle);
begin
  if (handle.dwLower <> -1) or
     (handle.dwUpper <> -1) then
  begin
    FreeCredentialsHandle(@handle);
    handle.dwLower := -1;
    handle.dwUpper := -1;
  end;
end;

procedure FreeSecContext(var aSecContext: TSecContext);
begin
  FreeSecurityContext(aSecContext.CtxHandle);
  FreeCredentialsContext(aSecContext.CredHandle);
end;

function SecEncrypt(var aSecContext: TSecContext;
  const aPlain: RawByteString): RawByteString;
var
  Sizes: TSecPkgContext_Sizes;
  SrcLen, EncLen: cardinal;
  Token: array [0..127] of byte; // Usually 60 bytes
  Padding: array [0..63] of byte; // Usually 1 byte
  InBuf: array[0..2] of TSecBuffer;
  InDesc: TSecBufferDesc;
  EncBuffer: RawByteString;
  Status: integer;
  BufPtr: PByte;
begin
  result := '';
  // Sizes.cbSecurityTrailer is size of the trailer (signature + padding) block
  if QueryContextAttributesW(
       @aSecContext.CtxHandle, SECPKG_ATTR_SIZES, @Sizes) <> 0 then
    raise ESynSspi.CreateLastOSError(aSecContext);
  if (Sizes.cbSecurityTrailer > SizeOf(Token)) or
     (Sizes.cbBlockSize > SizeOf(Padding)) then
    raise ESynSspi.Create('SecEncrypt: invalid ATTR_SIZES');
  // Encrypted data buffer structure:
  //
  // SSPI/Kerberos Interoperability with GSSAPI
  // https://msdn.microsoft.com/library/windows/desktop/aa380496.aspx
  // https://learn.microsoft.com/en-us/windows/win32/secauthn/sspi-kerberos-interoperability-with-gssapi
  //
  // GSS-API wrapper for Microsoft's Kerberos SSPI in Windows 2000
  // http://www.kerberos.org/software/samples/gsskrb5/gsskrb5/krb5/krb5msg.c
  //
  //   cbSecurityTrailer bytes   SrcLen bytes     cbBlockSize bytes or less
  //   (60 bytes)                                 (0 bytes, not used)
  // +-------------------------+----------------+--------------------------+
  // | Trailer                 | Data           | Padding                  |
  // +-------------------------+----------------+--------------------------+
  {%H-}InBuf[0].Init(SECBUFFER_TOKEN, @Token[0], Sizes.cbSecurityTrailer);
  // Encoding done in-place, so we copy the data
  SrcLen := Length(aPlain);
  FastSetRawByteString(EncBuffer, pointer(aPlain), SrcLen);
  InBuf[1].Init(SECBUFFER_DATA, pointer(EncBuffer), SrcLen);
  InBuf[2].Init(SECBUFFER_PADDING, @Padding[0], Sizes.cbBlockSize);
  {%H-}InDesc.Init(SECBUFFER_VERSION, @InBuf, 3);
  Status := EncryptMessage(@aSecContext.CtxHandle, 0, @InDesc, 0);
  if Status < 0 then
    raise ESynSspi.CreateLastOSError(aSecContext);
  EncLen := InBuf[0].cbBuffer + InBuf[1].cbBuffer + InBuf[2].cbBuffer;
  SetLength(result, EncLen);
  BufPtr := pointer(result);
  MoveFast(PByte(InBuf[0].pvBuffer)^, BufPtr^, InBuf[0].cbBuffer);
  Inc(BufPtr, InBuf[0].cbBuffer);
  MoveFast(PByte(InBuf[1].pvBuffer)^, BufPtr^, InBuf[1].cbBuffer);
  Inc(BufPtr, InBuf[1].cbBuffer);
  MoveFast(PByte(InBuf[2].pvBuffer)^, BufPtr^, InBuf[2].cbBuffer);
end;

function SecDecrypt(var aSecContext: TSecContext;
  var aEncrypted: RawByteString): RawByteString;
var
  EncLen, SigLen: cardinal;
  BufPtr: PByte;
  InBuf: array [0..1] of TSecBuffer;
  InDesc: TSecBufferDesc;
  Status: integer;
  QOP: cardinal;
begin
  EncLen := Length(aEncrypted);
  BufPtr := PByte(aEncrypted);
  if EncLen < SizeOf(cardinal) then
  begin
    SetLastError(ERROR_INVALID_PARAMETER);
    raise ESynSspi.CreateLastOSError(aSecContext);
  end;
  // Hack for compatibility with previous versions.
  // Should be removed in future.
  // Old version buffer format - first 4 bytes is Trailer length, skip it.
  // 16 bytes for NTLM and 60 bytes for Kerberos
  SigLen := PCardinal(BufPtr)^;
  if (SigLen = 16) or
     (SigLen = 60) then
  begin
    Inc(BufPtr, SizeOf(cardinal));
    Dec(EncLen, SizeOf(cardinal));
  end;
  {%H-}InBuf[0].Init(SECBUFFER_STREAM, BufPtr, EncLen);
  InBuf[1].Init(SECBUFFER_DATA, nil, 0);
  {%H-}InDesc.Init(SECBUFFER_VERSION, @InBuf, 2);
  Status := DecryptMessage(@aSecContext.CtxHandle, @InDesc, 0, QOP);
  if Status < 0 then
    raise ESynSspi.CreateLastOSError(aSecContext);
  FastSetRawByteString(result, InBuf[1].pvBuffer, InBuf[1].cbBuffer);
end;

function TlsConnectionInfo(var Ctxt: TCtxtHandle): RawUtf8;
var
  nfo: TSecPkgConnectionInfo;
  cip: TSecPkgCipherInfo; // Vista+ attribute
begin
  result := '';
  FillCharFast(nfo, SizeOf(nfo), 0);
  if QueryContextAttributesW(
      @Ctxt, SECPKG_ATTR_CONNECTION_INFO, @nfo) <> SEC_E_OK then
    exit;
  FillCharFast(cip, SizeOf(cip), 0);
  cip.dwVersion := SECPKGCONTEXT_CIPHERINFO_V1;
  if (OSVersion >= wVista) and
     (QueryContextAttributesW(
        @Ctxt, SECPKG_ATTR_CIPHER_INFO, @cip) = SEC_E_OK) and
     (cip.szCipherSuite[0] <> #0) then
  begin
    FixProtocol(nfo.dwProtocol); // cip.dwProtocol seems incorrect :(
    result := RawUtf8(format('%s TLSv1.%d ',
      [PWideChar(@cip.szCipherSuite), nfo.dwProtocol]));
  end
  else
    result := nfo.ToText; // fallback on XP
end;

function TlsCertInfo(var Ctxt: TCtxtHandle; out Info: TWinCertInfo): boolean;
var
  nfo: PCCERT_CONTEXT;
begin
  result := false;
  nfo := nil;
  if QueryContextAttributesW(
      @Ctxt, SECPKG_ATTR_REMOTE_CERT_CONTEXT, @nfo) <> SEC_E_OK then
    exit;
  result := WinCertCtxtDecode(nfo, Info);
  CertFreeCertificateContext(nfo);
end;

const
  RSA_PREFIX: PAnsiChar = '1.2.840.113549.1.1.'; // len=19
  ECC_PREFIX: PAnsiChar = '1.2.840.10045.';      // len=14
  ENU_PREFIX: PAnsiChar = '1.3.6.1.5.5.7.3.';    // len=16

procedure WinCertAlgoName(OID: PAnsiChar; out Text: RawUtf8);
var
  nfo: PCRYPT_OID_INFO;
begin
  nfo := CryptFindOIDInfo(CRYPT_OID_INFO_OID_KEY, OID, 0);
  if nfo <> nil then
    Win32PWideCharToUtf8(nfo^.pwszName, Text)
  else if OID <> nil then
    // minimal decoding fallback for Windows XP
    if CompareMemSmall(OID, RSA_PREFIX, 19) then
    begin
      inc(OID, 19);
      if StrComp(OID, PAnsiChar('4'#0)) = 0 then
        Text := 'md5RSA'
      else if StrComp(OID, PAnsiChar('5'#0)) = 0 then
        Text := 'sha1RSA'
      else if StrComp(OID, PAnsiChar('11')) = 0 then
        Text := 'sha256RSA'
      else if StrComp(OID, PAnsiChar('12')) = 0 then
        Text := 'sha384RSA'
      else if StrComp(OID, PAnsiChar('13')) = 0 then
        Text := 'sha512RSA'
      else if StrComp(OID, PAnsiChar('14')) = 0 then
        Text := 'sha224RSA'
      else
        Text := 'RSA';
    end
    else if CompareMemSmall(OID, ECC_PREFIX, 14) then
    begin
      inc(OID, 14);
      if StrComp(OID, PAnsiChar('4.1')) = 0 then
        Text := 'sha1ECDSA'
      else if StrComp(OID, PAnsiChar('4.2')) = 0 then
        Text := 'sha2ECDSA'
      else
        Text := 'ECC';
    end;
end;

procedure WinCertName(var Name: CERT_NAME_BLOB; out Text: RawUtf8;
  StrType: cardinal);
var
  len: PtrInt;
  tmp: TSynTempBuffer;
begin
  len := CertNameToStrW(X509_ASN_ENCODING, Name, StrType, nil, 0);
  len := CertNameToStrW(X509_ASN_ENCODING, Name, StrType, tmp.Init(len), len);
  Win32PWideCharToUtf8(tmp.buf, len - 1, Text);
  tmp.Done;
end;

function WinCertDecode(const Asn1: RawByteString; out Cert: TWinCertInfo;
  StrType: cardinal): boolean;
var
  ctx: PCCERT_CONTEXT;
begin
  result := false;
  ctx := CertCreateCertificateContext(
    X509_ASN_ENCODING or PKCS_7_ASN_ENCODING, pointer(Asn1), length(Asn1));
  if ctx = nil then
    exit; // caller may use GetLastError
  result := WinCertCtxtDecode(ctx, Cert, StrType);
  CertFreeCertificateContext(ctx);
end;

function ExtractX500(const Pattern, Text: RawUtf8): RawUtf8;
var
  i, j, o: PtrInt;
  t: RawUtf8;
begin
  result := '';
  o := 1;
  repeat
    i := PosEx(Pattern, Text, o);
    if i = 0 then
      exit;
    o := i + 1;
  until (i = 1) or
        (Text[i - 1] in [',', ' ']);
  inc(i, length(Pattern));
  t := Text;
  if t[i] = '"' then
  begin
    inc(i);
    o := i;
    repeat
      j := PosEx('"', t, o);
      if (j = 0) or
         (t[j + 1] <> '"') then
        break;
      delete(t, j, 1); // "" -> "
      o := j + 1;
    until false;
  end
  else
    j := PosEx(',', t, i);
  if j = 0 then
    j := 1000;
  TrimCopy(t, i, j - i, result);
end;

const
  WIN_CERT_EXT: array[wkuTlsServer..wkuTimestamp] of PAnsiChar = (
    '1',  // wkuTlsServer
    '2',  // wkuTlsClient
    '4',  // wkuEmail
    '3',  // wkuCodeSign
    '9',  // wkuOcspSign
    '8'); // wkuTimestamp

function WinCertCtxtDecode(Ctxt: PCCERT_CONTEXT; out Cert: TWinCertInfo;
  StrType: cardinal): boolean;
var
  nfo: PCERT_INFO;
  i, o: PtrInt;
  oid: PAnsiChar;
  ku: byte;
  u: TWinCertUsage;
  len: cardinal;
  sub: RawUtf8;
  h: THash160;
  tmp: TSynTempBuffer;
begin
  result := false;
  if Ctxt = nil then
    exit;
  Finalize(Cert);
  FillcharFast(Cert, SizeOf(Cert), 0);
  nfo := Ctxt^.pCertInfo;
  with nfo^.SerialNumber do
    ToHumanHexReverse(Cert.Serial, pbData, cbData);
  ku := 0;
  if CertGetIntendedKeyUsage(X509_ASN_ENCODING, nfo, @ku, SizeOf(ku)) then
    for u := low(WIN_CERT_USAGE) to high(WIN_CERT_USAGE) do
      if ku and WIN_CERT_USAGE[u] <> 0 then
        include(Cert.Usage, u);
  len := {%H-}tmp.Init;
  if CertGetEnhancedKeyUsage(Ctxt, 0, tmp.buf, len) then
    with PCERT_ENHKEY_USAGE(tmp.buf)^ do
      for i := 0 to integer(cUsageIdentifier) - 1 do
      begin
        oid := rgpszUsageIdentifier[i];
        if not CompareMemSmall(oid, ENU_PREFIX, 16) then
          continue;
        inc(oid, 16);
        for u := low(WIN_CERT_EXT) to high(WIN_CERT_EXT) do
          if StrComp(oid, WIN_CERT_EXT[u]) = 0 then
            include(Cert.Usage, u);
      end;
  WinCertName(nfo^.Issuer, Cert.IssuerName, StrType);
  WinCertName(nfo^.Subject, Cert.SubjectName, StrType);
  if StrType = CERT_X500_NAME_STR then
    sub := Cert.SubjectName // we already have the expected layout
  else
    WinCertName(nfo^.Subject, sub, CERT_X500_NAME_STR);
  Cert.Name := ExtractX500('CN=', sub);
  if Cert.Name = '' then
    Cert.Name := ExtractX500('O=', sub);
  if Cert.Name = '' then
  begin
    len := tmp.Init;
    if CertGetCertificateContextProperty(
        Ctxt, CERT_FRIENDLY_NAME_PROP_ID, tmp.buf, len) then
      Win32PWideCharToUtf8(tmp.buf, Cert.Name);
  end;
  with nfo^.IssuerUniqueId do
    ToHumanHex(Cert.IssuerID, pbData, cbData);
  with nfo^.SubjectUniqueId do
    ToHumanHex(Cert.SubjectID, pbData, cbData);
  Cert.NotBefore := FileTimeToDateTime(nfo^.NotBefore);
  Cert.NotAfter  := FileTimeToDateTime(nfo^.NotAfter);
  Cert.Algorithm := nfo^.SignatureAlgorithm.pszObjId;
  WinCertAlgoName(nfo^.SignatureAlgorithm.pszObjId, Cert.AlgorithmName);
  Cert.PublicKeyAlgorithm := nfo^.SubjectPublicKeyInfo.Algorithm.pszObjId;
  WinCertAlgoName(nfo^.SubjectPublicKeyInfo.Algorithm.pszObjId,
    Cert.PublicKeyAlgorithmName);
  with nfo^.SubjectPublicKeyInfo.PublicKey do
    FastSetRawByteString(Cert.PublicKeyContent, pbData, cbData);
  len := tmp.Init;
  if CertGetCertificateContextProperty(
       Ctxt, CERT_KEY_PROV_INFO_PROP_ID, tmp.buf, len) then
    with PCRYPT_KEY_PROV_INFO(tmp.buf)^ do
    begin
      Win32PWideCharToUtf8(pwszContainerName, Cert.KeyContainer);
      Win32PWideCharToUtf8(pwszProvName, Cert.KeyProvider);
    end;
  len := SizeOf(h); // 20 bytes of a SHA-1 hash
  if CertGetCertificateContextProperty(Ctxt, CERT_HASH_PROP_ID, @h, len) then
    ToHumanHex(Cert.Hash, @h, len);
  SetLength(Cert.Extension, nfo^.cExtension);
  for i := 0 to integer(nfo^.cExtension) - 1 do
    with nfo^.rgExtension[i],
         Cert.Extension[i] do
    begin
      OID := pszObjId;
      Critical := fCritical;
      ToHumanHex(Value, Blob.pbData, Blob.cbData);
      if (OID = '2.5.29.19') and
         (PosEx('01:ff', Value) <> 0) then
        include(Cert.Usage, wkuCA) // X509v3 Basic Constraints: CA:TRUE
      else if (Cert.SubjectID = '') and
              (OID = '2.5.29.14') and
              (copy(Value, 1, 6) = '04:14:') then
        Cert.SubjectID := copy(Value, 7, 2000) // rough parsing of 20-byte IDs
      else if (Cert.IssuerID = '') and
              (OID = '2.5.29.35') and // authorityKeyIdentifier
              (length(Value) > 60) then
      begin
        o := PosEx('80:14:', Value); // rough detection of 20-byte IDs
        if o <> 0 then
          Cert.IssuerID := copy(Value, o + 6, 59);
      end;
    end;
  result := true;
end;

function _WinCertInfoToText(const c: TWinCertInfo): RawUtf8;
begin
  // roughly follow X509_print() OpenSSL formatting with basic fields only
  result :=
    'Certificate:'#13#10 +
    '  Serial Number:'#13#10 +
    '    ' + c.Serial + #13#10 +
    '  Signature Algorithm: ' + c.AlgorithmName + #13#10 +
    '  Issuer: ' + c.IssuerName + #13#10 +
    '  Validity:'#13#10 +
    '    Not Before: ' + RawUtf8(DateTimeToIsoString(c.NotBefore)) + #13#10 +
    '    Not After : ' + RawUtf8(DateTimeToIsoString(c.NotAfter)) + #13#10 +
    '  Subject: ' + c.SubjectName + #13#10 +
    '  Subject Public Key Info:'#13#10 +
    '    Public Key Algorithm: ' + c.PublicKeyAlgorithmName + #13#10 +
    '    OID: ' + c.PublicKeyAlgorithm + #13#10;
  // known extensions will be properly written by mormot.crypt.secure code
end;


{ ****************** High-Level Client and Server Authentication using SSPI }

var
  ForceSecKerberosSpn: SynUnicode;
  NtlmName, NegotiateName: SynUnicode;

function ClientSspiAuthWorker(var aSecContext: TSecContext;
  const aInData: RawByteString; pszTargetName: PWideChar;
  pAuthData: PSecWinntAuthIdentityW;
  out aOutData: RawByteString): boolean;
var
  InBuf: TSecBuffer;
  InDesc: TSecBufferDesc;
  LInCtxPtr: PSecHandle;
  OutBuf: TSecBuffer;
  OutDesc: TSecBufferDesc;
  CtxReqAttr: cardinal;
  CtxAttr: cardinal;
  Status: Integer;
begin
  InBuf.BufferType := SECBUFFER_TOKEN;
  InBuf.cbBuffer := Length(aInData);
  InBuf.pvBuffer := PByte(aInData);
  InDesc.ulVersion := SECBUFFER_VERSION;
  InDesc.pBuffers := @InBuf;
  if (aSecContext.CredHandle.dwLower = -1) and
     (aSecContext.CredHandle.dwUpper = -1) then
  begin
    aSecContext.CreatedTick64 := mormot.core.os.GetTickCount64;
    if AcquireCredentialsHandleW(nil, pointer(NegotiateName), SECPKG_CRED_OUTBOUND,
        nil, pAuthData, nil, nil, @aSecContext.CredHandle, nil) <> 0 then
      raise ESynSspi.CreateLastOSError(aSecContext);
    InDesc.cBuffers := 0;
    LInCtxPtr := nil;
  end
  else
  begin
    InDesc.cBuffers := 1;
    LInCtxPtr := @aSecContext.CtxHandle;
  end;
  CtxReqAttr := ISC_REQ_ALLOCATE_MEMORY or
                ISC_REQ_CONFIDENTIALITY or
                ISC_REQ_INTEGRITY;
  if pszTargetName <> nil then
    CtxReqAttr := CtxReqAttr or ISC_REQ_MUTUAL_AUTH;
  OutBuf.BufferType := SECBUFFER_TOKEN;
  OutBuf.cbBuffer := 0;
  OutBuf.pvBuffer := nil;
  OutDesc.ulVersion := SECBUFFER_VERSION;
  OutDesc.cBuffers := 1;
  OutDesc.pBuffers := @OutBuf;
  Status := InitializeSecurityContextW(@aSecContext.CredHandle, LInCtxPtr,
    pszTargetName, CtxReqAttr, 0, SECURITY_NATIVE_DREP, @InDesc, 0,
    @aSecContext.CtxHandle, @OutDesc, CtxAttr, nil);
  result := (Status = SEC_I_CONTINUE_NEEDED) or
            (Status = SEC_I_COMPLETE_AND_CONTINUE);
  if (Status = SEC_I_COMPLETE_NEEDED) or
     (Status = SEC_I_COMPLETE_AND_CONTINUE) then
    Status := CompleteAuthToken(@aSecContext.CtxHandle, @OutDesc);
  if Status < 0 then
    raise ESynSspi.CreateLastOSError(aSecContext);
  FastSetRawByteString(aOutData, OutBuf.pvBuffer, OutBuf.cbBuffer);
  FreeContextBuffer(OutBuf.pvBuffer);
end;

function ClientSspiAuth(var aSecContext: TSecContext;
  const aInData: RawByteString; const aSecKerberosSpn: RawUtf8;
  out aOutData: RawByteString): boolean;
var
  TargetName: PWideChar;
begin
  if aSecKerberosSpn <> '' then
    TargetName := pointer(SynUnicode(aSecKerberosSpn))
  else
    TargetName := pointer(ForceSecKerberosSpn);
  result :=  ClientSspiAuthWorker(
    aSecContext, aInData, TargetName, nil, aOutData);
end;

function ClientSspiAuthWithPassword(var aSecContext: TSecContext;
  const aInData: RawByteString; const aUserName: RawUtf8;
  const aPassword: SpiUtf8;  const aSecKerberosSpn: RawUtf8;
  out aOutData: RawByteString): boolean;
var
  UserPos, TargetPos: Integer;
  Domain, User, Password: SynUnicode;
  AuthIdentity: TSecWinntAuthIdentityW;
  TargetName: PWideChar;
  TargetUtf8: RawUtf8;
begin
  if aSecKerberosSpn <> '' then
    TargetName := pointer(SynUnicode(aSecKerberosSpn))
  else
    TargetName := pointer(ForceSecKerberosSpn);
  UserPos := PosExChar('\', aUserName);
  if UserPos = 0 then
  begin
    if TargetName <> nil then
    begin
      // extract from 'mymormotservice/myserver.mydomain.tld@MYDOMAIN.TLD'
      TargetUtf8 := RawUtf8(TargetName);
      TargetPos := PosExChar('@', TargetUtf8);
      if TargetPos <> 0 then
        Domain := SynUnicode(copy(TargetUtf8, TargetPos + 1, 100));
      // Domain is required, otherwise deprecated NTLM is used
    end;
    User := SynUnicode(aUserName);
  end
  else
  begin
    Domain := SynUnicode(Copy(aUserName, 1, UserPos - 1));
    User := SynUnicode(Copy(aUserName, UserPos + 1, MaxInt));
  end;
  PassWord := SynUnicode(aPassword);
  FillCharFast(AuthIdentity, SizeOf(AuthIdentity), 0);
  AuthIdentity.Domain := pointer(Domain);
  AuthIdentity.DomainLength := Length(Domain);
  AuthIdentity.User := pointer(User);
  AuthIdentity.UserLength := Length(User);
  AuthIdentity.Password := pointer(Password);
  AuthIdentity.PasswordLength := Length(Password);
  AuthIdentity.Flags := SEC_WINNT_AUTH_IDENTITY_UNICODE;
  result := ClientSspiAuthWorker(
    aSecContext, aInData, TargetName, @AuthIdentity, aOutData);
  //FillCharFast(pointer(Password)^, length(Password) * 2, 0); // anti-forensic
end;

function ServerSspiAuth(var aSecContext: TSecContext;
  const aInData: RawByteString; out aOutData: RawByteString): boolean;
var
  InBuf: TSecBuffer;
  InDesc: TSecBufferDesc;
  PkgName: PWideChar;
  LInCtxPtr: PSecHandle;
  OutBuf: TSecBuffer;
  OutDesc: TSecBufferDesc;
  CtxAttr: cardinal;
  Status: Integer;
begin
  InBuf.BufferType := SECBUFFER_TOKEN;
  InBuf.cbBuffer := Length(aInData);
  InBuf.pvBuffer := PByte(aInData);
  InDesc.ulVersion := SECBUFFER_VERSION;
  InDesc.cBuffers := 1;
  InDesc.pBuffers := @InBuf;
  if (aSecContext.CredHandle.dwLower = -1) and
     (aSecContext.CredHandle.dwUpper = -1) then
  begin
    aSecContext.CreatedTick64 := mormot.core.os.GetTickCount64;
    if (aInData <> '') and
       (PCardinal(aInData)^ or $20202020 =
        ord('n') + ord('t') shl 8 + ord('l') shl 16 + ord('m') shl 24) then
      PkgName := pointer(NtlmName) // backward compatible but unsafe/legacy
    else
      PkgName := pointer(NegotiateName);
    if AcquireCredentialsHandleW(nil, PkgName, SECPKG_CRED_INBOUND,
        nil, nil, nil, nil, @aSecContext.CredHandle, nil) <> 0 then
      raise ESynSspi.CreateLastOSError(aSecContext);
    LInCtxPtr := nil;
  end
  else
    LInCtxPtr := @aSecContext.CtxHandle;
  OutBuf.BufferType := SECBUFFER_TOKEN;
  OutBuf.cbBuffer := 0;
  OutBuf.pvBuffer := nil;
  OutDesc.ulVersion := SECBUFFER_VERSION;
  OutDesc.cBuffers := 1;
  OutDesc.pBuffers := @OutBuf;
  Status := AcceptSecurityContext(@aSecContext.CredHandle, LInCtxPtr, @InDesc,
      ASC_REQ_ALLOCATE_MEMORY or ASC_REQ_CONFIDENTIALITY,
      SECURITY_NATIVE_DREP, @aSecContext.CtxHandle, @OutDesc, CtxAttr, nil);
  result := (Status = SEC_I_CONTINUE_NEEDED) or
            (Status = SEC_I_COMPLETE_AND_CONTINUE);
  if (Status = SEC_I_COMPLETE_NEEDED) or
     (Status = SEC_I_COMPLETE_AND_CONTINUE) then
    Status := CompleteAuthToken(@aSecContext.CtxHandle, @OutDesc);
  if Status < 0 then
      raise ESynSspi.CreateLastOSError(aSecContext);
  FastSetRawByteString(aOutData, OutBuf.pvBuffer, OutBuf.cbBuffer);
  FreeContextBuffer(OutBuf.pvBuffer);
end;

procedure ServerSspiAuthUser(var aSecContext: TSecContext;
  out aUserName: RawUtf8);
var
  Names: SecPkgContext_NamesW;
begin
  if QueryContextAttributesW(@aSecContext.CtxHandle,
       SECPKG_ATTR_NAMES, @Names) <> 0 then
    raise ESynSspi.CreateLastOSError(aSecContext);
  Win32PWideCharToUtf8(Names.sUserName, aUserName);
  FreeContextBuffer(Names.sUserName);
end;

function SecPackageName(var aSecContext: TSecContext): RawUtf8;
var
  NegotiationInfo: TSecPkgContext_NegotiationInfo;
begin
  if QueryContextAttributesW(@aSecContext.CtxHandle,
       SECPKG_ATTR_NEGOTIATION_INFO, @NegotiationInfo) <> 0 then
    raise ESynSspi.CreateLastOSError(aSecContext);
  Win32PWideCharToUtf8(NegotiationInfo.PackageInfo^.Name, result);
  FreeContextBuffer(NegotiationInfo.PackageInfo);
end;

procedure ClientForceSpn(const aSecKerberosSpn: RawUtf8);
begin
  ForceSecKerberosSpn := SynUnicode(aSecKerberosSpn);
end;

var
  DomainAuthMode: (damUndefined, damNtlm, damNegotiate);

procedure SetDomainAuthMode;
var
  SecPkgInfo: PSecPkgInfoW;
begin
  if SspiForceNtlmClient then
  begin
    SECPKGNAMEHTTP := 'NTLM';
    SECPKGNAMEHTTP_UPPER := 'NTLM';
    DomainAuthMode := damNtlm;
  end
  else
  begin
    SECPKGNAMEHTTP := 'Negotiate';
    SECPKGNAMEHTTP_UPPER := 'NEGOTIATE';
    DomainAuthMode := damNegotiate;
  end;
  SECPKGNAMEHTTPWWWAUTHENTICATE := 'WWW-Authenticate: ' + SECPKGNAMEHTTP;
  SECPKGNAMEHTTPAUTHORIZATION := 'AUTHORIZATION: ' + SECPKGNAMEHTTP_UPPER + ' ';
  // resolve security package names once at startup
  if NtlmName = '' then
  begin
    if QuerySecurityPackageInfoW('NTLM', SecPkgInfo) = 0 then
    begin
      NtlmName := SecPkgInfo^.Name;
      FreeContextBuffer(SecPkgInfo);
    end;
    if QuerySecurityPackageInfoW('Negotiate', SecPkgInfo) = 0 then
    begin
      NegotiateName := SecPkgInfo^.Name;
      FreeContextBuffer(SecPkgInfo);
    end;
  end;
end;

function InitializeDomainAuth: boolean;
begin
  // setup the security package to be used
  if (DomainAuthMode = damUndefined) or
     (SspiForceNtlmClient <> (DomainAuthMode = damNtlm)) then
    SetDomainAuthMode;
  // SSPI comes from standard secur32.dll so is always available
  result := true;
end;



{ ****************** Lan Manager Access Functions }

function NetApiBufferAllocate;    external netapi32;
function NetApiBufferFree;        external netapi32;
function NetApiBufferReallocate;  external netapi32;
function NetApiBufferSize;        external netapi32;

function NetUserAdd;              external netapi32;
function NetUserEnum;             external netapi32;
function NetUserGetInfo;          external netapi32;
function NetUserSetInfo;          external netapi32;
function NetUserDel;              external netapi32;
function NetUserGetGroups;        external netapi32;
function NetUserSetGroups;        external netapi32;
function NetUserGetLocalGroups;   external netapi32;
function NetUserModalsGet;        external netapi32;
function NetUserModalsSet;        external netapi32;
function NetUserChangePassword;   external netapi32;

function NetGroupEnum;            external netapi32;

function NetLocalGroupAdd;        external netapi32;
function NetLocalGroupAddMember;  external netapi32;
function NetLocalGroupEnum;       external netapi32;
function NetLocalGroupGetInfo;    external netapi32;
function NetLocalGroupSetInfo;    external netapi32;
function NetLocalGroupDel;        external netapi32;
function NetLocalGroupDelMember;  external netapi32;
function NetLocalGroupGetMembers; external netapi32;
function NetLocalGroupSetMembers; external netapi32;
function NetLocalGroupAddMembers; external netapi32;
function NetLocalGroupDelMembers; external netapi32;

procedure GetNames(g: PGroupInfo0Array; n: integer; var res: TRawUtf8DynArray);
var
  i: PtrInt;
begin
  if n > 0 then
  begin
    SetLength(res, n);
    for i := 0 to high(res) do
      Win32PWideCharToUtf8(g[i].name, res[i]);
  end;
  NetAPIBufferFree(g);
end;

function GetGroups(const server, user: RawUtf8; Local: boolean): TRawUtf8DynArray;
var
  dwEntriesRead, dwEntriesTotal: cardinal;
  v: pointer;
  s, u: PWideChar;
  res: integer;
  srv, usr: TSynTempBuffer;
begin
  result := nil;
  s := Utf8ToWin32PWideChar(server, srv);
  u := Utf8ToWin32PWideChar(user, usr);
  if Local then
    res := NetUserGetLocalGroups(s, u, 0, LG_INCLUDE_INDIRECT,
      v, MAX_PREFERRED_LENGTH, @dwEntriesRead, @dwEntriesTotal)
  else
    res := NetUserGetGroups(s, u, 0,
      v, MAX_PREFERRED_LENGTH, @dwEntriesRead, @dwEntriesTotal);
  if res = NERR_SUCCESS then
    GetNames(v, dwEntriesRead, result);
  srv.Done;
  usr.Done;
end;

function GetUsers(const server: RawUtf8;
  filter: TGetUsersFilterAccount): TRawUtf8DynArray;
var
  dwEntriesRead, dwEntriesTotal: cardinal;
  v: pointer;
  srv: TSynTempBuffer;
begin
  result := nil;
  if NetUserEnum(Utf8ToWin32PWideChar(server, srv), 0, byte(filter), v,
      MAX_PREFERRED_LENGTH, @dwEntriesRead, @dwEntriesTotal) = NERR_Success then
    // note: _USER_INFO_0 and _LOCALGROUP_INFO_0 are identical
    GetNames(v, dwEntriesRead, result);
  srv.Done;
end;

function GetGroups(const server: RawUtf8;
  sid: PRawUtf8DynArray; Local: boolean): TRawUtf8DynArray;
var
  dwEntriesRead, dwEntriesTotal: cardinal;
  v: pointer;
  s: PWideChar;
  g: PGroupInfo3;
  i: PtrInt;
  res: integer;
  srv: TSynTempBuffer;
begin
  result := nil;
  s := Utf8ToWin32PWideChar(server, srv);
  if (sid = nil) or
     Local then // NetLocalGroupEnum() does not support level 3 
  begin
    if Local then
      res := NetLocalGroupEnum(s, {level=}0, v, MAX_PREFERRED_LENGTH,
          @dwEntriesRead, @dwEntriesTotal)
    else
      res := NetGroupEnum(s, {level=}0, v, MAX_PREFERRED_LENGTH,
        @dwEntriesRead, @dwEntriesTotal);
    if res = NERR_Success then
      GetNames(v, dwEntriesRead, result);
  end
  else
  begin
    res := NetGroupEnum(s, {level=}3, v, MAX_PREFERRED_LENGTH,
              @dwEntriesRead, @dwEntriesTotal);
    if res = NERR_Success then // returns ERROR_INVALID_LEVEL if unsupported
    begin
      g := v;
      SetLength(result, dwEntriesRead);
      SetLength(sid^, dwEntriesRead);
      for i := 0 to integer(dwEntriesRead) - 1 do
      begin
        Win32PWideCharToUtf8(g^.name, result[i]);
        sid^[i] := SidToText(g^.group_sid);
        inc(g);
      end;
      NetAPIBufferFree(v);
    end;
  end;
  srv.Done;
end;

function GetGroupSid(const Server, GroupName: RawUtf8; Local: boolean): RawUtf8;
var
  dwEntriesRead, dwEntriesTotal: cardinal;
  v: pointer;
  s: PWideChar;
  g: PGroupInfo3;
  res: integer;
  name: RawUtf8;
  srv: TSynTempBuffer;
begin
  result := '';
  if GroupName = '' then
    exit;
  s := Utf8ToWin32PWideChar(Server, srv);
  if Local then
    res := NetLocalGroupEnum(s, {level=}3, v, MAX_PREFERRED_LENGTH,
            @dwEntriesRead, @dwEntriesTotal)
  else
    res := NetGroupEnum(s, {level=}3, v, MAX_PREFERRED_LENGTH,
            @dwEntriesRead, @dwEntriesTotal);
  if res = NERR_Success then
  begin
    g := v;
    while dwEntriesRead <> 0 do
    begin
      Win32PWideCharToUtf8(g^.name, Name);
      if PropNameEquals(Name, GroupName) then
      begin
        result := SidToText(g^.group_sid);
        break;
      end;
      inc(g);
      dec(dwEntriesRead);
    end;
    NetAPIBufferFree(v);
  end;
  srv.Done;
end;

function GetLocalGroups(const server: RawUtf8): TRawUtf8DynArray;
var
  dwEntriesRead, dwEntriesTotal: cardinal;
  v: pointer;
  srv: TSynTempBuffer;
begin
  result := nil;
  if NetLocalGroupEnum(Utf8ToWin32PWideChar(server, srv), 0, v,
      MAX_PREFERRED_LENGTH, @dwEntriesRead, @dwEntriesTotal) = NERR_Success then
    GetNames(v, dwEntriesRead, result);
  srv.Done;
end;

function GetLocalGroupMembers(const server, group: RawUtf8): TRawUtf8DynArray;
var
  dwEntriesRead, dwEntriesTotal: cardinal;
  v: pointer;
  s, g: PWideChar;
  srv, grp: TSynTempBuffer;
begin
  result := nil;
  s := Utf8ToWin32PWideChar(server, srv);
  g := Utf8ToWin32PWideChar(group, grp);
  if NetLocalGroupGetMembers(s, g, 3, v, MAX_PREFERRED_LENGTH,
      @dwEntriesRead, @dwEntriesTotal, nil) = NERR_Success then
    // note: _LOCALGROUP_MEMBERS_INFO_3 and _LOCALGROUP_INFO_0 are identical
    GetNames(v, dwEntriesRead, result);
  srv.Done;
  grp.Done;
end;


initialization
  WinCertInfoToText := @_WinCertInfoToText;

finalization

{$endif OSPOSIX}

end.

