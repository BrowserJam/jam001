#include "htmlview/OS.hpp"
#include "std/Utils.hpp"

#define WIN32_LEAN_AND_MEAN
#include "windows.h"

#include "winsock2.h"

void *os_reserve_vm(u64 size) {
  return VirtualAlloc(NULL, size, MEM_RESERVE, PAGE_READWRITE);
}

b32 os_commit_vm(void *ptr, u64 size) {
  return VirtualAlloc(ptr, size, MEM_COMMIT, PAGE_READWRITE) != NULL;
}

void os_sleep(u32 milliseconds) {
  Sleep(milliseconds);
}

void os_abort() {
  ExitProcess(1);
}

int AppEntry(Slice<Slice<u8>> argv);

#define NUM_MAX_ARGS (128)
static Slice<u8> gArgs[NUM_MAX_ARGS];

int main(int numArgs, char **arrArgs) {
  if (numArgs < 0) {
    return -1;
  }

  WSADATA wsaData;
  WSAStartup(MAKEWORD(2, 2), &wsaData);

  for (int idxArg = 0; idxArg < numArgs; idxArg++) {
    gArgs[idxArg] = {(u8 *)arrArgs[idxArg], (u32)strlen(arrArgs[idxArg])};
  }

  Slice<Slice<u8>> argv = {gArgs, (u32)numArgs};
  int rc = AppEntry(argv);

  WSACleanup();
  return rc;
}
