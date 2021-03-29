/* sagittarius-socket.h                            -*- mode:c; coding:utf-8; -*-
 *
 *   Copyright (c) 2010-2016  Takashi Kato <ktakashi@ymail.com>
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
#ifndef SAGITTARIUS_SOCKET_H_
#define SAGITTARIUS_SOCKET_H_

#ifdef _WIN32
# include <winsock2.h>
# include <ws2tcpip.h>
# ifdef _MSC_VER
#  pragma comment(lib, "ws2_32.lib")
# endif
/* what a crap!! */
# define SHUT_RD   SD_RECEIVE 
# define SHUT_WR   SD_SEND 
# define SHUT_RDWR SD_BOTH 
#else
# include <sys/socket.h>
# include <netdb.h>
# include <unistd.h>
# include <errno.h>
# include <fcntl.h>
# include <arpa/inet.h>
# include <sys/select.h>
# include <netinet/in.h>
# include <netinet/tcp.h>
#endif
#include <sagittarius.h>

typedef enum {
  SG_SOCKET_UNKNOWN,
  SG_SOCKET_CLIENT,
  SG_SOCKET_SERVER,
  SG_SOCKET_CLOSED,
} SgSocketType;

#ifndef _WIN32
typedef int SOCKET;
# define INVALID_SOCKET ((SOCKET)-1)
#endif

typedef struct SgSockaddrRec SgSockaddr;

typedef struct SgSocketRec
{
  SG_HEADER;
  SOCKET socket;		/* fd */
  int lastError;
  SgSocketType type;
  SgSockaddr *address;		/* for sockaddr */
  int nonblocking;		/* blocking or not */
  SgObject node;
  SgObject service;
} SgSocket;

SG_CLASS_DECL(Sg_SocketClass);
#define SG_CLASS_SOCKET (&Sg_SocketClass)
#define SG_SOCKET(obj)  ((SgSocket*)obj)
#define SG_SOCKETP(obj) SG_XTYPEP(obj, SG_CLASS_SOCKET)

typedef struct SgAddrinfoRec
{
  SG_HEADER;
  struct addrinfo *ai;
  SgObject node;
  SgObject service;
} SgAddrinfo;

SG_CLASS_DECL(Sg_AddrinfoClass);
#define SG_CLASS_ADDRINFO (&Sg_AddrinfoClass)
#define SG_ADDRINFO(obj)  ((SgAddrinfo*)obj)
#define SG_ADDRINFOP(obj) SG_XTYPEP(obj, SG_CLASS_ADDRINFO)

struct SgSockaddrRec
{
  SG_HEADER;
  socklen_t        addr_size;
  struct sockaddr *addr;
};

SG_CLASS_DECL(Sg_SockaddrClass);
#define SG_CLASS_SOCKADDR (&Sg_SockaddrClass)
#define SG_SOCKADDR(obj)  ((SgSockaddr*)obj)
#define SG_SOCKADDRP(obj) SG_XTYPEP(obj, SG_CLASS_SOCKADDR)

typedef enum {
  None,
  IPv4,
  IPv6
} INET_TYPE;
typedef struct SgIpAddressRec
{
  SG_HEADER;
  SgObject ip;
  INET_TYPE type;
} SgIpAddress;

SG_CLASS_DECL(Sg_IpAddressClass);
#define SG_CLASS_IP_ADDRESS  (&Sg_IpAddressClass)
#define SG_IP_ADDRESS(obj)   ((SgIpAddress*)obj)
#define SG_IP_ADDRESS_P(obj) SG_XTYPEP(obj, SG_CLASS_IP_ADDRESS)

typedef struct SgSocketInfoRec
{
  SG_HEADER;
  SgObject  hostname;		/* string */
  SgObject  ipaddress;
  int       port;
} SgSocketInfo;

SG_CLASS_DECL(Sg_SocketInfoClass);
#define SG_CLASS_SOCKET_INFO (&Sg_SocketInfoClass)
#define SG_SOCKET_INFO(obj)  ((SgSocketInfo*)obj)
#define SG_SOCKET_INFO_P(obj) SG_XTYPEP(obj, SG_CLASS_SOCKET_INFO)

typedef struct SgFdSetRec
{
  SG_HEADER;
  fd_set    fdset;
  int       maxfd;
  SgObject  sockets;
} SgFdSet;

SG_CLASS_DECL(Sg_FdSetClass);
#define SG_CLASS_FD_SET (&Sg_FdSetClass)
#define SG_FDSET(obj)  ((SgFdSet*)obj)
#define SG_FDSETP(obj) SG_XTYPEP(obj, SG_CLASS_FD_SET)

