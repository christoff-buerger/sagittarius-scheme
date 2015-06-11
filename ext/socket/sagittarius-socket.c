/* sagittarius-socket.c                            -*- mode:c; coding:utf-8; -*-
 *
 *   Copyright (c) 2010-2015  Takashi Kato <ktakashi@ymail.com>
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
 *
 *  $Id: $
 */


#include <sagittarius.h>
#define LIBSAGITTARIUS_EXT_BODY
#include <sagittarius/extend.h>
#include "sagittarius-socket.h"

#include <sys/types.h>
#include <string.h>
#include <signal.h>
/* we assume _WIN32 is only VC */
#if defined(_MSC_VER) || defined(_SG_WIN_SUPPORT)
#define EINTR  WSAEINTR
#define EAGAIN WSATRY_AGAIN
#define EWOULDBLOCK WSAEWOULDBLOCK
#define EPIPE WSAEINVAL
#endif

#ifndef MSG_NOSIGNAL
#define MSG_NOSIGNAL 0		/* no support (incl. *BSD/OSX) */
#endif

/* 
   https://bugs.launchpad.net/libdrizzle/+bug/404662
   Even though it said it's fixed HOWEVER h, on FreeBSD 9.1 it still
   returns EAI_BADFLAGS! so we set this 0
 */
#ifdef __FreeBSD__
#undef AI_V4MAPPED
#define AI_V4MAPPED 0
#endif

static void socket_printer(SgObject self, SgPort *port, SgWriteContext *ctx)
{
  SgSocket *socket = SG_SOCKET(self);
  const SgChar *type = (socket->type == SG_SOCKET_CLIENT)
    ? UC("client") : (socket->type == SG_SOCKET_SERVER)
    ? UC("server") : (socket->type == SG_SOCKET_CLOSED)
    ? UC("closed") : UC("unknown");
  SgObject address = (socket->address != NULL) ? socket->address: SG_FALSE;
  Sg_Printf(port, UC("#<socket %s %S>"), type, address);
}

SG_DEFINE_BUILTIN_CLASS_SIMPLE(Sg_SocketClass, socket_printer);


static SgString* get_address_string_rec(const struct sockaddr *addr,
					socklen_t addrlen, int port_p)
{
  int ret;
  char host[NI_MAXHOST];
  char ip[NI_MAXHOST];
  char serv[NI_MAXSERV];
  char name[NI_MAXSERV + (NI_MAXHOST<<1) + 1];
  do {
    ret = getnameinfo(addr,
		      addrlen,
		      host, sizeof(host),
		      serv, sizeof(serv), 
		      NI_NUMERICSERV);
  } while (EAI_AGAIN == ret);
  do {
    ret = getnameinfo(addr,
		      addrlen,
		      ip, sizeof(ip),
		      serv, sizeof(serv), 
		      NI_NUMERICSERV | NI_NUMERICHOST);
  } while (EAI_AGAIN == ret);
  if (port_p) {
    snprintf(name, sizeof(name), "%s(%s):%s", host, ip, serv);
  } else {
    snprintf(name, sizeof(name), "%s", host);
  }
  return SG_STRING(Sg_MakeStringC(name));
}

static SgString* get_address_string(const struct sockaddr *addr,
				    socklen_t addrlen)
{
  return get_address_string_rec(addr, addrlen, TRUE);
}

static void addrinfo_printer(SgObject self, SgPort *port, SgWriteContext *ctx)
{
  SgAddrinfo *info = SG_ADDRINFO(self);
  SgObject addr = get_address_string(info->ai->ai_addr, 
				     /* fxxk Windows! */
				     (socklen_t)info->ai->ai_addrlen);
  Sg_Printf(port, UC("#<addrinfo %A>"), addr);
}

SG_DEFINE_BUILTIN_CLASS_SIMPLE(Sg_AddrinfoClass, addrinfo_printer);

static void sockaddr_printer(SgObject self, SgPort *port, SgWriteContext *ctx)
{
  SgSockaddr *addr = SG_SOCKADDR(self);
  Sg_Printf(port, UC("#<sockaddr %d>"), addr->addr_size);
}

SG_DEFINE_BUILTIN_CLASS_SIMPLE(Sg_SockaddrClass, sockaddr_printer);

#define IPv4_INADDER_SIZE 0x4
#define IPv6_INADDER_SIZE 0x10
#define IPv6_INT16_SIZE   0x2

static SgObject bytevector_to_v4_string(SgObject bv)
{
  /* bv must have 4 length */
  ASSERT(SG_BVECTOR_SIZE(bv) >= IPv4_INADDER_SIZE);
  return Sg_Sprintf(UC("%d.%d.%d.%d"),
		    SG_BVECTOR_ELEMENT(bv, 0),
		    SG_BVECTOR_ELEMENT(bv, 1),
		    SG_BVECTOR_ELEMENT(bv, 2),
		    SG_BVECTOR_ELEMENT(bv, 3));
}

static SgObject bytevector_to_v6_string(SgObject bv)
{
  static const char table[] = "0123456789abcdef";
  SgObject r;
  SgPort sp;
  SgTextualPort tp;
  int i;
  Sg_InitStringOutputPort(&sp, &tp, 39);
  for (i = 0; i < (IPv6_INADDER_SIZE / IPv6_INT16_SIZE); i++) {
    int hi = SG_BVECTOR_ELEMENT(bv, (i<<1));
    int lo = SG_BVECTOR_ELEMENT(bv, ((i<<1)+1));
    Sg_PutcUnsafe(&sp, table[hi]);
    Sg_PutcUnsafe(&sp, table[lo]);
    if (i < (IPv6_INADDER_SIZE / IPv6_INT16_SIZE) - 1) {
      Sg_PutcUnsafe(&sp, ':');
    }
  }
  r = Sg_GetStringFromStringPort(&sp);
  SG_CLEAN_TEXTUAL_PORT(&tp);
  return r;
}

static SgObject ip_to_string(SgIpAddress *ip)
{
  switch (ip->type) {
  case IPv4: return bytevector_to_v4_string(ip->ip);
  case IPv6: return bytevector_to_v6_string(ip->ip);
  default: return SG_FALSE;
  }
}

static void ip_printer(SgObject self, SgPort *port, SgWriteContext *ctx)
{
  Sg_Printf(port, UC("#<ip-address %A>"), ip_to_string(SG_IP_ADDRESS(self)));
}

SG_DEFINE_BUILTIN_CLASS_SIMPLE(Sg_IpAddressClass, ip_printer);

static void socktinfo_printer(SgObject self, SgPort *port, SgWriteContext *ctx)
{
  SgSocketInfo *info = SG_SOCKET_INFO(self);
  Sg_Printf(port, UC("#<socket-info %A(%A:%d)>"),
	    info->hostname, info->ipaddress, info->port);
}

SG_DEFINE_BUILTIN_CLASS_SIMPLE(Sg_SocketInfoClass, socktinfo_printer);

static SgIpAddress *make_ip_address(struct sockaddr_storage *info)
{
  SgIpAddress *z = SG_NEW(SgIpAddress);
  SgObject ip;
  SG_SET_CLASS(z, SG_CLASS_IP_ADDRESS);
  if (info->ss_family == AF_INET) {
    struct sockaddr_in *s = (struct sockaddr_in *)info;
    ip = Sg_MakeByteVector(IPv4_INADDER_SIZE, 0);
    memcpy(SG_BVECTOR_ELEMENTS(ip), (void *)&s->sin_addr.s_addr,
	   IPv4_INADDER_SIZE);
    z->type = IPv4;
  } else {			/* AF_INET6 */
    struct sockaddr_in6 *s = (struct sockaddr_in6 *)info;
    ip = Sg_MakeByteVector(IPv6_INADDER_SIZE, 0);
    memcpy(SG_BVECTOR_ELEMENTS(ip), (void *)&s->sin6_addr.s6_addr,
	   IPv6_INADDER_SIZE);
    z->type = IPv6;
  }
  z->ip = ip;
  return z;
}

