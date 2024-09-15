#include "htmlview/HTTP.hpp"
#include "log/log.h"
#include "std/Utils.hpp"
#include "std/Vector.hpp"

#define WIN32_LEAN_AND_MEAN
#define _WINSOCK_DEPRECATED_NO_WARNINGS
#include "winsock2.h"
#include "ws2tcpip.h"

static const Slice<u8> PROTOCOL_HTTP = SLICE_FROM_STRLIT("http://");
static const Slice<u8> PORT_80 = SLICE_FROM_STRLIT("80");
static Slice<u8> duplicateStringAsciiz(Arena *arena, Slice<u8> src) {
  Slice<u8> ret;
  alloc(arena, src.length + 1, ret);
  memcpy(ret.data, src.data, src.length);
  return ret;
}

static b32 parseOrigin(Arena *arena,
                       Slice<u8> origin,
                       Slice<u8> &host,
                       Slice<u8> &port) {
  u32 idxFirstColon;
  if (indexOf(origin, u8(':'), &idxFirstColon)) {
    Slice<u8> h = subarray(origin, 0, idxFirstColon);
    Slice<u8> p = subarray(origin, idxFirstColon + 1);
    host = duplicateStringAsciiz(arena, h);
    port = duplicateStringAsciiz(arena, p);
  } else {
    host = duplicateStringAsciiz(arena, origin);
    port = duplicateStringAsciiz(arena, PORT_80);
  }

  return true;
}

/**
 * Initializes an Url from a string. The Url instance will allocate space for
 * and make zero-terminated copies of the parts of the url.
 */
b32 Url_initFromString(Url *self, Arena *arena, Slice<u8> url) {
  Slice<u8> cursor = url;

  // FIXME(danielm): protocol hardcoded to http
  if (!startsWith(cursor, PROTOCOL_HTTP)) {
    return false;
  }

  self->protocol = duplicateStringAsciiz(arena, PROTOCOL_HTTP);

  shrinkFromLeftByCount(&cursor, self->protocol.length - 1);

  u32 idxFirstSlash;
  if (!indexOf(cursor, u8('/'), &idxFirstSlash)) {
    // Implicit "/" path
    self->path = duplicateStringAsciiz(arena, SLICE_FROM_STRLIT("/"));
    return parseOrigin(arena, cursor, self->host, self->port);
  }

  Slice<u8> origin = subarray(cursor, 0, idxFirstSlash);

  if (!parseOrigin(arena, origin, self->host, self->port)) {
    return false;
  }

  Slice<u8> path = subarray(cursor, idxFirstSlash);
  self->path = duplicateStringAsciiz(arena, path);

  return true;
}

Slice<u8> Url_format(Arena *arena, Url *self) {
  ArenaTemp temp = getScratch(&arena, 1);

  Vector<u8> tmp = vectorWithInitialCapacity<u8>(
      temp.arena, self->protocol.length + self->host.length +
                      self->port.length + self->path.length + 1);

  memcpy(append(temp.arena, &tmp, self->protocol.length - 1),
         self->protocol.data, self->protocol.length - 1);
  memcpy(append(temp.arena, &tmp, self->host.length - 1), self->host.data,
         self->host.length - 1);
  *append(temp.arena, &tmp) = ':';
  memcpy(append(temp.arena, &tmp, self->port.length - 1), self->port.data,
         self->port.length - 1);
  memcpy(append(temp.arena, &tmp, self->path.length - 1), self->path.data,
         self->path.length - 1);

  Slice<u8> ret = copyToSlice(arena, tmp);
  releaseScratch(temp);
  return ret;
}

static void appendStrAsciiz(Arena *arena, Vector<u8> *dst, Slice<u8> s) {
  u8 *p = append(arena, dst, s.length - 1);
  memcpy(p, s.data, s.length - 1);
}

static void appendStr(Arena *arena, Vector<u8> *dst, const char *s) {
  u32 lenStr = strlen(s);
  u8 *p = append(arena, dst, lenStr);
  memcpy(p, s, lenStr);
}