/* socket port */
typedef struct SgSocketPortRec
{
  SgPort parent;
  SgSocket *socket;
} SgSocketPort;

SG_CLASS_DECL(Sg_SocketPortClass);
#define SG_CLASS_SOCKET_PORT (&Sg_SocketPortClass)
#define SG_SOCKET_PORT(obj)  ((SgSocketPort*)obj)
#define SG_SOCKET_PORTP(obj) SG_XTYPEP(obj, SG_CLASS_SOCKET_PORT)
#define SG_SOCKET_PORT_SOCKET(obj) (SG_SOCKET_PORT(obj)->socket)

#ifdef _WIN32
/* for abortable socket */
# define SG_SET_SOCKET_EVENT(sock, hEvent, flags)		\
  do {								\
    ULONG val = !(flags) ? SG_SOCKET(sock)->nonblocking: 1;	\
    SOCKET s = SG_SOCKET(sock)->socket;				\
    WSAEventSelect(s, (hEvent), flags);				\
    ioctlsocket(s, FIONBIO, &val);				\
  } while (0)
#define SG_ABORTABLE_SOCKET_OP(ret, socket, flags, operation)	\
  do {								\
    if (SG_SOCKET(socket)->nonblocking) {			\
      (ret) = operation;					\
    } else {							\
      HANDLE hEvents_[2];					\
      SgVM *vm = Sg_VM();					\
      int r;							\
      hEvents_[0] = CreateEvent(NULL, FALSE, FALSE, NULL);	\
      hEvents_[1] = (&vm->thread)->event;			\
      SG_SET_SOCKET_EVENT(socket, hEvents_[0], flags);		\
      r = WaitForMultipleObjects(2, hEvents_, FALSE, INFINITE);	\
      if (r == WAIT_OBJECT_0) {					\
	(ret) = operation;					\
      } else {							\
	ret = -1;						\
	SetLastError(WSAEINTR);					\
      }								\
      SG_SET_SOCKET_EVENT(socket, hEvents_[0], 0);		\
      CloseHandle(hEvents_[0]);					\
    }								\
  } while (0)
#else
#define SG_SET_SOCKET_EVENT(sock, hEvent, flags, revertp) /* dummy */
#define SG_ABORTABLE_SOCKET_OP(ret, socket, flags, operation) \
  (ret) = operation;
#endif

/* condition &socket 
   &i/o
    + &host-not-found (node, service)
    + &socket (socket)
       + &socket-connection
       + &socket-closed
       + &socket-port (port)
*/
SG_CLASS_DECL(Sg_HostNotFoundClass);
SG_CLASS_DECL(Sg_ConditionSocketClass);
SG_CLASS_DECL(Sg_ConditionSocketConnectionClass);
SG_CLASS_DECL(Sg_ConditionSocketClosedClass);
SG_CLASS_DECL(Sg_ConditionSocketPortClass);

#define SG_CLASS_HOST_NOT_FOUND          (&Sg_HostNotFoundClass)
#define SG_CLASS_CONDITION_SOCKET        (&Sg_ConditionSocketClass)
#define SG_CLASS_CONDITION_SOCKET_CONNECTION \
  (&Sg_ConditionSocketConnectionClass)
#define SG_CLASS_CONDITION_SOCKET_CLOSED (&Sg_ConditionSocketClosedClass)
#define SG_CLASS_CONDITION_SOCKET_PORT   (&Sg_ConditionSocketPortClass)

typedef struct SgHostNotFoundRec
{
  SG_INSTANCE_HEADER;
  SgObject node;
  SgObject service;
} SgHostNotFound;
#define SG_HOST_NOT_FOUND(o) ((SgHostNotFound *)o)
#define SG_HOST_NOT_FOUNDP(o) SG_ISA(o, SG_CLASS_HOST_NOT_FOUND)

typedef struct SgConditionSocketRec
{
  SG_INSTANCE_HEADER;
  SgObject socket;
} SgConditionSocket;
#define SG_CONDITION_SOCKET(o)  ((SgConditionSocket *)o)
#define SG_CONDITION_SOCKETP(o) SG_ISA(o, SG_CLASS_CONDITION_SOCKET)

typedef SgConditionSocket SgConditionSocketConnection;
#define SG_CONDITION_SOCKET_CONNECTION(o)  ((SgConditionSocketConnection *)o)
#define SG_CONDITION_SOCKET_CONNECTIONP(o)		\
  SG_ISA(o, SG_CLASS_CONDITION_SOCKET_CONNECTION)