static SgSocketInfo* make_socket_info(struct sockaddr_storage *info)
{
  SgSocketInfo *si = SG_NEW(SgSocketInfo);
  int port, addr_len;
  SgObject ip, host;
  SG_SET_CLASS(si, SG_CLASS_SOCKET_INFO);
  if (info->ss_family == AF_INET) {
    struct sockaddr_in *s = (struct sockaddr_in *)info;
    port = ntohs(s->sin_port);
    addr_len = sizeof(struct sockaddr_in);
  } else {			/* AF_INET6 */
    struct sockaddr_in6 *s = (struct sockaddr_in6 *)info;
    port = ntohs(s->sin6_port);
    addr_len = sizeof(struct sockaddr_in6);
  }
  ip = make_ip_address(info);
  host = get_address_string_rec((struct sockaddr *)info, addr_len, FALSE);
  si->hostname = host;
  si->ipaddress = ip;
  si->port = port;
  return si;
}

static SgObject si_hostname(SgSocketInfo *si)
{
  return si->hostname;
}
static SgObject si_ip_address(SgSocketInfo *si)
{
  return si->ipaddress;
}
static SgObject si_port(SgSocketInfo *si)
{
  return SG_MAKE_INT(si->port);
}

static SgSlotAccessor si_slots[] = {
  SG_CLASS_SLOT_SPEC("hostname",   0, si_hostname, NULL),
  SG_CLASS_SLOT_SPEC("ip-address", 1, si_ip_address, NULL),
  SG_CLASS_SLOT_SPEC("port",       2, si_port, NULL),
  { { NULL } }
};

#ifdef _WIN32
#define last_error WSAGetLastError()
#else
#define last_error errno
#endif

#define set_last_error(sock)			\
  do {						\
    (sock)->lastError = last_error;		\
  } while (0)


static void socket_finalizer(SgObject self, void *data)
{
  Sg_SocketClose(SG_SOCKET(self));
}

static SgSocket* make_socket_inner(SOCKET fd)
{
  SgSocket *s = SG_NEW(SgSocket);
  SG_SET_CLASS(s, SG_CLASS_SOCKET);
  s->socket = fd;
  Sg_RegisterFinalizer(s, socket_finalizer, NULL);
  s->type = SG_SOCKET_UNKNOWN;
  s->address = NULL;
  s->thread = NULL;
  return s;
}

static SgSocket* make_socket(SOCKET fd, SgSocketType type, SgString *address)
{
  SgSocket *s = make_socket_inner(fd);
  s->type = type;
  s->address = address;
  s->lastError = 0;
  return s;
}

static SgAddrinfo* make_addrinfo()
{
  SgAddrinfo *info = SG_NEW(SgAddrinfo);
  SG_SET_CLASS(info, SG_CLASS_ADDRINFO);
  return info;
}

/* accessors for addressinfo */
static SgObject ai_flags(SgAddrinfo *ai)
{
  return SG_MAKE_INT(ai->ai->ai_flags);
}
static void ai_flags_set(SgAddrinfo *ai, SgObject flags)
{
  if (!SG_INTP(flags)) Sg_Error(UC("fixnum required but got %S"), flags);
  ai->ai->ai_flags = SG_INT_VALUE(flags);
}

static SgObject ai_family(SgAddrinfo *ai)
{
  return SG_MAKE_INT(ai->ai->ai_family);
}
static void ai_family_set(SgAddrinfo *ai, SgObject family)
{
  if (!SG_INTP(family)) Sg_Error(UC("fixnum required but got %S"), family);
  ai->ai->ai_family = SG_INT_VALUE(family);
}

static SgObject ai_socktype(SgAddrinfo *ai)
{
  return SG_MAKE_INT(ai->ai->ai_socktype);
}
static void ai_socktype_set(SgAddrinfo *ai, SgObject socktype)
{
  if (!SG_INTP(socktype)) Sg_Error(UC("fixnum required but got %S"), socktype);
  ai->ai->ai_socktype = SG_INT_VALUE(socktype);
}

static SgObject ai_protocol(SgAddrinfo *ai)
{
  return SG_MAKE_INT(ai->ai->ai_protocol);
}
static void ai_protocol_set(SgAddrinfo *ai, SgObject protocol)
{
  if (!SG_INTP(protocol)) Sg_Error(UC("fixnum required but got %S"), protocol);
  ai->ai->ai_protocol = SG_INT_VALUE(protocol);
}

static SgObject ai_addr(SgAddrinfo *ai)
{
  SgSockaddr *addr = SG_NEW(SgSockaddr);
  SG_SET_CLASS(addr, SG_CLASS_SOCKADDR);
  addr->addr_size = ai->ai->ai_addrlen;
  addr->addr = ai->ai->ai_addr;
  return SG_OBJ(addr);
}

static SgObject ai_next(SgAddrinfo *ai)
{
  if (ai->ai->ai_next) {
    SgAddrinfo *info = make_addrinfo();
    info->ai = ai->ai->ai_next;
    return info;
  }
  return SG_FALSE;
}

static SgSlotAccessor ai_slots[] = {
  SG_CLASS_SLOT_SPEC("flags",    0, ai_flags, ai_flags_set),
  SG_CLASS_SLOT_SPEC("family", 1, ai_family, ai_family_set),
  SG_CLASS_SLOT_SPEC("socktype", 2, ai_socktype, ai_socktype_set),
  SG_CLASS_SLOT_SPEC("protocol", 3, ai_protocol, ai_protocol_set),
  SG_CLASS_SLOT_SPEC("addr", 4, ai_addr, NULL),
  SG_CLASS_SLOT_SPEC("next", 5, ai_next, NULL),
  { { NULL } }
};

SgAddrinfo* Sg_MakeAddrinfo()
{
  SgAddrinfo *info = make_addrinfo();
  info->ai = SG_NEW(struct addrinfo);
  memset(info->ai, 0, sizeof(struct addrinfo));
  return info;
}

SgAddrinfo* Sg_GetAddrinfo(SgObject node, SgObject service, SgAddrinfo *hints)
{
  const char * cnode = (!SG_FALSEP(node)) ?
    Sg_Utf32sToUtf8s(SG_STRING(node)) : NULL;
  const char * csrv  = (!SG_FALSEP(service)) ?
    Sg_Utf32sToUtf8s(SG_STRING(service)) : NULL;
  int ret;
  SgAddrinfo *result = make_addrinfo();
  struct addrinfo *ai, *cur, *prev, *next;
  do {
    ret = getaddrinfo(cnode, csrv, hints->ai, &ai);
  } while (EAI_AGAIN == ret);

  if (ret != 0) {
#ifdef _WIN32
    const char *msg = gai_strerrorA(ret);
#else
    const char *msg = gai_strerror(ret);
#endif
    Sg_IOError((SgIOErrorType)-1, SG_INTERN("get-addrinfo"), 
	       Sg_Utf8sToUtf32s(msg, (int)strlen(msg)),
	       SG_FALSE, SG_LIST2(SG_OBJ(node), SG_OBJ(service)));
    return NULL;
  }
  /* copy addr info */
  result->ai = SG_NEW(struct addrinfo);
  cur = result->ai;
  for (next = ai, prev = NULL; next; 
       next = next->ai_next, cur = cur->ai_next, prev = cur) {
    memcpy(cur, next, sizeof(struct addrinfo));
    /* copy sockaddr */
    cur->ai_addr = SG_NEW2(struct sockaddr *, ai->ai_addrlen);
    memcpy(cur->ai_addr, next->ai_addr, ai->ai_addrlen);
    /* FIXME ugly check */
    if (next->ai_next) {
      cur->ai_next = SG_NEW(struct addrinfo);
      if (prev) prev->ai_next = cur;
    }
  }

  freeaddrinfo(ai);
  return result;
}

