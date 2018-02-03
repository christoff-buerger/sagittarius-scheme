/* tls-win.c                                       -*- mode:c; coding:utf-8; -*-
 *
 *   Copyright (c) 2018  Takashi Kato <ktakashi@ymail.com>
 *
 *   Redistribution and use in source and binary forms, with or without
 *   modification, are permitted provided that the following conditions
 *   are met:
 *
 *   1. Redistributions of source code must retain the above copyright
 *      notice, this list of conditions and the following disclaimer.
 *
 *   2. Redistributions in binary form must reproduce the above copyright
 *      notice, this list of conditions and the following disclaimer in the
 *      documentation and/or other materials provided with the distribution.
 *
 *   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 *   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 *   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 *   A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 *   OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 *   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 *   TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 *   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 *   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 *   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 *   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/* 
References:
- https://msdn.microsoft.com/en-us/library/windows/desktop/aa375195(v=vs.85).aspx
 */

#ifndef UNICODE
# define UNICODE
#endif

#define SECURITY_WIN32
#ifndef __CYGWIN__
# include <winsock2.h>
#endif
#include <windows.h>
#include <wintrust.h>
#include <wincrypt.h>
#include <schannel.h>
#include <ncrypt.h>
/* #include <security.h> */
#include <sspi.h>
#include <sagittarius.h>
#include "sagittarius-socket.h"
#define LIBSAGITTARIUS_EXT_BODY
#include <sagittarius/extend.h>
#include "tls-socket.h"

#ifdef _MSC_VER
# pragma comment(lib, "crypt32.lib")
# pragma comment(lib, "secur32.lib")
# pragma comment(lib, "ncrypt.lib")
#endif

#ifndef max
# define max(a,b) (((a) > (b)) ? (a) : (b))
#endif
#ifndef min
# define min(a,b) (((a) < (b)) ? (a) : (b))
#endif

#include "raise_incl.incl"

#ifdef __CYGWIN__
static SgObject get_windows_last_error(int e)
{
#define MSG_SIZE 128
  wchar_t msg[MSG_SIZE];
  int size = FormatMessageW(FORMAT_MESSAGE_FROM_SYSTEM
			    | FORMAT_MESSAGE_IGNORE_INSERTS,
			    0, 
			    e,
			    MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
			    msg,
			    MSG_SIZE,
			    NULL);
  if (size > 2 && msg[size - 2] == '\r') {
    msg[size - 2] = 0;
    size -= 2;
  }
  return Sg_WCharTsToString(msg, size);
#undef MSG_SIZE
}
# define Sg_GetLastErrorMessageWithErrorCode get_windows_last_error
#endif

#define W_(x) L ## x
#define W(x) W_(x)

#ifdef USE_UCS4_CPP
static LPWSTR KEY_CONTAINER_NAME =
  L"Sagittarius " W(SAGITTARIUS_VERSION) L" SSL Socket Key Container";
static LPWSTR KEY_PROVIDER = MS_DEF_RSA_SCHANNEL_PROV;
#else
static LPWSTR KEY_CONTAINER_NAME = NULL;
static LPWSTR KEY_PROVIDER = NULL;
#endif

/* #define DEBUG_TLS_HANDLES */
#ifdef  DEBUG_TLS_HANDLES

#define fmt_dump(fmt, ...) fprintf(stderr, fmt, __VA_ARGS__)
#define msg_dump(msg) fputs(msg, stderr)

static void dump_ctx_handle(CtxtHandle *ctx)
{
  SECURITY_STATUS ss;
  SecPkgContext_ConnectionInfo ci;
  ss = QueryContextAttributes(ctx, SECPKG_ATTR_CONNECTION_INFO, (void *)&ci);
  if (FAILED(ss)) {
    msg_dump("Failed to QueryContextAttributes\n");
    return;
  }
  fmt_dump("Protocol: 0x%x\n", ci.dwProtocol);
  fmt_dump("Cipher: 0x%x\n", ci.aiCipher);
  fmt_dump("Cipher strength: %d\n", ci.dwCipherStrength);
}

