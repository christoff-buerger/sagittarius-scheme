/* tls_openssl.c                                   -*- mode:c; coding:utf-8; -*-
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


#include <openssl/ssl.h>
#include <openssl/err.h>
#if (SSLEAY_VERSION_NUMBER >= 0x0907000L)
# include <openssl/conf.h>
#endif

#if (OPENSSL_VERSION_NUMBER < 0x10100000) || defined(LIBRESSL_VERSION_NUMBER)
#define	SSL_CTX_up_ref(ctx)					\
  CRYPTO_add(&(ctx->references), 1, CRYPTO_LOCK_SSL_CTX)
#endif

#include <sagittarius.h>
#define LIBSAGITTARIUS_EXT_BODY
#include <sagittarius/extend.h>
#include "tls-socket.h"

typedef struct OpenSSLDataRec
{
  SSL_CTX *ctx;
  SSL     *ssl;
} OpenSSLData;

static void tls_socket_finalizer(SgObject self, void *data)
{
  Sg_TLSSocketClose(SG_TLS_SOCKET(self));
}

static SgTLSSocket* make_tls_socket(SgSocket *socket, SSL_CTX *ctx)
{
  SgTLSSocket *r = SG_NEW(SgTLSSocket);
  OpenSSLData *data = SG_NEW(OpenSSLData);
  SG_SET_CLASS(r, SG_CLASS_TLS_SOCKET);
  
  r->socket = socket;
  r->data = data;
  data->ctx = ctx;
  
  data->ssl = NULL;
  Sg_RegisterFinalizer(r, tls_socket_finalizer, NULL);
  return r;
}

/* needs to be shared... */
static void raise_socket_error(SgObject who, SgObject msg, 
			       SgObject c, SgObject irr)
{
  SgObject sc;
  if (SG_NULLP(irr)) {
    sc = Sg_Condition(SG_LIST3(c,
			       Sg_MakeWhoCondition(who),
			       Sg_MakeMessageCondition(msg)));
  } else {
    sc = Sg_Condition(SG_LIST4(c,
			       Sg_MakeWhoCondition(who),
			       Sg_MakeMessageCondition(msg),
			       Sg_MakeIrritantsCondition(irr)));
  }
  Sg_Raise(sc, FALSE);
}


SgTLSSocket* Sg_SocketToTLSSocket(SgSocket *socket,
				  /* list of bytevectors */
				  SgObject certificates,
				  /* encoded private key, bytevector */
				  SgByteVector *privateKey)
{
  SgObject cp;
  SSL_CTX *ctx = SSL_CTX_new(SSLv23_client_method());
  SSL_CTX_set_options(ctx, SSL_OP_NO_SSLv2 | SSL_OP_NO_SSLv3);
  /* TODO handle certificates and private key */
  SG_FOR_EACH(cp, Sg_Reverse(certificates)) {
    SgObject c = SG_CAR(cp);
    int r;
    if (!SG_BVECTORP(c)) {
      SSL_CTX_free(ctx);
      Sg_AssertionViolation(SG_INTERN("socket->tls-socket"),
			    Sg_Sprintf(UC("bytevector required but got %S"), c),
			    certificates);
    }
    r = SSL_CTX_use_certificate_ASN1(ctx, SG_BVECTOR_SIZE(c),
				     SG_BVECTOR_ELEMENTS(c));
    if (r != 1) goto err;
  }
  if (privateKey) {
    int r = SSL_CTX_use_RSAPrivateKey_ASN1(ctx, SG_BVECTOR_ELEMENTS(privateKey),
					   SG_BVECTOR_SIZE(privateKey));
    if (r != 1) goto err;
    r = SSL_CTX_check_private_key(ctx);
    if (r != 1) goto err;
  }
  
  return make_tls_socket(socket, ctx);

 err: {
    unsigned long e = ERR_get_error();
    const char *msg = ERR_reason_error_string(e);
    SSL_CTX_free(ctx);
    Sg_AssertionViolation(SG_INTERN("socket->tls-socket"),
			  Sg_Utf8sToUtf32s(msg, strlen(msg)),
			  SG_NIL);
  }
  return NULL;			/* dummy */
}

int Sg_TLSSocketConnect(SgTLSSocket *tlsSocket)
{
  OpenSSLData *data = (OpenSSLData *)tlsSocket->data;
  data->ssl = SSL_new(data->ctx);
  SSL_set_fd(data->ssl, tlsSocket->socket->socket);
  return SSL_connect(data->ssl);
}