SgObject Sg_CreateSocket(int family, int socktype, int protocol)
{
  const SOCKET fd = socket(family, socktype, protocol);
  if (-1 == fd) {
    return SG_FALSE;
  }

#ifdef SO_NOSIGPIPE
  const int option_value = 1;
  if (-1 == setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, 
		       &option_value, sizeof(option_value))) {
    return SG_FALSE;
  }
#endif
  return make_socket_inner(fd);
}

SgObject Sg_SocketConnect(SgSocket *socket, SgAddrinfo* addrinfo)
{
  struct addrinfo *p = addrinfo->ai;
  if (connect(socket->socket, p->ai_addr, (int)p->ai_addrlen) == 0) {
    socket->type = SG_SOCKET_CLIENT;
    socket->address = get_address_string(p->ai_addr, (socklen_t)p->ai_addrlen);
    return socket;
  }
  socket->lastError = last_error;
  return SG_FALSE;
}

SgObject Sg_SocketBind(SgSocket *socket, SgAddrinfo* addrinfo)
{
  struct addrinfo *p = addrinfo->ai;
  if (bind(socket->socket, p->ai_addr, (int)p->ai_addrlen) == 0) {
    socket->type = SG_SOCKET_SERVER;
    socket->address = get_address_string(p->ai_addr, (socklen_t)p->ai_addrlen);
    return socket;
  }
  socket->lastError = last_error;
  return SG_FALSE;
}

SgObject Sg_SocketListen(SgSocket *socket, int backlog)
{
  if (listen(socket->socket, backlog) == 0) {
    return socket;
  }
  socket->lastError = last_error;
  return SG_FALSE;
}

#define CLOSE_SOCKET(who, socket)			\
  do {							\
    if (!Sg_SocketOpenP(socket))			\
      Sg_IOError((SgIOErrorType)-1, SG_INTERN(who),	\
		 SG_MAKE_STRING("socket is closed"),	\
		 SG_FALSE, SG_NIL);			\
  } while (0)


SgObject Sg_SocketSetopt(SgSocket *socket, int level, int name, SgObject value)
{
  int r = 0;
  CLOSE_SOCKET("socket-setsockopt!",socket);
  if (SG_BVECTORP(value)) {
    r = setsockopt(socket->socket, level, name,
		   (const char *)SG_BVECTOR_ELEMENTS(value), 
		   SG_BVECTOR_SIZE(value));
  } else if (SG_INTP(value) || SG_BIGNUMP(value)) {
    int v = Sg_GetInteger(value);
    r = setsockopt(socket->socket, level, name, (const char *)&v, sizeof(int));
  } else {
    Sg_WrongTypeOfArgumentViolation(SG_INTERN("socket-setsockopt!"),
				    SG_MAKE_STRING("bytevector or integer"),
				    value, SG_NIL);
  }
  if (r != 0) {
    socket->lastError = last_error;
    return SG_FALSE;
  }
  return SG_TRUE;
}
SgObject Sg_SocketGetopt(SgSocket *socket, int level, int name, int rsize)
{
  int r = 0;
  socklen_t rrsize = rsize;
  CLOSE_SOCKET("socket-getsockopt", socket);
  if (rsize > 0) {
    SgObject bvec = Sg_MakeByteVector(rrsize, 0);
    r = getsockopt(socket->socket, level, name, 
		   (char *)SG_BVECTOR_ELEMENTS(bvec), &rrsize);
    if (r < 0) {
      Sg_IOError((SgIOErrorType)-1, SG_INTERN("socket-getsockopt"), 
		 Sg_GetLastErrorMessageWithErrorCode(last_error),
		 SG_FALSE, SG_NIL);
    }
    SG_BVECTOR_SIZE(bvec) = rrsize;
    return SG_OBJ(bvec);
  } else {
    int val;
    rrsize = sizeof(int);
    r = getsockopt(socket->socket, level, name, (char *)&val, &rrsize);
    if (r < 0) {
      Sg_IOError((SgIOErrorType)-1, SG_INTERN("socket-getsockopt"), 
		 Sg_GetLastErrorMessageWithErrorCode(last_error),
		 SG_FALSE, SG_NIL);
    }
    return Sg_MakeInteger(val);
  }
}

int Sg_SocketReceive(SgSocket *socket, uint8_t *data, int size, int flags)
{
  /* int count = 0, osize = size; */
  CLOSE_SOCKET("socket-recv", socket);
  for (;;) {
    const int ret = recv(socket->socket, (char*)data, size,
			 /* we don't want SIGPIPE */
			 flags | MSG_NOSIGNAL);
    if (ret == -1) {
      if (errno == EINTR) {
	continue;
      } else if (errno == EPIPE) {
	if (flags & MSG_NOSIGNAL) {
	  return 0;
	}
      } else if (errno == EAGAIN || errno == EWOULDBLOCK) {
	/* most probably non-blocking socket */
	return ret;
      }
      Sg_IOError((SgIOErrorType)-1, SG_INTERN("socket-recv"), 
		 Sg_GetLastErrorMessageWithErrorCode(last_error),
		 SG_FALSE, SG_NIL);
      return ret;		/* dummy */
    }
    return ret;
  }
}

int Sg_SocketReceiveFrom(SgSocket *socket, uint8_t *data, int size, int flags,
			 SgSockaddr *addr)
{
  /* int count = 0, osize = size; */
  CLOSE_SOCKET("socket-recv", socket);
  for (;;) {
    const int ret = recvfrom(socket->socket, (char*)data, size,
			     /* we don't want SIGPIPE */
			     flags | MSG_NOSIGNAL, addr->addr,
			     (socklen_t *)&addr->addr_size);
    if (ret == -1) {
      if (errno == EINTR) {
	continue;
      } else if (errno == EPIPE) {
	if (flags & MSG_NOSIGNAL) {
	  return 0;
	} else {
	  goto err;
	}
      } else if (errno == EAGAIN || errno == EWOULDBLOCK) {
	/* most probably non-blocking socket */
	return ret;
      } else {
      err:
	Sg_IOError((SgIOErrorType)-1, SG_INTERN("socket-recv"), 
		   Sg_GetLastErrorMessageWithErrorCode(last_error),
		   SG_FALSE, SG_NIL);
	return ret;
      }
    }
    return ret;
  }
}

int Sg_SocketSend(SgSocket *socket, uint8_t *data, int size, int flags)
{
  int rest = size;
  int sizeSent = 0;

  CLOSE_SOCKET("socket-send", socket);
  while (rest > 0) {
    const int ret = send(socket->socket, (char*)data, size, 
			 /* we don't want SIGPIPE */
			 flags | MSG_NOSIGNAL);
    if (ret == -1) {
      if (errno == EINTR) {
	continue;
      } else if (errno == EPIPE) {
	if (flags & MSG_NOSIGNAL) {
	  return 0;
	} else {
	  goto err;
	}	
      } else if (errno == EAGAIN || errno == EWOULDBLOCK) {
	/* most probably non-blocking socket */
	continue;
      } else {
      err:
	Sg_IOError((SgIOErrorType)-1, SG_INTERN("socket-send"), 
		   Sg_GetLastErrorMessageWithErrorCode(last_error),
		   SG_FALSE, SG_NIL);
	return ret;
      }
    }
    sizeSent += ret;
    rest -= ret;
    data += ret;
    size -= ret;
  }
  return sizeSent;
}