static void dump_cred_handle(CredHandle *cred)
{
  SECURITY_STATUS ss;
  SecPkgCred_SupportedAlgs sa;
  SecPkgCred_SupportedProtocols sp;
  ss = QueryCredentialsAttributes(cred, SECPKG_ATTR_SUPPORTED_ALGS, (void *)&sa);
  if (!FAILED(ss)) {
    int i;
    fmt_dump("# of Supported algorithms %d\n", sa.cSupportedAlgs);
    for (i = 0; i < sa.cSupportedAlgs; i++) 
      fmt_dump("[%d] algorithm %x\n", i, sa.palgSupportedAlgs[i]);
  } else {
    SgObject msg = Sg_GetLastErrorMessageWithErrorCode(ss);
    fmt_dump("[%lx] %s\n", ss, Sg_Utf32sToUtf8s(SG_STRING(msg)));
  }
  ss = QueryCredentialsAttributes(cred, SECPKG_ATTR_SUPPORTED_PROTOCOLS, (void *)&sp);
  if (!FAILED(ss)) {
#define if_supported(v)							\
    do {								\
      if ((v&sp.grbitProtocol)==(v)) fmt_dump("Protocol: %s\n", #v);	\
    } while (0)
    
    if_supported(SP_PROT_TLS1_CLIENT);
    if_supported(SP_PROT_TLS1_SERVER);
    if_supported(SP_PROT_SSL3_CLIENT);
    if_supported(SP_PROT_SSL3_SERVER);
    if_supported(SP_PROT_SSL2_CLIENT);
    if_supported(SP_PROT_SSL2_SERVER);
#undef is_supported
  } else {
    SgObject msg = Sg_GetLastErrorMessageWithErrorCode(ss);
    fmt_dump("[%lx] %s\n", ss, Sg_Utf32sToUtf8s(SG_STRING(msg)));
  }
}

typedef BOOL (WINAPI *GetCryptProvFromCert)(HWND,
					    PCCERT_CONTEXT,
					    HCRYPTPROV *,
					    DWORD *,
					    BOOL *,
					    LPWSTR *,
					    LPWSTR *,
					    DWORD *);
typedef void (WINAPI *FreeCryptProvFromCert)(BOOL, HCRYPTPROV, LPWSTR, DWORD, LPWSTR);

static void dump_cert_context(PCCERT_CONTEXT cert)
{
  HCRYPTPROV prov;
  DWORD keySpec, provType, propId, cbData;
  LPWSTR container, provName;
  void *pvData;
  BOOL acquire = FALSE;
  HMODULE module = LoadLibraryA("mssign32.dll");
  if (module) {
    GetCryptProvFromCert getCryptProvFromCert =
      (GetCryptProvFromCert)GetProcAddress(module, "GetCryptProvFromCert");
    FreeCryptProvFromCert freeCryptProvFromCert =
      (FreeCryptProvFromCert)GetProcAddress(module, "FreeCryptProvFromCert");
    if (getCryptProvFromCert &&
	freeCryptProvFromCert &&
	getCryptProvFromCert(NULL, cert, &prov, &keySpec, &acquire,
			     &container, &provName, &provType)) {
      fmt_dump("Provider name: %S\n", provName);
      fmt_dump("Container name: %S\n", container);
      fmt_dump("Provider type: %ld\n", provType);
      fmt_dump("Key spec: %ld\n", keySpec);
      freeCryptProvFromCert(FALSE, prov, provName, provType, container);
    } else {
      fmt_dump("Failed to get key provider from cert: %lx\n", GetLastError());
    }
    FreeLibrary(module);
  }
  propId = 0;
  while (propId = CertEnumCertificateContextProperties(cert, propId)) {
    fmt_dump("Property # %d found\n  --> ", propId);
    switch(propId) {
    case CERT_FRIENDLY_NAME_PROP_ID:
      msg_dump("Display name: ");
      break;
    case CERT_SIGNATURE_HASH_PROP_ID:
      msg_dump("Signature hash identifier ");
      break;
    case CERT_KEY_PROV_HANDLE_PROP_ID:
      msg_dump("KEY PROV HANDLE.");
      break;
    case CERT_KEY_PROV_INFO_PROP_ID:
      msg_dump("KEY PROV INFO.");
      break;
    case CERT_SHA1_HASH_PROP_ID:
      msg_dump("SHA1 HASH identifier.");
      break;
    case CERT_MD5_HASH_PROP_ID:
      msg_dump("md5 hash identifier.");
      break;
    case CERT_KEY_CONTEXT_PROP_ID:
      msg_dump("KEY CONTEXT PROP identifier.");
      break;
    case CERT_KEY_SPEC_PROP_ID:
      msg_dump("KEY SPEC PROP identifier.");
      break;
    case CERT_ENHKEY_USAGE_PROP_ID:
      msg_dump("ENHKEY USAGE PROP identifier.");
      break;
    case CERT_NEXT_UPDATE_LOCATION_PROP_ID:
      msg_dump("NEXT UPDATE LOCATION PROP identifier.");
      break;
    case CERT_PVK_FILE_PROP_ID:
      msg_dump("PVK FILE PROP identifier.");
      break;
    case CERT_DESCRIPTION_PROP_ID:
      msg_dump("DESCRIPTION PROP identifier.");
      break;
    case CERT_ACCESS_STATE_PROP_ID:
      msg_dump("ACCESS STATE PROP identifier.");
      break;
    case CERT_SMART_CARD_DATA_PROP_ID:
      msg_dump("SMART_CARD DATA PROP identifier.");
      break;
    case CERT_EFS_PROP_ID:
      msg_dump("EFS PROP identifier.");
      break;
    case CERT_FORTEZZA_DATA_PROP_ID:
      msg_dump("FORTEZZA DATA PROP identifier.");
      break;
    case CERT_ARCHIVED_PROP_ID:
      msg_dump("ARCHIVED PROP identifier ");
      break;
    case CERT_KEY_IDENTIFIER_PROP_ID:
      msg_dump("KEY IDENTIFIER PROP identifier.");
      break;
    case CERT_AUTO_ENROLL_PROP_ID:
      msg_dump("AUTO ENROLL identifier.");
      break;
    default:
      msg_dump("Unknown identifier.");
      break;
    }
    if (CertGetCertificateContextProperty(cert, propId, NULL, &cbData)) {
      pvData = (void *)LocalAlloc(0, cbData);
      if (CertGetCertificateContextProperty(cert, propId, pvData, &cbData)) {
	if (propId == CERT_KEY_CONTEXT_PROP_ID) {
	  CERT_KEY_CONTEXT *keyCtx = (CERT_KEY_CONTEXT *)pvData;
	  msg_dump(" The property contents are\n");
	  fmt_dump("   - Key spec %d\n", keyCtx->dwKeySpec);
	  fmt_dump("   - Provider %p\n", keyCtx->hCryptProv);
	} else if (propId == CERT_KEY_PROV_INFO_PROP_ID) {
	  CRYPT_KEY_PROV_INFO *provInfo = (CRYPT_KEY_PROV_INFO *)pvData;
	  msg_dump(" The property contents are\n");
	  fmt_dump("   - Container name %S\n", provInfo->pwszContainerName);
	  fmt_dump("   - Provider name %S\n", provInfo->pwszProvName);
	  fmt_dump("   - Provider type %d\n", provInfo->dwProvType);
	  fmt_dump("   - Flags %d\n", provInfo->dwFlags);
	  fmt_dump("   - Key spec %d\n", provInfo->dwKeySpec);
	  fmt_dump("   - # of parameters %d\n", provInfo->cProvParam);
	} else {
	  fmt_dump(" The property content is %d\n", pvData);
	}
      }
      LocalFree(pvData);
    }
  }
}
#undef dump
#undef fmt_dump

# define DUMP_CTX_HANDLE(ctx) dump_ctx_handle(ctx)
# define DUMP_CRED_HANDLE(cred) dump_cred_handle(cred)
# define DUMP_CERT_CONTEXT(cert) dump_cert_context(cert)
#else
# define DUMP_CTX_HANDLE(ctx)
# define DUMP_CRED_HANDLE(cred)
# define DUMP_CERT_CONTEXT(cert)
#endif

typedef struct WinTLSContextRec
{
  /* we don't support CA/trusted certificates for now. */
  /* HCERTSTORE certStore; */
  int certificateCount;
  PCCERT_CONTEXT *certificates;
  HCRYPTKEY privateKey;
} WinTLSContext;

typedef struct WinTLSDataRec
{
  CredHandle credential;
  CtxtHandle context;
  int pendingSize;
  uint8_t *pendingData;
  int closed;
  WinTLSContext *tlsContext;
} WinTLSData;

/* #define IMPL_NAME UNISP_NAME_W */
#ifdef USE_UCS4_CPP
# define IMPL_NAME SCHANNEL_NAME_W
#else
static wchar_t *IMPL_NAME = NULL;
#endif

static void client_init(SgTLSSocket *r)
{
  SECURITY_STATUS status;
  SCHANNEL_CRED credData = {0};
  wchar_t *name = IMPL_NAME;
  WinTLSData *data = (WinTLSData *)r->data;
  WinTLSContext *context = data->tlsContext;
  
  data->credential.dwLower = 0;
  data->credential.dwUpper = 0;
  data->context.dwLower = 0;
  data->context.dwUpper = 0;
  data->pendingSize = 0;

  credData.dwVersion = SCHANNEL_CRED_VERSION;
  credData.dwFlags = SCH_CRED_NO_DEFAULT_CREDS |
    SCH_CRED_NO_SYSTEM_MAPPER |
    SCH_CRED_REVOCATION_CHECK_CHAIN;
  credData.cCreds = context->certificateCount;
  credData.paCred = context->certificates;
  
  status = AcquireCredentialsHandleW(NULL,
				     name,
				     SECPKG_CRED_OUTBOUND,
				     NULL,
				     &credData,
				     NULL,
				     NULL,
				     &data->credential,
				     NULL);
  DUMP_CRED_HANDLE(&data->credential);
  
  if (status != S_OK) {
    FreeCredentialsHandle(&data->credential);
    raise_socket_error(SG_INTERN("socket->tls-socket"),
		       Sg_GetLastErrorMessageWithErrorCode(status),
		       Sg_MakeConditionSocket(r),
		       Sg_MakeIntegerU(status));
  }
}

static void free_context(WinTLSContext *context)
{
  int i;
  for (i = 0; i < context->certificateCount; i++) {
    CertFreeCertificateContext(context->certificates[i]);
  }
  if (context->privateKey) {
    CryptDestroyKey(context->privateKey);
    context->privateKey = NULL;
  }
  context->certificateCount = 0;
  /* if (context->certStore) { */
  /*   CertCloseStore(context->certStore, 0); */
  /*   context->certStore = NULL; */
  /* } */
}

static void tls_socket_finalizer(SgObject self, void *data)
{
  Sg_TLSSocketClose(SG_TLS_SOCKET(self));
}

static void tls_context_finalize(SgObject self, void *data)
{
  WinTLSContext *context = (WinTLSContext *)self;
  free_context(context);
}

static SgTLSSocket * make_tls_socket(SgSocket *socket, WinTLSContext *ctx)
{
  SgTLSSocket *r = SG_NEW(SgTLSSocket);
  WinTLSData *data = SG_NEW(WinTLSData);
  WinTLSContext *context = ctx == NULL? SG_NEW(WinTLSContext) : ctx;
  SG_SET_CLASS(r, SG_CLASS_TLS_SOCKET);
  r->socket = socket;
  r->data = data;
  data->tlsContext = context;
  if (!ctx) {
    context->certificateCount = 0;
    context->privateKey = NULL;
    Sg_RegisterFinalizer(context, tls_context_finalize, NULL);
  }
  return r;
}

static void load_certificates(WinTLSData *data, SgObject certificates)
{
  
  int count = 0, len = Sg_Length(certificates);
  SgObject cp;
  WinTLSContext *context = data->tlsContext;
  context->certificateCount = len;
  context->certificates = SG_NEW_ARRAY(PCCERT_CONTEXT, len);
  SG_FOR_EACH(cp, certificates) {
    SgByteVector *cert;
    PCCERT_CONTEXT pcert;
    if (!SG_BVECTORP(SG_CAR(cp))) {
      Sg_AssertionViolation(SG_INTERN("socket->tls-socket"),
			    Sg_Sprintf(UC("bytevector required but got %S"),
				       SG_CAR(cp)),
			    certificates);
    }
    cert = SG_BVECTOR(SG_CAR(cp));
    pcert = CertCreateCertificateContext(X509_ASN_ENCODING |
					 PKCS_7_ASN_ENCODING,
					 SG_BVECTOR_ELEMENTS(cert),
					 SG_BVECTOR_SIZE(cert));
    if (!pcert) {
      SgObject msg = Sg_GetLastErrorMessageWithErrorCode(GetLastError());
      int i;
      for (i = 0; i < count; i++) {
	CertFreeCertificateContext(context->certificates[i]);
      }
      context->certificateCount = 0;
      Sg_AssertionViolation(SG_INTERN("socket->tls-socket"),
			    Sg_Sprintf(UC("Failed to load certificate: %A"),
				       msg),
			    cert);
    }
    context->certificates[count++] = pcert;
  }
}

static DWORD add_private_key(WinTLSData *data,
			     SgByteVector *privateKey)
{
  WinTLSContext *context = data->tlsContext;
  if (privateKey && context->certificateCount > 0) {
    PCCERT_CONTEXT ctx = context->certificates[0];
    HCRYPTPROV hProv = NULL;
    HCRYPTKEY c;
    CERT_KEY_CONTEXT keyCtx = {0};
    DWORD spec, cbKeyBlob;
    LPBYTE pbKeyBlob = NULL;
    BOOL callerFree;
    CRYPT_KEY_PROV_INFO provInfo;
    
    if (!CryptDecodeObjectEx(X509_ASN_ENCODING | PKCS_7_ASN_ENCODING,
			     PKCS_RSA_PRIVATE_KEY,
			     SG_BVECTOR_ELEMENTS(privateKey),
			     SG_BVECTOR_SIZE(privateKey),
			     0, NULL, NULL, &cbKeyBlob)) {
      return GetLastError();
    }
#ifdef HAVE_ALLOCA
    pbKeyBlob = (LPBYTE)alloca(cbKeyBlob);
#else
    pbKeyBlob = SG_NEW_ATOMIC2(LPBYTE, cbKeyBlob);
#endif    
    if (!CryptDecodeObjectEx(X509_ASN_ENCODING | PKCS_7_ASN_ENCODING,
			     PKCS_RSA_PRIVATE_KEY,
			     SG_BVECTOR_ELEMENTS(privateKey),
			     SG_BVECTOR_SIZE(privateKey),
			     CRYPT_DECODE_NOCOPY_FLAG,
			     NULL, pbKeyBlob, &cbKeyBlob)) {
      return GetLastError();
    }
    if (!CryptAcquireContext(&hProv,
			     KEY_CONTAINER_NAME,
			     KEY_PROVIDER,
			     PROV_RSA_SCHANNEL,
			     CRYPT_NEWKEYSET)) {
      if (NTE_EXISTS == GetLastError()) {
	if (!CryptAcquireContext(&hProv, KEY_CONTAINER_NAME,
				 KEY_PROVIDER, PROV_RSA_SCHANNEL, 0)) {
	  return GetLastError();
	}
      } else {
	return GetLastError();
      }
    }
    /* CryptSetProvParam(hProv, PP_DELETEKEY, NULL, 0); */
    if (!CryptImportKey(hProv, pbKeyBlob, cbKeyBlob,
			NULL, 0, &context->privateKey)) {
      CryptReleaseContext(hProv, 0);
      return GetLastError();
    }
    
    provInfo.pwszContainerName = KEY_CONTAINER_NAME;
    provInfo.pwszProvName = KEY_PROVIDER;
    provInfo.dwProvType = PROV_RSA_SCHANNEL;
    provInfo.dwFlags = CERT_SET_KEY_CONTEXT_PROP_ID;
    provInfo.dwKeySpec = AT_KEYEXCHANGE;
    provInfo.cProvParam = 0;
    if (!CertSetCertificateContextProperty(ctx, CERT_KEY_PROV_INFO_PROP_ID, 0,
					   (const void *)&provInfo)) {
      return GetLastError();
    }

    keyCtx.cbSize = sizeof(CERT_KEY_CONTEXT);
    keyCtx.hCryptProv = hProv;
    keyCtx.dwKeySpec = AT_KEYEXCHANGE;
    if (!CertSetCertificateContextProperty(ctx, CERT_KEY_CONTEXT_PROP_ID, 0,
					   (const void *)&keyCtx)) {
      CryptReleaseContext(hProv, 0);
      return GetLastError();
    }

    DUMP_CERT_CONTEXT(ctx);
    /* check */
    if (!CryptAcquireCertificatePrivateKey(ctx, 0, NULL,
					   &c, &spec, &callerFree)) {
      return GetLastError();
    }
    
    if (callerFree) {
      if (spec == CERT_NCRYPT_KEY_SPEC) NCryptFreeObject(c);
      else CryptReleaseContext(c, 0);
    }
    return S_OK;
  }
  return E_NOTIMPL;
}

#if 0
static HCERTSTORE create_cert_store(SgTLSSocket *s)
{
#if 1
  /* Using memory (should work) */
  return CertOpenStore(CERT_STORE_PROV_MEMORY, 0, NULL, 0, (const void *)NULL);
#else
  /* Using temporary file */
  SgObject dir = Sg_GetTemporaryDirectory();
  SgObject path = Sg_Sprintf(UC("%A\\%A"), dir,
			     Sg_MakeIntegerU((uintptr_t)s));
  wchar_t *p = Sg_StringToWCharTs(path);
  HANDLE handle = CreateFileW(p, GENERIC_READ | GENERIC_WRITE,
			      FILE_SHARE_READ | FILE_SHARE_WRITE, NULL,
			      CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
  CloseHandle(handle);
  return CertOpenStore(CERT_STORE_PROV_FILENAME_W,
		       X509_ASN_ENCODING | PKCS_7_ASN_ENCODING,
		       NULL, 0, p);
#endif
}
#endif

static int server_init(SgTLSSocket *s)
{
  /* WinTLSData *data = (WinTLSData *)s->data; */
  /* WinTLSContext *context = data->tlsContext; */
  /* context->certStore = create_cert_store(s); */
  /* if (!context->certStore) goto err; */
  /* if (context->certificateCount > 0) { */
  /*   int i; */
  /*   for (i = 0; i < context->certificateCount; i++) { */
  /*     if (!CertAddCertificateContextToStore(context->certStore, */
  /* 					    context->certificates[i], */
  /* 					    CERT_STORE_ADD_REPLACE_EXISTING, */
  /* 					    NULL)) { */
  /* 	CertCloseStore(context->certStore, 0); */
  /* 	context->certStore = NULL; */
  /* 	goto err; */
  /*     } */
  /*   } */
  /* } */
  return TRUE;
 /* err: */
 /*  free_context(context); */
 /*  Sg_UnregisterFinalizer(context); */
 /*  raise_socket_error(SG_INTERN("tls-socket-accept"), */
 /* 		     Sg_GetLastErrorMessageWithErrorCode(GetLastError()), */
 /* 		     Sg_MakeConditionSocket(s), */
 /* 		     s); */
 /*  return FALSE;		 */	/* dummy */
}

SgTLSSocket* Sg_SocketToTLSSocket(SgSocket *socket,
				  /* list of bytevectors */
				  SgObject certificates,
				  /* encoded private key */
				  SgByteVector *privateKey)
{
  SgTLSSocket *r = make_tls_socket(socket, NULL);
  WinTLSData *data = (WinTLSData *)r->data;
  int serverP = FALSE;
  DWORD result;
  
  load_certificates(data, certificates);
  result = add_private_key(data, privateKey);
  
  switch (socket->type) {
  case SG_SOCKET_CLIENT: client_init(r); break;
  case SG_SOCKET_SERVER: serverP = server_init(r); break;
  default:
    free_context(data->tlsContext);
    Sg_AssertionViolation(SG_INTERN("socket->tls-socket"),
      Sg_Sprintf(UC("Client or server socket is required but got %S"), socket),
      socket);
    return NULL;		/* dummy */
  }
  
  if (serverP && FAILED(result) && result != E_NOTIMPL) {
    Sg_TLSSocketClose(r);
    raise_socket_error(SG_INTERN("socket->tls-socket"),
		       Sg_GetLastErrorMessageWithErrorCode(result),
		       Sg_MakeConditionSocket(r),
		       Sg_MakeIntegerU(result));
  }
  Sg_RegisterFinalizer(r, tls_socket_finalizer, NULL);
  return r;
}

static int socket_readable(SOCKET socket)
{
  fd_set rfds;
  int total;
  struct timeval tv;
  FD_ZERO(&rfds);
  FD_SET(socket, &rfds);
  tv.tv_sec = 0;
#ifdef __CYGWIN__
  tv.tv_usec = 10;		/* wait a bit on Cygwin */
#else
  tv.tv_usec = 0;		/* seems okay like this */
#endif
  total = select(socket+1, &rfds, NULL, NULL, &tv);
  return total == 1;
}

int Sg_TLSSocketConnect(SgTLSSocket *tlsSocket)
{
  SgSocket *socket = tlsSocket->socket;
  SECURITY_STATUS ss = SEC_I_CONTINUE_NEEDED;
  WinTLSData *data = (WinTLSData *)tlsSocket->data;
  SecBufferDesc sbout, sbin;
  SecBuffer bufso, bufsi[2];
  wchar_t *dn;
  int initialised = FALSE, pt = 0;
  /* FIXME... */
  uint8_t t[0x10000];
  DWORD sspiFlags = ISC_REQ_MANUAL_CRED_VALIDATION |
    ISC_REQ_SEQUENCE_DETECT   |
    ISC_REQ_REPLAY_DETECT     |
    ISC_REQ_CONFIDENTIALITY   |
    ISC_RET_EXTENDED_ERROR    |
    ISC_REQ_ALLOCATE_MEMORY   |
    ISC_REQ_STREAM;

  dn = (SG_FALSEP(socket->node)) ? NULL : Sg_StringToWCharTs(socket->node);
  for (;;) {
    DWORD sspiOutFlags = 0;
    int rval;

    if (ss != SEC_I_CONTINUE_NEEDED &&
	ss != SEC_E_INCOMPLETE_MESSAGE &&
	ss != SEC_I_INCOMPLETE_CREDENTIALS)
      break;

    bufso.pvBuffer = NULL;
    bufso.BufferType = SECBUFFER_TOKEN;
    bufso.cbBuffer = 0;
    sbout.ulVersion = SECBUFFER_VERSION;
    sbout.cBuffers = 1;
    sbout.pBuffers = &bufso;
    if (initialised) {
      for (;;) {
	rval = Sg_SocketReceive(socket, t+pt, sizeof(t), 0);
	if (rval == 0 || rval == -1) {
	  raise_socket_error(SG_INTERN("tls-socket-connect!"),
			     SG_MAKE_STRING("Failed to receive handshake message"),
			     Sg_MakeConditionSocket(tlsSocket),
			     tlsSocket);
	}
	pt += rval;
	if (!socket_readable(socket->socket)) break;
      }
      bufsi[0].BufferType = SECBUFFER_TOKEN;
      bufsi[0].cbBuffer = pt;
      bufsi[0].pvBuffer = t;
      bufsi[1].BufferType = SECBUFFER_EMPTY;
      bufsi[1].cbBuffer = 0;
      bufsi[1].pvBuffer = NULL;
      sbin.ulVersion = SECBUFFER_VERSION;
      sbin.pBuffers = bufsi;
      sbin.cBuffers = 2;
    }

    ss = InitializeSecurityContextW(&data->credential,
				    initialised ? &data->context : NULL,
				    dn,
				    sspiFlags,
				    0,
				    0,
				    initialised ? &sbin : NULL,
				    0,
				    initialised ? NULL : &data->context,
				    &sbout,
				    &sspiOutFlags,
				    NULL);
    DUMP_CTX_HANDLE(&data->context);
    
    if (ss == SEC_E_INCOMPLETE_MESSAGE) continue;

    pt = 0;

    if (FAILED(ss) || (!initialised && ss != SEC_I_CONTINUE_NEEDED)) {
      raise_socket_error(SG_INTERN("tls-socket-connect!"),
			 Sg_GetLastErrorMessageWithErrorCode(ss),
			 Sg_MakeConditionSocket(tlsSocket),
			 Sg_MakeIntegerU(ss));
    }

    if (bufso.cbBuffer != 0 && bufso.pvBuffer != NULL) {
      /* send the data we got to the remote part */
      rval = Sg_SocketSend(socket, (uint8_t *)bufso.pvBuffer, bufso.cbBuffer, 0);
      FreeContextBuffer(bufso.pvBuffer);
      if ((unsigned int)rval != bufso.cbBuffer) {
	raise_socket_error(SG_INTERN("tls-socket-connect!"),
			   SG_MAKE_STRING("Failed to send handshake message"),
			   Sg_MakeConditionSocket(tlsSocket),
			   tlsSocket);
      }
    }
    if (!initialised) {
      initialised = TRUE;
      continue;
    }

    if (ss == S_OK) break;
  }

  return TRUE;
}

static SgTLSSocket * to_server_socket(SgTLSSocket *parent, SgSocket *sock)
{
  WinTLSData *pData = (WinTLSData *)parent->data;
  SgTLSSocket *s = make_tls_socket(sock, pData->tlsContext);
  WinTLSData *data = (WinTLSData *)s->data;
  SCHANNEL_CRED credData = {0};
  wchar_t *name = IMPL_NAME;
  SECURITY_STATUS ss;
  
  data->closed = FALSE;
  
  credData.dwVersion = SCHANNEL_CRED_VERSION;
  credData.dwFlags = SCH_CRED_NO_SYSTEM_MAPPER |
#ifdef SCH_USE_STRONG_CRYPTO
    SCH_USE_STRONG_CRYPTO |
#endif
    SCH_CRED_REVOCATION_CHECK_CHAIN;
  credData.dwMinimumCipherStrength = 128;
  credData.cCreds = data->tlsContext->certificateCount;
  credData.paCred = data->tlsContext->certificates;
  /* credData.hRootStore = data->tlsContext->certStore; */

  ss = AcquireCredentialsHandleW(NULL,
				 name,
				 SECPKG_CRED_INBOUND,
				 NULL,
				 &credData,
				 NULL,
				 NULL,
				 &data->credential,
				 NULL);
  DUMP_CRED_HANDLE(&data->credential);

  if (ss != S_OK) {
    Sg_TLSSocketClose(s);
    raise_socket_error(SG_INTERN("tls-socket-accept"),
		       Sg_GetLastErrorMessageWithErrorCode(ss),
		       Sg_MakeConditionSocket(s),
		       Sg_MakeIntegerU(ss));
  }
  Sg_RegisterFinalizer(s, tls_socket_finalizer, NULL);
  return s;
}

static int server_handshake(SgTLSSocket *tlsSocket)
{
  SgSocket *socket = tlsSocket->socket;
  SECURITY_STATUS ss = SEC_I_CONTINUE_NEEDED;
  WinTLSData *data = (WinTLSData *)tlsSocket->data;
  SecBufferDesc sbout, sbin;
  SecBuffer bufso[2], bufsi[2];
  int initialised = FALSE, pt = 0;
  /* FIXME... */
  uint8_t t[0x10000];

  for (;;) {
    DWORD sspiOutFlags = 0;
    int rval = 0;

    if (ss != SEC_I_CONTINUE_NEEDED &&
	ss != SEC_E_INCOMPLETE_MESSAGE &&
	ss != SEC_I_INCOMPLETE_CREDENTIALS)
      break;

    /* TODO handle when pt is bigger than buffer size */
    for (;;) {
      rval = Sg_SocketReceive(socket, t+pt, sizeof(t), 0);
      if (rval == 0 || rval == -1) {
	raise_socket_error(SG_INTERN("tls-socket-server-handshake"),
			   SG_MAKE_STRING("Failed to receive handshake message"),
			   Sg_MakeConditionSocket(tlsSocket),
			   tlsSocket);
      }
      pt += rval;
      if (!socket_readable(socket->socket)) break;
    }
    bufsi[0].BufferType = SECBUFFER_TOKEN;
    bufsi[0].cbBuffer = pt;
    bufsi[0].pvBuffer = t;
    bufsi[1].BufferType = SECBUFFER_EMPTY;
    bufsi[1].cbBuffer = 0;
    bufsi[1].pvBuffer = NULL;
    sbin.ulVersion = SECBUFFER_VERSION;
    sbin.pBuffers = bufsi;
    sbin.cBuffers = 2;
      
    bufso[0].pvBuffer = NULL;
    bufso[0].BufferType = SECBUFFER_TOKEN;
    bufso[0].cbBuffer = 0;
    bufso[1].pvBuffer = NULL;
    bufso[1].BufferType = SECBUFFER_EMPTY;
    bufso[1].cbBuffer = 0;
    sbout.ulVersion = SECBUFFER_VERSION;
    sbout.cBuffers = 2;
    sbout.pBuffers = bufso;

    ss = AcceptSecurityContext(&data->credential,
			       initialised ? &data->context : NULL,
			       &sbin,
			       ASC_REQ_ALLOCATE_MEMORY,
			       0,
			       initialised ? NULL : &data->context,
			       &sbout,
			       &sspiOutFlags,
			       NULL);
    initialised = TRUE;
    if (ss == SEC_E_INCOMPLETE_MESSAGE) continue;
    pt = 0;
    
    if (FAILED(ss) || (ss != S_OK && ss != SEC_I_CONTINUE_NEEDED)) {
      raise_socket_error(SG_INTERN("tls-socket-server-handshake"),
			 Sg_GetLastErrorMessageWithErrorCode(ss),
			 Sg_MakeConditionSocket(tlsSocket),
			 Sg_MakeIntegerU(ss));
    }
    DUMP_CTX_HANDLE(&data->context);
    if (bufso[0].cbBuffer != 0 && bufso[0].pvBuffer != NULL) {
      /* send the data we got to the remote part */
      rval = Sg_SocketSend(socket, (uint8_t *)bufso[0].pvBuffer,
			   bufso[0].cbBuffer, 0);
      FreeContextBuffer(bufso[0].pvBuffer);
      if ((unsigned int)rval != bufso[0].cbBuffer) {
	raise_socket_error(SG_INTERN("tls-socket-server-handshake"),
			   SG_MAKE_STRING("Failed to send handshake message"),
			   Sg_MakeConditionSocket(tlsSocket),
			   tlsSocket);
      }
    }
    if (ss == S_OK) break;
  }

  return TRUE;
}


SgObject Sg_TLSSocketAccept(SgTLSSocket *tlsSocket, int handshake)
{
  SgObject sock = Sg_SocketAccept(tlsSocket->socket);
  if (SG_SOCKETP(sock)) {
    SgTLSSocket *srv = to_server_socket(tlsSocket, SG_SOCKET(sock));
    if (handshake) {
      server_handshake(srv);
    }
    return SG_OBJ(srv);
  }
  return SG_FALSE;
}

static void tls_socket_shutdown(SgTLSSocket *tlsSocket)
{
  WinTLSData *data = (WinTLSData *)tlsSocket->data;
  SecBufferDesc sbout;
  SecBuffer buffer;
  DWORD type = SCHANNEL_SHUTDOWN;
  int serverP;
  
  buffer.pvBuffer = &type;
  buffer.BufferType = SECBUFFER_TOKEN;
  buffer.cbBuffer = sizeof(type);
  sbout.cBuffers = 1;
  sbout.pBuffers = &buffer;
  sbout.ulVersion = SECBUFFER_VERSION;

  switch (tlsSocket->socket->type) {
  case SG_SOCKET_SERVER: serverP = TRUE; break;
  case SG_SOCKET_CLIENT: serverP = FALSE; break;
  default: return;
  }
  
  do {
    SECURITY_STATUS ss = ApplyControlToken(&data->context, &sbout);
    
    DWORD sspiFlags = ISC_REQ_SEQUENCE_DETECT   |
      ISC_REQ_REPLAY_DETECT     |
      ISC_REQ_CONFIDENTIALITY   |
      ISC_RET_EXTENDED_ERROR    |
      ISC_REQ_ALLOCATE_MEMORY   |
      ISC_REQ_STREAM;
    DWORD outFlags;
    uint8_t *message;
    int count;
    if (FAILED(ss)) return;	/* do nothing? */

    buffer.pvBuffer = NULL;
    buffer.BufferType = SECBUFFER_TOKEN;
    buffer.cbBuffer = 0;
    sbout.cBuffers = 1;
    sbout.pBuffers = &buffer;
    sbout.ulVersion = SECBUFFER_VERSION;
    if (serverP) {
      ss = AcceptSecurityContext(&data->credential,
				 &data->context,
				 NULL,
				 sspiFlags,
				 SECURITY_NATIVE_DREP,
				 NULL,
				 &sbout,
				 &outFlags,
				 NULL);
    } else {
      ss = InitializeSecurityContextW(&data->credential,
				      &data->context,
				      NULL,
				      sspiFlags,
				      0,
				      SECURITY_NATIVE_DREP,
				      NULL,
				      0,
				      &data->context,
				      &sbout,
				      &outFlags,
				      NULL);
    }
    if (FAILED(ss)) return;
    message = (uint8_t *)buffer.pvBuffer;
    count = buffer.cbBuffer;
    if (message != NULL && count != 0) {
      Sg_SocketSend(tlsSocket->socket, message, count, 0);
      FreeContextBuffer(message);
    }
  } while(0);
}

void Sg_TLSSocketShutdown(SgTLSSocket *tlsSocket, int how)
{
  /* FIXME it seems not right */
  tls_socket_shutdown(tlsSocket);
  Sg_SocketShutdown(tlsSocket->socket, how);
}

void Sg_TLSSocketClose(SgTLSSocket *tlsSocket)
{
  WinTLSData *data = (WinTLSData *)tlsSocket->data;
  if (!data->closed) {
    DeleteSecurityContext(&data->context);
    FreeCredentialsHandle(&data->credential);
    data->tlsContext = NULL;      /* for GC */
    Sg_SocketClose(tlsSocket->socket);
    data->closed = TRUE;
    Sg_UnregisterFinalizer(SG_OBJ(tlsSocket));
  }
}

int Sg_TLSSocketOpenP(SgTLSSocket *tlsSocket)
{
  WinTLSData *data = (WinTLSData *)tlsSocket->data;
  return !data->closed;
}

/* TODO check -1 */
#define handleError(rval, socket)

int Sg_TLSSocketReceive(SgTLSSocket *tlsSocket, uint8_t *b, int size, int flags)
{
  SgSocket *socket = tlsSocket->socket;
  WinTLSData *data = (WinTLSData *)tlsSocket->data;
  SecPkgContext_StreamSizes sizes;
  SECURITY_STATUS ss;
  int read = 0, bufferSize, pt;
  SecBufferDesc sbin;
  SecBuffer buffers[4];
  uint8_t *mmsg;

  ss = QueryContextAttributes(&data->context, SECPKG_ATTR_STREAM_SIZES, &sizes);
  if (FAILED(ss)) {
    raise_socket_error(SG_INTERN("tls-socket-recv!"),
		       Sg_GetLastErrorMessageWithErrorCode(ss),
		       Sg_MakeConditionSocket(tlsSocket),
		       Sg_MakeIntegerU(ss));
  }
  if (data->pendingSize > 0) {
    if (size <= data->pendingSize) {
      int s = data->pendingSize-size;
      memcpy(b, data->pendingData, size);
      if (s) {
	memmove(data->pendingData, data->pendingData + size, s);
      }
      data->pendingSize = s;
      return size;
    }
    memcpy(b, data->pendingData, data->pendingSize);
    read += data->pendingSize;
    size -= data->pendingSize;
    data->pendingSize = 0;
    if (!socket_readable(socket->socket)) return read;
  }
  /* TODO optimise size or reuse buffer */
  bufferSize = sizes.cbMaximumMessage + sizes.cbHeader + sizes.cbTrailer;
#ifdef HAVE_ALLOCA
  mmsg = (uint8_t *)alloca(bufferSize);
#else
  mmsg = SG_NEW_ATOMIC2(uint8_t *, bufferSize);
#endif

  pt = 0;
  for (;;) {
    /* TODO handle the case when pt is bigger than buffer */
    int rval = Sg_SocketReceive(socket, mmsg + pt, bufferSize, 0), i;
    SecBuffer *buffer = NULL, *extra = NULL;

    handleError(rval, socket);
    buffers[0].pvBuffer = mmsg;
    buffers[0].cbBuffer = rval;
    buffers[0].BufferType = SECBUFFER_DATA;
    buffers[1].BufferType = SECBUFFER_EMPTY;
    buffers[2].BufferType = SECBUFFER_EMPTY;
    buffers[3].BufferType = SECBUFFER_EMPTY;

    sbin.ulVersion = SECBUFFER_VERSION;
    sbin.pBuffers = buffers;
    sbin.cBuffers = 4;
    ss = DecryptMessage(&data->context, &sbin, 0, NULL);
    /* In case of non SSL? */
    if (ss == SEC_E_INCOMPLETE_MESSAGE) {
      pt += rval;
      continue;
    }
    pt = 0;
    if (ss != SEC_E_OK) {
      raise_socket_error(SG_INTERN("tls-socket-recv!"),
			 Sg_GetLastErrorMessageWithErrorCode(ss),
			 Sg_MakeConditionSocket(tlsSocket),
			 Sg_MakeIntegerU(ss));
    }
    buffer = NULL;
    for (i = 1; i < sizeof(buffers); i++) {
      if (buffer == NULL && buffers[i].BufferType == SECBUFFER_DATA)
	buffer = &buffers[i];
      if (extra == NULL && buffers[i].BufferType == SECBUFFER_EXTRA)
	extra = &buffers[i];
    }
    /* Data buffer not found */
    if (buffer == NULL || buffer->BufferType != SECBUFFER_DATA) {
      return 0;
    }

    if (buffer->cbBuffer <= (unsigned int)size) {
      memcpy(b + read, buffer->pvBuffer, buffer->cbBuffer);
      read += buffer->cbBuffer;
    } else {
      int s = buffer->cbBuffer - size;
      memcpy(b + read, buffer->pvBuffer, size);
      data->pendingSize = s;
      /* TODO reuse the buffer if it fits */
      data->pendingData = SG_NEW_ATOMIC2(uint8_t *, s);
      memcpy(data->pendingData, (uint8_t *)buffer->pvBuffer + size, s);
      read += size;
    }
    return read;
  }
}

int Sg_TLSSocketSend(SgTLSSocket *tlsSocket, uint8_t *b, int size, int flags)
{
  SgSocket *socket = tlsSocket->socket;
  WinTLSData *data = (WinTLSData *)tlsSocket->data;
  SecPkgContext_StreamSizes sizes;
  SECURITY_STATUS ss;
  SecBufferDesc sbin;
  SecBuffer bufs[4];
  int sent = 0, rest = size;
  uint8_t *mmsg, *mhdr, *mtrl;

  ss = QueryContextAttributes(&data->context, SECPKG_ATTR_STREAM_SIZES, &sizes);
  if (FAILED(ss)) goto err;

#ifdef HAVE_ALLOCA
  mmsg = (uint8_t *)alloca(min(sizes.cbMaximumMessage, (unsigned int)size));
  mhdr = (uint8_t *)alloca(sizes.cbHeader);
  mtrl = (uint8_t *)alloca(sizes.cbTrailer);
#else
  mmsg = SG_NEW_ATOMIC2(uint8_t *, min(sizes.cbMaximumMessage, size));
  mhdr = SG_NEW_ATOMIC2(uint8_t *, sizes.cbHeader);
  mtrl = SG_NEW_ATOMIC2(uint8_t *, sizes.cbTrailer);
#endif

  while (rest > 0) {
    unsigned int portion = rest;
    int rval;
    if (portion > sizes.cbMaximumMessage) {
      portion = sizes.cbMaximumMessage;
    }
    memcpy(mmsg, b, portion);

    bufs[0].pvBuffer = mhdr;
    bufs[0].cbBuffer = sizes.cbHeader;
    bufs[0].BufferType = SECBUFFER_STREAM_HEADER;
    bufs[1].pvBuffer = mmsg;
    bufs[1].cbBuffer = portion;
    bufs[1].BufferType = SECBUFFER_DATA;
    bufs[2].pvBuffer = mtrl;
    bufs[2].cbBuffer = sizes.cbTrailer;
    bufs[2].BufferType = SECBUFFER_STREAM_TRAILER;
    bufs[3].pvBuffer = NULL;
    bufs[3].cbBuffer = 0;
    bufs[3].BufferType = SECBUFFER_EMPTY;

    sbin.ulVersion = SECBUFFER_VERSION;
    sbin.pBuffers = bufs;
    sbin.cBuffers = 4;

    ss = EncryptMessage(&data->context, 0, &sbin, 0);
    if (FAILED(ss)) goto err;
#define send(buf)							\
    do {								\
      rval = Sg_SocketSend(socket, (uint8_t *)(buf).pvBuffer,		\
			   (buf).cbBuffer, 0);				\
      handleError(rval, socket);					\
    } while (0)

    send(bufs[0]);
    send(bufs[1]);
    send(bufs[2]);

    sent += portion;
    rest -= portion;
    b    += portion;
  }
  return sent;
 err:
  raise_socket_error(SG_INTERN("tls-socket-send"),
		     Sg_GetLastErrorMessageWithErrorCode(ss),
		     Sg_MakeConditionSocket(tlsSocket),
		     Sg_MakeIntegerU(ss));
  return -1;			/* dummy */
}

static void cleanup_keyset(void *data)
{
  /* Delete key set*/
  HCRYPTPROV hProv = NULL;
  CryptAcquireContext(&hProv, KEY_CONTAINER_NAME, KEY_PROVIDER,
		      PROV_RSA_SCHANNEL, CRYPT_DELETEKEYSET);
}

void Sg_InitTLSImplementation()
{
#ifndef USE_UCS4_CPP
  /* due to the widechar conversion we need to set up like this */
  SgObject keyContainer =
    SG_MAKE_STRING("CYGWIN Sagittarius " SAGITTARIUS_VERSION
		   " SSL Socket Key Container");
  SgObject provName = SG_MAKE_STRING(MS_DEF_RSA_SCHANNEL_PROV_A);
  SgObject implName = SG_MAKE_STRING(SCHANNEL_NAME_A);
  KEY_CONTAINER_NAME = Sg_StringToWCharTs(keyContainer);
  KEY_PROVIDER = Sg_StringToWCharTs(provName);
  IMPL_NAME = Sg_StringToWCharTs(implName);
#endif
  Sg_AddCleanupHandler(cleanup_keyset, NULL);
  cleanup_keyset(NULL);
}