static b32 readUntilDelimiter(Arena *arena,
                              SOCKET hSock,
                              char delimiterCh,
                              Slice<u8> &out) {
  int rc;
  DWORD numRecv = 0;

  ArenaTemp temp = getScratch(&arena, 1);
  Vector<u8> tempVec;
  b32 isWaitingForLF = false;
  while (true) {
    u8 *buf = append(temp.arena, &tempVec);
    WSABUF wsaBuf = {1, (CHAR *)buf};
    DWORD flags = 0;
    rc = WSARecv(hSock, &wsaBuf, 1, &numRecv, &flags, nullptr, nullptr);
    if (rc != 0) {
      log_info("WSARecv failed while reading until delimiter [%d]",
               WSAGetLastError());
      releaseScratch(temp);
      return false;
    }

    if (isWaitingForLF) {
      if (*buf != '\n') {
        releaseScratch(temp);
        return false;
      }
      break;
    }

    if (*buf == delimiterCh || *buf == '\r') {
      DCHECK(tempVec.length != 0);
      tempVec.length--;
      out = copyToSlice(arena, tempVec);

      if (*buf == '\r') {
        isWaitingForLF = true;
        continue;
      } else {
        break;
      }
    }
  }
  releaseScratch(temp);
  return true;
}

static b32 readUntilCRLF(Arena *arena, SOCKET hSock, Slice<u8> &out) {
  return readUntilDelimiter(arena, hSock, '\0', out);
}

static b32 atoi(Slice<u8> s, i32 &out) {
  out = 0;
  for (u32 i = 0; i < s.length; i++) {
    u8 ch = s[i];
    if (!('0' <= ch && ch <= '9')) {
      return false;
    }

    out = (out * 10) + (ch - '0');
  }

  return true;
}

static b32 readStatusLine(Arena *arena,
                          SOCKET hSock,
                          Slice<u8> &version,
                          i32 &code,
                          Slice<u8> &reason) {
  int rc;
  DWORD numRecv = 0;

  if (!readUntilDelimiter(arena, hSock, ' ', version)) {
    return false;
  }

  ArenaTemp temp = getScratch(&arena, 1);
  Slice<u8> codeBuf;
  if (!readUntilDelimiter(temp.arena, hSock, ' ', codeBuf)) {
    return false;
  }
  if (!atoi(codeBuf, code)) {
    return false;
  }
  releaseScratch(temp);
  if (!readUntilCRLF(temp.arena, hSock, reason)) {
    return false;
  }

  return true;
}

enum class ReadHeaderStatus {
  Ok = 0,
  EndOfHeaders = 1,
  RecvError = -1,
};

static ReadHeaderStatus readHeader(Arena *arena,
                                   SOCKET hSock,
                                   Slice<u8> &key,
                                   Slice<u8> &value) {
  int rc;
  DWORD numRecv = 0;

  if (!readUntilDelimiter(arena, hSock, ':', key)) {
    return ReadHeaderStatus::RecvError;
  }

  if (empty(key)) {
    return ReadHeaderStatus::EndOfHeaders;
  }

  if (!readUntilCRLF(arena, hSock, value)) {
    return ReadHeaderStatus::RecvError;
  }

  while (!empty(value) && value[0] == ' ') {
    shrinkFromLeft(&value);
  }

  return ReadHeaderStatus::Ok;
}