int Sg_SocketSendTo(SgSocket *socket, uint8_t *data, int size, int flags,
		    SgSockaddr *addr)
{
  int rest = size;
  int sizeSent = 0;

  CLOSE_SOCKET("socket-send", socket);
  while (rest > 0) {
    const int ret = sendto(socket->socket, (char*)data, size, 
			   /* we don't want SIGPIPE */
			   flags | MSG_NOSIGNAL, addr->addr, 
			   (int)addr->addr_size);
    if (ret == -1) {
      if (errno == EINTR) {
	continue;
      } else if (errno == EPIPE) {
	if (flags & MSG_NOSIGNAL) {
	  return 0;
	} else {
	  goto err;
	}	
      } else if (errno == EAGAIN || errno == EWOULDBLOCK) {
	/* most probably non-blocking socket */
	continue;
      } else {
      err:
	Sg_IOError((SgIOErrorType)-1, SG_INTERN("socket-sendto"), 
		   Sg_GetLastErrorMessageWithErrorCode(last_error),
		   SG_FALSE, SG_NIL);
	return ret;
      }
    }
    sizeSent += ret;
    rest -= ret;
    data += ret;
    size -= ret;
  }
  return sizeSent;
}

SgSocket* Sg_SocketAccept(SgSocket *socket)
{
  struct sockaddr_storage addr;
  socklen_t addrlen = sizeof(addr);
  SOCKET fd = -1;

  CLOSE_SOCKET("socket-accept", socket);

  for (;;) {
    fd = accept(socket->socket, (struct sockaddr *)&addr, &addrlen);
    if (-1 == fd) {
      /* For some reason, accept may fail on Solaris without
	 errno set. I'm not sure what this exactly means but
	 seems we can retry.
       */
      if (!errno || errno == EINTR) {
	continue;
      } else {
	Sg_IOError((SgIOErrorType)-1, SG_INTERN("socket-accept"), 
		   Sg_GetLastErrorMessageWithErrorCode(last_error),
		   SG_FALSE, socket);
	return NULL;		/* dummy */
      }
    } else {
      break;
    }
  }
  return make_socket(fd, SG_SOCKET_SERVER,
		     get_address_string((struct sockaddr *)&addr, addrlen));
}

void Sg_SocketShutdown(SgSocket *socket, int how)
{
  if (!Sg_SocketOpenP(socket)) {
    return;
  }
  shutdown(socket->socket, how);
}

void Sg_SocketClose(SgSocket *socket)
{
  if (!Sg_SocketOpenP(socket)) {
    return;
  }
#ifdef _WIN32
  /* FIXME socket-close should not shutdown socket but we don't have
     any way to flush socket other than shutting down write side of
     socket descriptor on Windows. */
  shutdown(socket->socket, SD_SEND);
  closesocket(socket->socket);
#else
  close(socket->socket);
  socket->socket = -1;
#endif
  socket->type = SG_SOCKET_CLOSED;
}

/* fdset */
static void fdset_printer(SgObject self, SgPort *port, SgWriteContext *ctx)
{
  Sg_Printf(port, UC("#<fdset %d %S>"), SG_FDSET(self)->maxfd,
	    SG_FDSET(self)->sockets);
}

SG_DEFINE_BUILTIN_CLASS_SIMPLE(Sg_FdSetClass, fdset_printer);

static SgFdSet* make_fd_set()
{
  SgFdSet *z = SG_NEW(SgFdSet);
  SG_SET_CLASS(z, SG_CLASS_FD_SET);
  z->maxfd = -1;
  z->sockets = SG_NIL;
  FD_ZERO(&z->fdset);
  return z;
}

static SgFdSet* copy_fd_set(SgFdSet *src)
{
  SgFdSet *z = SG_NEW(SgFdSet);
  SG_SET_CLASS(z, SG_CLASS_FD_SET);
  z->fdset = src->fdset;
  z->maxfd = src->maxfd;
  return z;
}

SgObject Sg_MakeFdSet()
{
  return SG_OBJ(make_fd_set());
}

static int collect_max_fd(int max, SgObject sockets, fd_set *fds)
{
  SgObject cp;
  FD_ZERO(fds);
  SG_FOR_EACH(cp, sockets) {
    SOCKET fd;
    if (!SG_SOCKETP(SG_CAR(cp))) {
      Sg_WrongTypeOfArgumentViolation(SG_INTERN("socket-select"),
				      SG_MAKE_STRING("socket"),
				      SG_CAR(cp), sockets);
    }
    if (!Sg_SocketOpenP(SG_SOCKET(SG_CAR(cp)))) {
      Sg_AssertionViolation(SG_INTERN("socket-select"),
			    SG_MAKE_STRING("socket is closed"),
			    SG_LIST2(SG_CAR(cp), sockets));
    }
    fd = SG_SOCKET(SG_CAR(cp))->socket;
    /* MSDN says the first argument of select is ignored, so this is useless */
#ifndef _WIN32
    if (max < fd) max = fd;
#endif
    FD_SET(fd, fds);
  }
  return max;
}

SgObject Sg_SocketsToFdSet(SgObject sockets)
{
  SgFdSet *fdset = make_fd_set();
  fdset->maxfd = collect_max_fd(fdset->maxfd, sockets, &fdset->fdset);
  fdset->sockets = sockets;
  return SG_OBJ(fdset);
}

static struct timeval *select_timeval(SgObject timeout, struct timeval *tm)
{
  if (SG_FALSEP(timeout)) return NULL;
  if (SG_INTP(timeout)) {
    int val = SG_INT_VALUE(timeout);
    if (val < 0) goto badtv;
    tm->tv_sec = val / 1000000;
    tm->tv_usec = val % 1000000;
    return tm;
  } else if (SG_BIGNUMP(timeout)) {
    long usec;
    SgObject sec;
    if (Sg_Sign(timeout) < 0) goto badtv;
    sec = Sg_BignumDivSI(SG_BIGNUM(timeout), 1000000, &usec);
    tm->tv_sec = Sg_GetInteger(sec);
    tm->tv_usec = usec;
    return tm;
  } else if (SG_FLONUMP(timeout)) {
    long val = Sg_GetInteger(timeout);
    if (val < 0) goto badtv;
    tm->tv_sec = val / 1000000;
    tm->tv_usec = val % 1000000;
    return tm;
  } else if (SG_PAIRP(timeout) && SG_PAIRP(SG_CDR(timeout))) {
    SgObject sec = SG_CAR(timeout);
    SgObject usec = SG_CADR(timeout);
    long isec, iusec;
    if (!Sg_IntegerP(sec) || !Sg_IntegerP(usec)) goto badtv;
    isec = Sg_GetInteger(sec);
    iusec = Sg_GetInteger(usec);
    if (isec < 0 || iusec < 0) goto badtv;
    tm->tv_sec = isec;
    tm->tv_usec = iusec;
    return tm;
  }
 badtv:
  Sg_Error(UC("timeval needs to be a real number (in microseconds) or a list"
	      " of two integers (seconds and microseconds), but got %S"),
	   timeout);
  return NULL;                /* dummy */
}

static SgObject collect_fds(SgObject sockets, fd_set *fds)
{
  SgObject h = SG_NIL, t = SG_NIL;
  SG_FOR_EACH(sockets, sockets) {
    SgSocket *socket = SG_SOCKET(SG_CAR(sockets));
    if (FD_ISSET(socket->socket, fds)) {
      SG_APPEND1(h, t, socket);
    }
  }
  return h;
}

SgObject Sg_CollectSockets(SgObject fdset, SgObject sockets)
{
  return collect_fds(sockets, &SG_FDSET(fdset)->fdset);
}