typedef SgConditionSocket SgConditionSocketClosed;
#define SG_CONDITION_SOCKET_CLOSED(o)  ((SgConditionSocketClosed *)o)
#define SG_CONDITION_SOCKET_CLOSEDP(o)		\
  SG_ISA(o, SG_CLASS_CONDITION_SOCKET_CLOSED)

typedef struct SgConditionSocketPortRec
{
  SgConditionSocket parent;
  SgObject port;
} SgConditionSocketPort;
#define SG_CONDITION_SOCKET_PORT(o)  ((SgConditionSocketPort *)o)
#define SG_CONDITION_SOCKET_PORTP(o) SG_ISA(o, SG_CLASS_CONDITION_SOCKET_PORT)

SG_CDECL_BEGIN

SG_EXTERN SgAddrinfo* Sg_MakeAddrinfo();
SG_EXTERN SgAddrinfo* Sg_GetAddrinfo(SgObject node, SgObject service,
				     SgAddrinfo *hints);

SG_EXTERN SgObject  Sg_CreateSocket(int family, int socktype, int protocol);

SG_EXTERN SgObject  Sg_SocketSetopt(SgSocket *socket, int level,
				    int opname, SgObject value);
SG_EXTERN SgObject  Sg_SocketGetopt(SgSocket *socket, int level,
				    int opname, int rsize);

SG_EXTERN SgObject  Sg_SocketConnect(SgSocket *socket, SgAddrinfo* addrinfo,
				     SgObject timeout);
SG_EXTERN SgObject  Sg_SocketBind(SgSocket *socket, SgAddrinfo* addrinfo);
SG_EXTERN SgObject  Sg_SocketListen(SgSocket *socket, int backlog);

SG_EXTERN long      Sg_SocketReceive(SgSocket *socket, uint8_t *data,
				     long size, int flags);
SG_EXTERN long      Sg_SocketReceiveFrom(SgSocket *socket, uint8_t *data,
					 long size, int flags,
					 SgSockaddr *addr);
SG_EXTERN long      Sg_SocketSend(SgSocket *socket, uint8_t *data,
				  long size, int flags);
SG_EXTERN long      Sg_SocketSendTo(SgSocket *socket, uint8_t *data,
				    long size, int flags, SgSockaddr *addr);
SG_EXTERN SgObject  Sg_SocketAccept(SgSocket *socket);
SG_EXTERN void      Sg_SocketShutdown(SgSocket *socket, int how);
SG_EXTERN void      Sg_SocketClose(SgSocket *socket);
SG_EXTERN int       Sg_SocketOpenP(SgSocket *socket);

/* misc */
SG_EXTERN SgObject  Sg_SocketErrorMessage(SgSocket *socket);

SG_EXTERN int       Sg_SocketNonblocking(SgSocket *socket);
SG_EXTERN int       Sg_SocketBlocking(SgSocket *socket);

SG_EXTERN SgObject  Sg_MakeSocketPort(SgSocket *socket, int close);
SG_EXTERN SgObject  Sg_MakeSocketInputPort(SgSocket *socket);
SG_EXTERN SgObject  Sg_MakeSocketOutputPort(SgSocket *socket);
SG_EXTERN void      Sg_ShutdownPort(SgPort *port, int how);

/* fdset */
SG_EXTERN SgObject  Sg_MakeFdSet();
SG_EXTERN SgObject  Sg_SocketsToFdSet(SgObject sockets);
/* SG_EXTERN SgObject  Sg_CollectSockets(SgObject fdset, SgObject sockets); */

/* select */
SG_EXTERN SgObject  Sg_SocketSelect(SgObject reads, SgObject writes,
				    SgObject errors, SgObject timeout);
SG_EXTERN SgObject  Sg_SocketSelectX(SgObject reads, SgObject writes,
				     SgObject errors, SgObject timeout);

/* misc */
SG_EXTERN SgObject  Sg_SocketPeer(SgObject socket);
SG_EXTERN SgObject  Sg_SocketName(SgObject socket);
SG_EXTERN SgObject  Sg_SocketInfo(SgObject socket);
SG_EXTERN SgObject  Sg_IpAddressToString(SgObject ip);

/* conditions */
SG_EXTERN SgObject  Sg_MakeHostNotFound(SgObject node, SgObject service);
SG_EXTERN SgObject  Sg_MakeConditionSocket(SgObject socket);
SG_EXTERN SgObject  Sg_MakeConditionSocketConnection(SgObject socket);
SG_EXTERN SgObject  Sg_MakeConditionSocketClosed(SgObject socket);
SG_EXTERN SgObject  Sg_MakeConditionSocketPort(SgObject socket, SgObject port);

SG_CDECL_END

#endif /* SAGITTARIUS_SOCKET_HPP_ */