SgObject  Sg_TLSSocketAccept(SgTLSSocket *tlsSocket)
{
  SgObject sock = Sg_SocketAccept(tlsSocket->socket);
  if (SG_SOCKETP(sock)) {
    OpenSSLData *newData, *data = (OpenSSLData *)tlsSocket->data;
    SgTLSSocket *newSock = make_tls_socket(SG_SOCKET(sock), data->ctx);
    /* this will be shared among the server socket, so increase the 
       reference count.
     */
    SSL_CTX_up_ref(data->ctx);
    newData = (OpenSSLData *)newSock->data;
    newData->ssl = SSL_new(data->ctx);
    SSL_set_fd(newData->ssl, newSock->socket->socket);
    return newSock;
  }
  /* interrupted */
  return SG_FALSE;
}

void Sg_TLSSocketShutdown(SgTLSSocket *tlsSocket, int how)
{
  OpenSSLData *data = (OpenSSLData *)tlsSocket->data;
  SSL_shutdown(data->ssl);
  /* hmmm, does this work? */
  Sg_SocketShutdown(tlsSocket->socket, how);
}

void Sg_TLSSocketClose(SgTLSSocket *tlsSocket)
{
  OpenSSLData *data = (OpenSSLData *)tlsSocket->data;
  if (data->ssl) {
    SSL_free(data->ssl);
    data->ssl = NULL;
  }
  if (data->ctx) {
    SSL_CTX_free(data->ctx);
    data->ctx = NULL;
  }
  Sg_SocketClose(tlsSocket->socket);
}

int Sg_TLSSocketOpenP(SgTLSSocket *tlsSocket)
{
  OpenSSLData *data = (OpenSSLData *)tlsSocket->data;
  return data->ssl != NULL && data->ctx != NULL;
}

#if EAGAIN == EWOULDBLOCK
#define NON_BLOCKING_CASE EAGAIN
#else
#define NON_BLOCKING_CASE EAGAIN: case EWOULDBLOCK
#endif

#define handleError(who, r, ssl)					\
  if ((r) <= 0)	{							\
    int e = errno;							\
    int err = SSL_get_error((ssl), (r));				\
    if (err != SSL_ERROR_NONE) {					\
      const char *msg;							\
      if (SSL_ERROR_SYSCALL == err) {					\
	switch (e) {							\
	case EINTR: continue;						\
	case EPIPE:							\
	  if (flags & MSG_NOSIGNAL) {					\
	    return 0;							\
	  }								\
	  break;							\
	case NON_BLOCKING_CASE:						\
	  /* most probably non-blocking socket */			\
	  continue;							\
	}								\
	raise_socket_error(SG_INTERN(who),				\
			   Sg_GetLastErrorMessageWithErrorCode(e),	\
			   Sg_MakeConditionSocket(tlsSocket),		\
			   SG_LIST1(SG_MAKE_INT(e)));			\
      }									\
      msg = ERR_reason_error_string(err);				\
      raise_socket_error(SG_INTERN(who),				\
			 Sg_Utf8sToUtf32s(msg, strlen(msg)),		\
			 Sg_MakeConditionSocket(tlsSocket),		\
			 SG_NIL);					\
    }									\
  }

int Sg_TLSSocketReceive(SgTLSSocket *tlsSocket, uint8_t *data,
			int size, int flags)
{
  OpenSSLData *tlsData = (OpenSSLData *)tlsSocket->data;
  int r;
  if (!tlsData->ssl) {
    raise_socket_error(SG_INTERN("tls-socket-recv"),
		       SG_MAKE_STRING("socket is closed"),
		       Sg_MakeConditionSocketClosed(tlsSocket),
		       tlsSocket);
  }
  for (;;) {
    r = SSL_read(tlsData->ssl, data, size);
    handleError("tls-socket-recv", r, tlsData->ssl);
    return r;
  }
}

int Sg_TLSSocketSend(SgTLSSocket *tlsSocket, uint8_t *data, int size, int flags)
{
  OpenSSLData *tlsData = (OpenSSLData *)tlsSocket->data;
  int r, sent = 0;
  if (!tlsData->ssl) {
    raise_socket_error(SG_INTERN("tls-socket-send"),
		       SG_MAKE_STRING("socket is closed"),
		       Sg_MakeConditionSocketClosed(tlsSocket),
		       tlsSocket);
  }
  while (size > 0) {
    r = SSL_write(tlsData->ssl, data, size);
    handleError("tls-socket-send", r, tlsData->ssl);
    sent += r;
    data += r;
    size -= r;
  }
  return sent;
}

void Sg_InitTLSImplementation()
{
  OpenSSL_add_all_algorithms();
  /* ERR_load_BIO_strings(); */
  /* ERR_load_crypto_strings(); */
  SSL_load_error_strings();
  OPENSSL_config(NULL);
  SSL_library_init();
}