static SgObject socket_select_int(SgFdSet *rfds, SgFdSet *wfds, SgFdSet *efds,
				  SgObject timeout)
{
  struct timeval tv;
  int max = 0, numfds;
  SgVM *vm = Sg_VM();
  
#ifdef _WIN32
  HANDLE hEvents[2];
  hEvents[0] = CreateEvent(NULL, FALSE, FALSE, NULL);
  /* all the same */
  hEvents[1] = (&vm->thread)->event;
#endif
  
  if (rfds) max = rfds->maxfd;
  if (wfds && wfds->maxfd > max) max = wfds->maxfd;
  if (efds && efds->maxfd > max) max = efds->maxfd;

  /* TODO wrap this with macro */
#ifdef _WIN32

# define SET_EVENT(fdset, flags)			\
  do {							\
    if (fdset) {					\
      SgObject sockets = (fdset)->sockets;		\
      SG_FOR_EACH(sockets, sockets) {			\
	SOCKET s = SG_SOCKET(SG_CAR(sockets))->socket;	\
	WSAEventSelect(s, hEvents[0], flags);		\
      }							\
    }							\
  }while (0)

  SET_EVENT(rfds, FD_READ | FD_OOB);
  SET_EVENT(wfds, FD_WRITE);
  SET_EVENT(efds, FD_READ | FD_OOB);

  int r = WaitForMultipleObjects(2, hEvents, FALSE, INFINITE);
  if (r == WAIT_OBJECT_0) {
    numfds = select(max + 1, 
		  (rfds ? &rfds->fdset : NULL), 
		  (wfds ? &wfds->fdset : NULL), 
		  (efds ? &efds->fdset : NULL), 
		  select_timeval(timeout, &tv));
  } else {
    ResetEvent(hEvents[1]);
    numfds = -1;
  }
  SET_EVENT(rfds, 0);
  SET_EVENT(wfds, 0);
  SET_EVENT(efds, 0);
  CloseHandle(hEvents[0]);
#else
  numfds = select(max + 1, 
		  (rfds ? &rfds->fdset : NULL), 
		  (wfds ? &wfds->fdset : NULL), 
		  (efds ? &efds->fdset : NULL), 
		  select_timeval(timeout, &tv));
#endif

  if (numfds < 0) {
    /* if it's on Windows, then it always interrupted, I guess. */
#ifndef _WIN32
    if (errno == EINTR)
#endif
      {
	return Sg_Values4(SG_FALSE,
			  SG_FALSE,
			  SG_FALSE,
			  SG_FALSE);
      }
    Sg_IOError((SgIOErrorType)-1, SG_INTERN("socket-select"), 
	       Sg_GetLastErrorMessageWithErrorCode(last_error),
	       SG_FALSE, SG_NIL);
  }
  return Sg_Values4(Sg_MakeInteger(numfds),
		    (rfds ? SG_OBJ(rfds) : SG_FALSE),
		    (wfds ? SG_OBJ(wfds) : SG_FALSE),
		    (efds ? SG_OBJ(efds) : SG_FALSE));
}

static SgFdSet* check_fd(SgObject o)
{
  if (SG_FALSEP(o)) return NULL;
  if (!SG_FDSETP(o)) {
    Sg_Error(UC("<fdset> or #f required but got %S"), o);
  }
  return SG_FDSET(o);
}

SgObject Sg_SocketSelect(SgObject reads, SgObject writes, SgObject errors,
			 SgObject timeout)
{
  SgFdSet *r = check_fd(reads);
  SgFdSet *w = check_fd(writes);
  SgFdSet *e = check_fd(errors);
  return socket_select_int((r? copy_fd_set(r) : NULL),
			   (w? copy_fd_set(w) : NULL),
			   (e? copy_fd_set(e) : NULL),
			   timeout);
}

SgObject Sg_SocketSelectX(SgObject reads, SgObject writes, SgObject errors,
			 SgObject timeout)
{
  SgFdSet *r = check_fd(reads);
  SgFdSet *w = check_fd(writes);
  SgFdSet *e = check_fd(errors);
  return socket_select_int(r, w, e, timeout);
}


SgObject Sg_SocketPeer(SgObject socket)
{
  struct sockaddr_storage name;
  socklen_t len = sizeof(name);
  int ret;
  ret = getpeername(SG_SOCKET(socket)->socket, (struct sockaddr *)&name, &len);
  if (ret == 0) {
    return make_socket_info(&name);
  } else {
    return SG_FALSE;
  }
}

SgObject Sg_SocketName(SgObject socket)
{
  SgObject address = SG_SOCKET(socket)->address;
  if (address) return address;
  else return SG_FALSE;
}

SgObject Sg_SocketInfo(SgObject socket)
{
  struct sockaddr_storage name;
  socklen_t len = sizeof(name);
  int ret;
  ret = getsockname(SG_SOCKET(socket)->socket, (struct sockaddr *)&name, &len);
  if (ret == 0) {
    return make_socket_info(&name);
  } else {
    return SG_FALSE;
  }
}

SgObject Sg_IpAddressToString(SgObject ip)
{
  return ip_to_string(SG_IP_ADDRESS(ip));
}

int Sg_SocketOpenP(SgSocket *socket)
{
  return socket->type != SG_SOCKET_CLOSED;
}

int Sg_SocketNonblocking(SgSocket *socket)
{
#ifdef _WIN32
  unsigned long val = 1;
  if (ioctlsocket(socket->socket, FIONBIO, &val) != 0) {
    goto err;
  }
#else
  int flags = fcntl(socket->socket, F_GETFL, 0);
  flags &= ~O_SYNC;
  if (fcntl(socket->socket, F_SETFL, flags | O_NONBLOCK) != 0) {
    goto err;
  }
#endif
  return TRUE;
 err:
  Sg_IOError((SgIOErrorType)-1, SG_INTERN("socket-nonblocking!"), 
	     Sg_GetLastErrorMessageWithErrorCode(last_error),
	     SG_FALSE, socket);
  return FALSE;			/* dummy */
}
int Sg_SocketBlocking(SgSocket *socket)
{
#ifdef _WIN32
  unsigned long val = 0;
  int err;
  if ((err = ioctlsocket(socket->socket, FIONBIO, &val)) != 0) {
    goto err;
  }
#else
  int flags = fcntl(socket->socket, F_GETFL, 0);
  flags &= ~O_NONBLOCK;
  if (fcntl(socket->socket, F_SETFL, flags | O_SYNC) != 0) {
    goto err;
  }
#endif
  return TRUE;
 err:
  Sg_IOError((SgIOErrorType)-1, SG_INTERN("socket-blocking!"), 
	     Sg_GetLastErrorMessageWithErrorCode(last_error),
	     SG_FALSE, socket);
  return FALSE;			/* dummy */  
}

SgObject Sg_SocketErrorMessage(SgSocket *socket)
{
  return Sg_GetLastErrorMessageWithErrorCode(socket->lastError);
}

#define SG_PORT_SOCKET(p) SG_SOCKET(SG_BINARY_PORT(p)->src.data)

static void socket_flush(SgObject self)
{
}

static int socket_ready_int(SgObject socket, struct timeval *tm)
{
  fd_set fds;
  int state;

  FD_ZERO(&fds);
  FD_SET(SG_SOCKET(socket)->socket, &fds);

#ifdef _WIN32
  state = select(FD_SETSIZE, &fds, NULL, NULL, tm);
#else
  state = select(SG_SOCKET(socket)->socket + 1, &fds, NULL, NULL, tm);
#endif
  if (state < 0) {
    if (last_error == EINTR) return FALSE;
    Sg_IOError((SgIOErrorType)-1, SG_INTERN("port-ready?"), 
	       Sg_GetLastErrorMessageWithErrorCode(last_error),
	       SG_FALSE, SG_NIL);
    return FALSE;
  }
  return FD_ISSET(SG_SOCKET(socket)->socket, &fds);
}

static int socket_open(SgObject self)
{
  return Sg_SocketOpenP(SG_PORT_SOCKET(self));
}

static int socket_close(SgObject self)
{
  if (!SG_PORT(self)->closed) {
    SG_PORT(self)->closed = TRUE;
    SG_BINARY_PORT(self)->closed = SG_BPORT_CLOSED;
    Sg_SocketClose(SG_PORT_SOCKET(self));
  }
  return SG_PORT(self)->closed;
}

static int socket_close_only_port(SgObject self)
{
  if (!SG_PORT(self)->closed) {
    SG_PORT(self)->closed = TRUE;
  }
  return SG_PORT(self)->closed;
}

