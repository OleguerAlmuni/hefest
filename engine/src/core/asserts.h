#pragma once

#include "defines.h"

// Dissable assertions by commenting out the following line
#define HASSERTIONS_ENABLED

#ifdef HASSERTIONS_ENABLED
#if _MSC_VER
#include <intrin.h>
#define debug_break() __debugbreak()
#else
#define debug_break() __builtin_trap()
#endif

HAPI void report_assertion_failure(const char* expression, const char* message, const char* file, i32 line);

#define HASSERT(expr)                                                \
    {                                                                \
        if (expr) {                                                  \
        } else {                                                     \
            report_assertion_failure(#expr, "", __FILE__, __LINE__); \
            debug_break();                                           \
        }                                                            \
    }

#define HASSERT_MSG(expr, message)                                        \
    {                                                                 \
        if (expr) {                                                   \
        } else {                                                      \
            report_assertion_failure(#expr, message, __FILE__, __LINE__); \
            debug_break();                                            \
        }                                                             \
    }

#ifdef _DEBUG
#define HASSERT_DEBUG(expr)                                          \
    {                                                                \
        if (expr) {                                                  \
        } else {                                                     \
            report_assertion_failure(#expr, "", __FILE__, __LINE__); \
            debug_break();                                           \
        }                                                            \
    }
#else
#define HASSERT_DEBUG(expr) // Does nothing
#endif

#else
#define HASSERT(expr) // Does nothing
#define HASSERT_MSG(expr, message) // Does nothing
#define HASSERT_DEBUG(expr) // Does nothing
#endif