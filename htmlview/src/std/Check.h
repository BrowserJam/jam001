#pragma once

#if __cplusplus
extern "C" {
#endif

#ifdef _MSC_VER
#define CHECK_NORETURN __declspec(noreturn)
#elif __GNUC__ || __clang__
#define CHECK_NORETURN __attribute__((noreturn))
#else
#define CHECK_NORETURN
#endif

CHECK_NORETURN void checkFail(const char *pExpr,
                              const char *pFile,
                              unsigned line);

#if __cplusplus
}
#endif

#define CHECK(expression)    \
  (void)((!!(expression)) || \
         (checkFail((#expression), (__FILE__), (unsigned)(__LINE__)), 0))

#ifdef NDEBUG
#define DCHECK(expr) ((void)0)
#else
#define DCHECK(expr) CHECK(expr)
#endif

#define TODO() CHECK(!"TODO")