static int socket_get_u8(SgObject self)
{
  if (SG_PORT_HAS_U8_AHEAD(self)) {
    uint8_t buf = SG_PORT_U8_AHEAD(self);
    SG_PORT_U8_AHEAD(self) = EOF;
    return buf;
  } else {
    uint8_t c;
    const int ret = Sg_SocketReceive(SG_PORT_SOCKET(self), &c, 1, 0);
    if (0 == ret) {
      return EOF;
    } else if (-1 == ret) {
      Sg_IOReadError(SG_INTERN("get-u8"),
		     Sg_GetLastErrorMessageWithErrorCode(SG_PORT_SOCKET(self)->lastError),
		     self,
		     SG_NIL);
      return -1;
    } else {
      SG_BINARY_PORT(self)->position += ret;
      return c;
    }
  }
}

static int socket_look_ahead_u8(SgObject self)
{
  const uint8_t ret = socket_get_u8(self);
  SG_PORT_U8_AHEAD(self) = ret;
  return ret;
}

static int64_t socket_read_u8(SgObject self, uint8_t *buf, int64_t size)
{
  /* we need to read eagarly, or else something wrong happen. 
     for example, if the socket is TLS socket and encryption/decryption
     take sometime to flush socket even the data is continuous.
   */
  int readSize = 0;
  if (SG_PORT_HAS_U8_AHEAD(self) && size > 0) {
    buf[0] = SG_PORT_U8_AHEAD(self);
    SG_PORT_U8_AHEAD(self) = EOF;
    buf++;
    size--;
    readSize++;
  }
  for (;;) {
    int now = Sg_SocketReceive(SG_PORT_SOCKET(self), buf + readSize, 
			       (int)size, 0);
    int ready;
    struct timeval tm = {0, 10000};	/* wait a bit in case of retry (10ms?)*/
    if (-1 == now) {
      Sg_IOReadError(SG_INTERN("read-u8"),
		     Sg_GetLastErrorMessageWithErrorCode(SG_PORT_SOCKET(self)->lastError),
		     self,
		     SG_NIL);
      return -1;
    }
    size -= now;
    readSize += now;
    if (now == 0) break;
    if (size == 0) break;
    /* now how could we know if this socket still have some data ready
       or it's already ended. for now we use select if the socket has
       something to be read.
       FIXME: this may cause issue on TLS socket... */
    ready = socket_ready_int(SG_PORT_SOCKET(self), &tm);
    if (!ready) {
      /* most likely nothing is waiting. i hope... */
      break;
    }
    /* ok something is there keep reading*/
  }
  SG_BINARY_PORT(self)->position += readSize;
  return readSize;
}

static int64_t socket_read_u8_all(SgObject self, uint8_t **buf)
{
  uint8_t read_buf[1024];
  SgPort buffer;
  SgBinaryPort bp;
  int mark = 0;
  Sg_InitByteArrayOutputPort(&buffer, &bp, 1024);
  for (;;) {
    int read_size = Sg_SocketReceive(SG_PORT_SOCKET(self), read_buf, 1024, 0);
    if (-1 == read_size) {
      Sg_IOReadError(SG_INTERN("read-u8-all"),
		     Sg_GetLastErrorMessageWithErrorCode(SG_PORT_SOCKET(self)->lastError),
		     self,
		     SG_NIL);
      return -1;
    } else {
      Sg_WritebUnsafe(&buffer, read_buf, 0, read_size);
      if (1024 != read_size) {
	mark += read_size;
	break;
      } else {
	mark += read_size;
      }
    }
  }
  SG_BINARY_PORT(self)->position += mark;
  *buf = Sg_GetByteArrayFromBinaryPort(&buffer);
  SG_CLEAN_BINARY_PORT(&bp);
  return mark;
}


static int64_t socket_put_u8_array(SgObject self, uint8_t *v, int64_t size)
{
  int64_t written_size = Sg_SocketSend(SG_PORT_SOCKET(self), v, (int)size, 0);
  if (-1 == written_size) {
    Sg_IOWriteError(SG_INTERN("read-u8"),
		    Sg_GetLastErrorMessageWithErrorCode(SG_PORT_SOCKET(self)->lastError),
		    self,
		    SG_NIL);
    return -1;
  }
  return written_size;
}


static int64_t socket_put_u8(SgObject self, uint8_t v)
{
  return socket_put_u8_array(self, &v, 1);
}

static int socket_ready(SgObject self)
{
  SgObject socket = SG_PORT_SOCKET(self);
  struct timeval tm = {0, 0};
  return socket_ready_int(socket, &tm);
}

static SgPortTable socket_close_table = {
  socket_flush,
  socket_close,
  socket_ready,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
};
static SgPortTable socket_table = {
  socket_flush,
  socket_close_only_port,
  socket_ready,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
};

static SgBinaryPortTable socket_binary_table = {
  socket_open,
  socket_get_u8,
  socket_look_ahead_u8,
  socket_read_u8,
  socket_read_u8_all,
  socket_put_u8,
  socket_put_u8_array,
  NULL
};

static inline SgObject make_socket_port(SgSocket *socket,
					enum SgPortDirection d, 
					int closeP)
{
  if (closeP) {
    return Sg_MakeBinaryPort(d, &socket_close_table, 
			     &socket_binary_table, (void*)socket);
  } else {
    return Sg_MakeBinaryPort(d, &socket_table, 
			     &socket_binary_table, (void*)socket);
  }
}

SgObject Sg_MakeSocketPort(SgSocket *socket, int closeP)
{
  return make_socket_port(socket, SG_BIDIRECTIONAL_PORT, closeP);
}

SgObject  Sg_MakeSocketInputPort(SgSocket *socket)
{
  /* I hope compiler is smart enough to remove if and switch. */
  return make_socket_port(socket, SG_INPUT_PORT, FALSE);
}
SgObject  Sg_MakeSocketOutputPort(SgSocket *socket)
{
  /* I hope compiler is smart enough to remove if and switch. */
  return make_socket_port(socket, SG_OUTPUT_PORT, FALSE);
}

void Sg_ShutdownPort(SgPort *port, int how)
{
  /* TODO should we handle transcoded port? */
  if (!(SG_PORT(port)->type == SG_BINARY_PORT_TYPE &&
	SG_BINARY_PORT(port)->type == SG_CUSTOM_BINARY_PORT_TYPE) ||
      !SG_SOCKETP(SG_PORT_SOCKET(port))) {
    Sg_Error(UC("socket port required but got %S"), port);
  }
  if (!Sg_PortClosedP(port)) {
    Sg_FlushPort(port);
    Sg_SocketShutdown(SG_PORT_SOCKET(port), how);
  }
}

extern void Sg__Init_socket_stub(SgLibrary *lib);

#ifdef _WIN32
static void finish_winsock(void *data)
{
  WSACleanup();
}
#endif

