#pragma once

#include <stdio.h>
#include <stdlib.h>

// The C++ port throws som/error.h's Error, which nothing catches, so the
// process terminates. C has no exceptions: report and exit.
static inline _Noreturn void error(const char* what) {
  fprintf(stderr, "Error: %s\n", what);
  exit(1);
}
