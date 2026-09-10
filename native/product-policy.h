#pragma once
#include <stdlib.h>
#include <string.h>
#define ARDESK_PRODUCT_ENVIRONMENT

static inline void ardesk_product_environment(void) {
    const char *exe = bionicx_getenv("BIONICX_EXECFN");
    const char *name = exe ? strrchr(exe, '/') : NULL;
    if (!name || (strcmp(name + 1, "pacman") && strcmp(name + 1, "pacman-key"))) return;
    setenv("BIONICX_VIRTUAL_ROOT", "1", 1);
    setenv("BIONICX_REWRITE_ABSOLUTE_SYMLINKS", "1", 1);
}