SG_EXTENSION_ENTRY void CDECL Sg_Init_sagittarius__socket()
{
  SgLibrary *lib;
#ifdef _WIN32
  WSADATA wsaData;
  WSAStartup(2, &wsaData);
  Sg_AddCleanupHandler(finish_winsock, NULL);
#endif
  SG_INIT_EXTENSION(sagittarius__socket);
  lib = SG_LIBRARY(Sg_FindLibrary(SG_INTERN("(sagittarius socket)"),
				  FALSE));
  Sg__Init_socket_stub(lib);

  /* for multithreading issue, we do not add this cond-feature.
     we always support this anyway */
  /* Sg_AddCondFeature(UC("sagittarius.socket")); */
  Sg_InitStaticClassWithMeta(SG_CLASS_SOCKET, UC("<socket>"), lib, NULL,
			     SG_FALSE, NULL, 0);
  Sg_InitStaticClassWithMeta(SG_CLASS_ADDRINFO, UC("<addrinfo>"), lib, NULL,
			     SG_FALSE, ai_slots, 0);
  Sg_InitStaticClassWithMeta(SG_CLASS_IP_ADDRESS, UC("<ip-address>"), lib, NULL,
			     SG_FALSE, NULL, 0);
  Sg_InitStaticClassWithMeta(SG_CLASS_SOCKET_INFO, UC("<socket-info>"), lib,
			     NULL, SG_FALSE, si_slots, 0);
  Sg_InitStaticClassWithMeta(SG_CLASS_FD_SET, UC("<fdset>"), lib, NULL,
			     SG_FALSE, NULL, 0);
  /* from Ypsilon */
#define ARCH_CCONST(name)					\
  Sg_MakeBinding(lib, SG_SYMBOL(SG_INTERN(#name)), SG_MAKE_INT(name), TRUE)
#define ARCH_CFALSE(name)			\
  Sg_MakeBinding(lib, SG_SYMBOL(SG_INTERN(#name)), SG_FALSE, TRUE)
#ifdef AF_UNSPEC
  ARCH_CCONST(AF_UNSPEC);
#else
  ARCH_CFALSE(AF_UNSPEC);
#endif
#ifdef AF_INET
  ARCH_CCONST(AF_INET);
#else
  ARCH_CFALSE(AF_INET);
#endif
#ifdef AF_INET6
  ARCH_CCONST(AF_INET6);
#else
  ARCH_CFALSE(AF_INET6);
#endif
#ifdef SOCK_STREAM
  ARCH_CCONST(SOCK_STREAM);
#else
  ARCH_CFALSE(SOCK_STREAM);
#endif
#ifdef SOCK_DGRAM
  ARCH_CCONST(SOCK_DGRAM);
#else
  ARCH_CFALSE(SOCK_DGRAM);
#endif
#ifdef SOCK_RAW
  ARCH_CCONST(SOCK_RAW);
#else
  ARCH_CFALSE(SOCK_RAW);
#endif
#ifdef SOCK_RDM
  ARCH_CCONST(SOCK_RDM);
#else
  ARCH_CFALSE(SOCK_RDM);
#endif
#ifdef SOCK_SEQPACKET
  ARCH_CCONST(SOCK_SEQPACKET);
#else
  ARCH_CFALSE(SOCK_SEQPACKET);
#endif
#ifdef AI_PASSIVE
  ARCH_CCONST(AI_PASSIVE);
#else
  ARCH_CFALSE(AI_PASSIVE);
#endif
#ifdef AI_CANONNAME
  ARCH_CCONST(AI_CANONNAME);
#else
  ARCH_CFALSE(AI_CANONNAME);
#endif
#ifdef AI_NUMERICHOST
  ARCH_CCONST(AI_NUMERICHOST);
#else
  ARCH_CFALSE(AI_NUMERICHOST);
#endif
#ifdef AI_V4MAPPED
  ARCH_CCONST(AI_V4MAPPED);
#else
  ARCH_CFALSE(AI_V4MAPPED);
#endif
#ifdef AI_ALL
  ARCH_CCONST(AI_ALL);
#else
  ARCH_CFALSE(AI_ALL);
#endif
#ifdef AI_ADDRCONFIG
  ARCH_CCONST(AI_ADDRCONFIG);
#else
  ARCH_CFALSE(AI_ADDRCONFIG);
#endif
  /* IPPROTO_xxx for ai_protocol, i don't list up every thing but
     tcp and udp*/
#ifdef IPPROTO_IP
  ARCH_CCONST(IPPROTO_IP);
#else
  ARCH_CFALSE(IPPROTO_IP);
#endif
#ifdef IPPROTO_TCP
  ARCH_CCONST(IPPROTO_TCP);
#else
  ARCH_CFALSE(IPPROTO_TCP);
#endif
#ifdef IPPROTO_UDP
  ARCH_CCONST(IPPROTO_UDP);
#else
  ARCH_CFALSE(IPPROTO_UDP);
#endif
#ifdef IPPROTO_RAW
  ARCH_CCONST(IPPROTO_RAW);
#else
  ARCH_CFALSE(IPPROTO_RAW);
#endif
#ifdef IPPROTO_IPV6
  ARCH_CCONST(IPPROTO_IPV6);
#else
  ARCH_CFALSE(IPPROTO_IPV6);
#endif
#ifdef IPPROTO_ICMP
  ARCH_CCONST(IPPROTO_ICMP);
#else
  ARCH_CFALSE(IPPROTO_ICMP);
#endif
#ifdef IPPROTO_ICMPV6
  ARCH_CCONST(IPPROTO_ICMPV6);
#else
  ARCH_CFALSE(IPPROTO_ICMPV6);
#endif

#ifdef SHUT_RD
  ARCH_CCONST(SHUT_RD);
#else
  ARCH_CFALSE(SHUT_RD);
#endif
#ifdef SHUT_WR
  ARCH_CCONST(SHUT_WR);
#else
  ARCH_CFALSE(SHUT_WR);
#endif
#ifdef SHUT_RDWR
  ARCH_CCONST(SHUT_RDWR);
#else
  ARCH_CFALSE(SHUT_RDWR);
#endif
#ifdef MSG_OOB
  ARCH_CCONST(MSG_OOB);
#else
  ARCH_CFALSE(MSG_OOB);
#endif
#ifdef MSG_PEEK
  ARCH_CCONST(MSG_PEEK);
#else
  ARCH_CFALSE(MSG_PEEK);
#endif
#ifdef MSG_DONTROUTE
  ARCH_CCONST(MSG_DONTROUTE);
#else
  ARCH_CFALSE(MSG_DONTROUTE);
#endif
#ifdef MSG_CTRUNC
  ARCH_CCONST(MSG_CTRUNC);
#else
  ARCH_CFALSE(MSG_CTRUNC);
#endif
#ifdef MSG_PROBE
  ARCH_CCONST(MSG_PROBE);
#else
  ARCH_CFALSE(MSG_PROBE);
#endif
#ifdef MSG_TRUNC
  ARCH_CCONST(MSG_TRUNC);
#else
  ARCH_CFALSE(MSG_TRUNC);
#endif
#ifdef MSG_DONTWAIT
  ARCH_CCONST(MSG_DONTWAIT);
#else
  ARCH_CFALSE(MSG_DONTWAIT);
#endif
#ifdef MSG_EOR
  ARCH_CCONST(MSG_EOR);
#else
  ARCH_CFALSE(MSG_EOR);
#endif
#ifdef MSG_WAITALL
  ARCH_CCONST(MSG_WAITALL);
#else
  ARCH_CFALSE(MSG_WAITALL);
#endif
#ifdef MSG_FIN
  ARCH_CCONST(MSG_FIN);
#else
  ARCH_CFALSE(MSG_FIN);
#endif
#ifdef MSG_SYN
  ARCH_CCONST(MSG_SYN);
#else
  ARCH_CFALSE(MSG_SYN);
#endif
#ifdef MSG_CONFIRM
  ARCH_CCONST(MSG_CONFIRM);
#else
  ARCH_CFALSE(MSG_CONFIRM);
#endif
#ifdef MSG_RST
  ARCH_CCONST(MSG_RST);
#else
  ARCH_CFALSE(MSG_RST);
#endif
#ifdef MSG_ERRQUEUE
  ARCH_CCONST(MSG_ERRQUEUE);
#else
  ARCH_CFALSE(MSG_ERRQUEUE);
#endif
#ifdef MSG_NOSIGNAL
  ARCH_CCONST(MSG_NOSIGNAL);
#else
  ARCH_CFALSE(MSG_NOSIGNAL);
#endif
#ifdef MSG_MORE
  ARCH_CCONST(MSG_MORE);
#else
  ARCH_CFALSE(MSG_MORE);
#endif
#ifdef MSG_EOF
  ARCH_CCONST(MSG_EOF);
#else
  ARCH_CFALSE(MSG_EOF);
#endif

#ifdef SOL_SOCKET
  ARCH_CCONST(SOL_SOCKET);
#else
  ARCH_CFALSE(SOL_SOCKET);
#endif
#ifdef SO_ACCEPTCONN
  ARCH_CCONST(SO_ACCEPTCONN);
#else
  ARCH_CFALSE(SO_ACCEPTCONN);
#endif
#ifdef SO_BINDTODEVICE
  ARCH_CCONST(SO_BINDTODEVICE);
#else
  ARCH_CFALSE(SO_BINDTODEVICE);
#endif
#ifdef SO_BROADCAST
  ARCH_CCONST(SO_BROADCAST);
#else
  ARCH_CFALSE(SO_BROADCAST);
#endif
#ifdef SO_DEBUG
  ARCH_CCONST(SO_DEBUG);
#else
  ARCH_CFALSE(SO_DEBUG);
#endif
#ifdef SO_DONTROUTE
  ARCH_CCONST(SO_DONTROUTE);
#else
  ARCH_CFALSE(SO_DONTROUTE);
#endif
#ifdef SO_ERROR
  ARCH_CCONST(SO_ERROR);
#else
  ARCH_CFALSE(SO_ERROR);
#endif
#ifdef SO_KEEPALIVE
  ARCH_CCONST(SO_KEEPALIVE);
#else
  ARCH_CFALSE(SO_KEEPALIVE);
#endif
#ifdef SO_LINGER
  ARCH_CCONST(SO_LINGER);
#else
  ARCH_CFALSE(SO_LINGER);
#endif
#ifdef SO_OOBINLINE
  ARCH_CCONST(SO_OOBINLINE);
#else
  ARCH_CFALSE(SO_OOBINLINE);
#endif
#ifdef SO_PASSCRED
  ARCH_CCONST(SO_PASSCRED);
#else
  ARCH_CFALSE(SO_PASSCRED);
#endif
#ifdef SO_PEERCRED
  ARCH_CCONST(SO_PEERCRED);
#else
  ARCH_CFALSE(SO_PEERCRED);
#endif
#ifdef SO_PRIORITY
  ARCH_CCONST(SO_PRIORITY);
#else
  ARCH_CFALSE(SO_PRIORITY);
#endif
#ifdef SO_RCVBUF
  ARCH_CCONST(SO_RCVBUF);
#else
  ARCH_CFALSE(SO_RCVBUF);
#endif
#ifdef SO_RCVLOWAT
  ARCH_CCONST(SO_RCVLOWAT);
#else
  ARCH_CFALSE(SO_RCVLOWAT);
#endif
#ifdef SO_RCVTIMEO
  ARCH_CCONST(SO_RCVTIMEO);
#else
  ARCH_CFALSE(SO_RCVTIMEO);
#endif
#ifdef SO_REUSEADDR
  ARCH_CCONST(SO_REUSEADDR);
#else
  ARCH_CFALSE(SO_REUSEADDR);
#endif
#ifdef SO_REUSEPORT
  ARCH_CCONST(SO_REUSEPORT);
#else
  ARCH_CFALSE(SO_REUSEPORT);
#endif
#ifdef SO_SNDBUF
  ARCH_CCONST(SO_SNDBUF);
#else
  ARCH_CFALSE(SO_SNDBUF);
#endif
#ifdef SO_SNDLOWAT
  ARCH_CCONST(SO_SNDLOWAT);
#else
  ARCH_CFALSE(SO_SNDLOWAT);
#endif
#ifdef SO_SNDTIMEO
  ARCH_CCONST(SO_SNDTIMEO);
#else
  ARCH_CFALSE(SO_SNDTIMEO);
#endif
#ifdef SO_TIMESTAMP
  ARCH_CCONST(SO_TIMESTAMP);
#else
  ARCH_CFALSE(SO_TIMESTAMP);
#endif
#ifdef SO_TYPE
  ARCH_CCONST(SO_TYPE);
#else
  ARCH_CFALSE(SO_TYPE);
#endif
#ifdef SOL_TCP
  ARCH_CCONST(SOL_TCP);
#else
  ARCH_CFALSE(SOL_TCP);
#endif
#ifdef TCP_NODELAY
  ARCH_CCONST(TCP_NODELAY);
#else
  ARCH_CFALSE(TCP_NODELAY);
#endif
#ifdef TCP_MAXSEG
  ARCH_CCONST(TCP_MAXSEG);
#else
  ARCH_CFALSE(TCP_MAXSEG);
#endif
#ifdef TCP_CORK
  ARCH_CCONST(TCP_CORK);
#else
  ARCH_CFALSE(TCP_CORK);
#endif
#ifdef SOL_IP
  ARCH_CCONST(SOL_IP);
#else
  ARCH_CFALSE(SOL_IP);
#endif
#ifdef IP_OPTIONS
  ARCH_CCONST(IP_OPTIONS);
#else
  ARCH_CFALSE(IP_OPTIONS);
#endif
#ifdef IP_PKTINFO
  ARCH_CCONST(IP_PKTINFO);
#else
  ARCH_CFALSE(IP_PKTINFO);
#endif
#ifdef IP_RECVTOS
  ARCH_CCONST(IP_RECVTOS);
#else
  ARCH_CFALSE(IP_RECVTOS);
#endif
#ifdef IP_RECVTTL
  ARCH_CCONST(IP_RECVTTL);
#else
  ARCH_CFALSE(IP_RECVTTL);
#endif
#ifdef IP_RECVOPTS
  ARCH_CCONST(IP_RECVOPTS);
#else
  ARCH_CFALSE(IP_RECVOPTS);
#endif
#ifdef IP_TOS
  ARCH_CCONST(IP_TOS);
#else
  ARCH_CFALSE(IP_TOS);
#endif
#ifdef IP_TTL
  ARCH_CCONST(IP_TTL);
#else
  ARCH_CFALSE(IP_TTL);
#endif
#ifdef IP_HDRINCL
  ARCH_CCONST(IP_HDRINCL);
#else
  ARCH_CFALSE(IP_HDRINCL);
#endif
#ifdef IP_RECVERR
  ARCH_CCONST(IP_RECVERR);
#else
  ARCH_CFALSE(IP_RECVERR);
#endif
#ifdef IP_MTU_DISCOVER
  ARCH_CCONST(IP_MTU_DISCOVER);
#else
  ARCH_CFALSE(IP_MTU_DISCOVER);
#endif
#ifdef IP_MTU
  ARCH_CCONST(IP_MTU);
#else
  ARCH_CFALSE(IP_MTU);
#endif
#ifdef IP_ROUTER_ALERT
  ARCH_CCONST(IP_ROUTER_ALERT);
#else
  ARCH_CFALSE(IP_ROUTER_ALERT);
#endif
#ifdef IP_MULTICAST_TTL
  ARCH_CCONST(IP_MULTICAST_TTL);
#else
  ARCH_CFALSE(IP_MULTICAST_TTL);
#endif
#ifdef IP_MULTICAST_LOOP
  ARCH_CCONST(IP_MULTICAST_LOOP);
#else
  ARCH_CFALSE(IP_MULTICAST_LOOP);
#endif
#ifdef IP_ADD_MEMBERSHIP
  ARCH_CCONST(IP_ADD_MEMBERSHIP);
#else
  ARCH_CFALSE(IP_ADD_MEMBERSHIP);
#endif
#ifdef IP_DROP_MEMBERSHIP
  ARCH_CCONST(IP_DROP_MEMBERSHIP);
#else
  ARCH_CFALSE(IP_DROP_MEMBERSHIP);
#endif
#ifdef IP_MULTICAST_IF
  ARCH_CCONST(IP_MULTICAST_IF);
#else
  ARCH_CFALSE(IP_MULTICAST_IF);
#endif

#ifndef SOMAXCONN
#define SOMAXCONN 5
#endif
  ARCH_CCONST(SOMAXCONN);

#undef ARCH_CCONST
#undef ARCH_CFALSE

}
