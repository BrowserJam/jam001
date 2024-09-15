#include "std/Check.h"
#include "log/log.h"

#include <stdlib.h>

CHECK_NORETURN void checkFail(const char *pExpr,
                              const char *pFile,
                              unsigned line) {
  log_fatal("\n  Assertion failed: %s\n    at %s:%u\n", pExpr, pFile, line);
  abort();
}