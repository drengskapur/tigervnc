/* Copyright (C) 2002-2005 RealVNC Ltd.  All Rights Reserved.
 * Copyright (c) 2012 University of Oslo.  All Rights Reserved.
 * 
 * This is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 * 
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this software; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307,
 * USA.
 */

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <sys/stat.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <errno.h>
#include <stdlib.h>
#include <stddef.h>
#include <string.h>

#include <core/Exception.h>
#include <core/LogWriter.h>

#include <network/UnixSocket.h>

using namespace network;

static core::LogWriter vlog("UnixSocket");

// -=- UnixSocket

UnixSocket::UnixSocket(int sock) : Socket(sock)
{
}

UnixSocket::UnixSocket(const char *path)
{
  int sock, err, result;
  sockaddr_un addr;
  socklen_t salen;

  if (strlen(path) >= sizeof(addr.sun_path))
    throw core::socket_error("Socket path is too long", ENAMETOOLONG);

  // - Create a socket
  sock = socket(AF_UNIX, SOCK_STREAM, 0);
  if (sock == -1)
    throw core::socket_error("Unable to create socket", errno);

  // - Attempt to connect
  memset(&addr, 0, sizeof(addr));
  addr.sun_family = AF_UNIX;
  strcpy(addr.sun_path, path);
  salen = sizeof(addr);
  while ((result = connect(sock, (sockaddr *)&addr, salen)) == -1) {
    err = errno;
    close(sock);
    break;
  }

  if (result == -1)
    throw core::socket_error("Unable to connect to socket", err);

  setFd(sock);
}

const char* UnixSocket::getPeerAddress() {
  static struct sockaddr_un addr;
  socklen_t salen;

  // AF_UNIX only has a single address (the server side).
  // Unfortunately we don't know which end we are, so we'll have to
  // test a bit.

  salen = sizeof(addr);
  if (getpeername(getFd(), (struct sockaddr *)&addr, &salen) != 0) {
    vlog.error("Unable to get peer name for socket");
    return "";
  }

  if (salen > offsetof(struct sockaddr_un, sun_path))
    return addr.sun_path;

  salen = sizeof(addr);
  if (getsockname(getFd(), (struct sockaddr *)&addr, &salen) != 0) {
    vlog.error("Unable to get local name for socket");
    return "";
  }

  if (salen > offsetof(struct sockaddr_un, sun_path))
    return addr.sun_path;

  // socketpair() will create unnamed sockets

  return "(unnamed UNIX socket)";
}

const char* UnixSocket::getPeerEndpoint() {
  return getPeerAddress();
}

UnixListener::UnixListener(const char *path, int mode)
{
  struct sockaddr_un addr;
  mode_t saved_umask;
  int err, result;

  if (strlen(path) >= sizeof(addr.sun_path))
    throw core::socket_error("Socket path is too long", ENAMETOOLONG);

  // - Create a socket
  if ((fd = socket(AF_UNIX, SOCK_STREAM, 0)) < 0)
    throw core::socket_error("Unable to create listening socket", errno);

  // - Delete existing socket (ignore result)
  unlink(path);

  // - Attempt to bind to the requested path
  memset(&addr, 0, sizeof(addr));
  addr.sun_family = AF_UNIX;
  strcpy(addr.sun_path, path);
  saved_umask = umask(0777);
  result = bind(fd, (struct sockaddr *)&addr, sizeof(addr));
  err = errno;
  umask(saved_umask);
  if (result < 0) {
    close(fd);
    throw core::socket_error("Unable to bind listening socket", err);
  }

  // - Set socket mode
  if (chmod(path, mode) < 0) {
    err = errno;
    close(fd);
    throw core::socket_error("Unable to set socket mode", err);
  }

  listen(fd);
}

UnixListener::~UnixListener()
{
  struct sockaddr_un addr;
  socklen_t salen = sizeof(addr);

  if (getsockname(getFd(), (struct sockaddr *)&addr, &salen) == 0)
    unlink(addr.sun_path);
}

Socket* UnixListener::createSocket(int fd_) {
  return new UnixSocket(fd_);
}

int UnixListener::getMyPort() {
  return 0;
}