static b32 fetchFromSocket(Arena *arena,
                           SOCKET hSock,
                           const Url &url,
                           i32 &responseCode,
                           Slice<u8> &body) {
  int rc;
  ArenaTemp temp = getScratch(&arena, 1);
  Vector<u8> request = vectorWithInitialCapacity<u8>(temp.arena, 1024);
  // Request line
  appendStr(temp.arena, &request, "GET ");
  appendStrAsciiz(temp.arena, &request, url.path);
  appendStr(temp.arena, &request, " HTTP/1.1\r\n");

  // Host
  appendStr(temp.arena, &request, "Host: ");
  appendStrAsciiz(temp.arena, &request, url.host);
  appendStr(temp.arena, &request, ":");
  appendStrAsciiz(temp.arena, &request, url.port);
  appendStr(temp.arena, &request, "\r\n");
  // Connection
  appendStr(temp.arena, &request, "Connection: close\r\n");
  // No stuff we cant handle pwease
  appendStr(temp.arena, &request, "Accept: text/*, text/html\r\n");
  // Announce ourselves
  appendStr(
      temp.arena, &request,
      "User-Agent: git.easimer.net/easimer/htmlview (Browser Jam 2024)\r\n");
  // End of request
  appendStr(temp.arena, &request, "\r\n");

  log_info("Sending request");
  WSABUF wsaBuf = {request.length, (CHAR *)request.data};
  DWORD numBytesSent = 0;
  rc = WSASend(hSock, &wsaBuf, 1, &numBytesSent, 0, nullptr, nullptr);
  log_info("Sent request:\n\"\"\"\n%.*s\n\"\"\"", FMT_SLICE(request));

  resetScratch(temp);
  if (rc != 0) {
    log_error("WSASend failed [%d]", rc);
    releaseScratch(temp);
    return false;
  }

  Slice<u8> responseVersion, reason;

  if (!readStatusLine(temp.arena, hSock, responseVersion, responseCode,
                      reason)) {
    log_error("Failed to parse status line");
    releaseScratch(temp);
    return false;
  }

  log_info("Version: %.*s Code: %d Reason: '%.*s'", FMT_SLICE(responseVersion),
           responseCode, FMT_SLICE(reason));

  resetScratch(temp);
  i32 contentLength = 0;
  ReadHeaderStatus rhs = ReadHeaderStatus::Ok;
  while (rhs != ReadHeaderStatus::EndOfHeaders) {
    Slice<u8> key, value;
    rhs = readHeader(temp.arena, hSock, key, value);
    if (rhs == ReadHeaderStatus::Ok) {
      log_info("Key '%.*s' value '%.*s'", FMT_SLICE(key), FMT_SLICE(value));
    }

    if (compareAsString(key, SLICE_FROM_STRLIT("Content-Length"))) {
      if (!atoi(value, contentLength)) {
        log_error("Failed to parse Content-Length");
        releaseScratch(temp);
        return false;
      }
    }
  }

  resetScratch(temp);

  // Read the body
  log_info("Content length: %d bytes", contentLength);

  alloc(arena, contentLength, body);
  u32 offCursor = 0;

  while (offCursor < contentLength) {
    WSABUF wsaBuf = {contentLength - offCursor, (CHAR *)body.data + offCursor};
    DWORD flags = 0;
    DWORD numRecv = 0;
    rc = WSARecv(hSock, &wsaBuf, 1, &numRecv, &flags, nullptr, nullptr);
    if (rc != 0) {
      log_error("WSARecv failed [%d]", WSAGetLastError());
      releaseScratch(temp);
      return false;
    }
    offCursor += numRecv;
  }

  releaseScratch(temp);
  return true;
}

b32 HTTP_fetch(Arena *arena, Slice<u8> urlIn, HTTP_Response &res) {
  Url url = {};
  if (!Url_initFromString(&url, arena, urlIn)) {
    return false;
  }
  struct addrinfo hints;
  memset(&hints, 0, sizeof(hints));
  hints.ai_family = AF_INET;
  hints.ai_socktype = SOCK_STREAM;
  hints.ai_protocol = IPPROTO_TCP;

  log_info("Resolving address of %.*s:%.*s", FMT_SLICE(url.host),
           FMT_SLICE(url.port));

  INT rc;
  struct addrinfo *resAddrInfo;
  rc = getaddrinfo((PCSTR)url.host.data, (PCSTR)url.port.data, &hints,
                   &resAddrInfo);
  if (rc != 0) {
    log_error("Address resolution failed [%d]", rc);
    return false;
  }

  struct addrinfo *curAddr = resAddrInfo;

  SOCKET hSock = INVALID_SOCKET;

  while (curAddr != nullptr) {
    SOCKET hSockTemp =
        socket(curAddr->ai_family, curAddr->ai_socktype, curAddr->ai_protocol);

    rc = connect(hSockTemp, curAddr->ai_addr, (int)curAddr->ai_addrlen);
    if (rc == SOCKET_ERROR) {
      closesocket(hSockTemp);
      curAddr = curAddr->ai_next;
      continue;
    }

    hSock = hSockTemp;
    break;
  }

  freeaddrinfo(resAddrInfo);

  if (hSock == INVALID_SOCKET) {
    log_error("Failed to connect to %.*s:%.*s", FMT_SLICE(url.host),
              FMT_SLICE(url.port));
    return false;
  }

  log_info("Connected to %.*s:%.*s", FMT_SLICE(url.host), FMT_SLICE(url.port));

  i32 responseCode;
  Slice<u8> responseBody;
  b32 fetchStatus =
      fetchFromSocket(arena, hSock, url, responseCode, responseBody);
  closesocket(hSock);
  if (!fetchStatus) {
    return false;
  }

  res.body = responseBody;
  res.code = responseCode;
  return true;
}
