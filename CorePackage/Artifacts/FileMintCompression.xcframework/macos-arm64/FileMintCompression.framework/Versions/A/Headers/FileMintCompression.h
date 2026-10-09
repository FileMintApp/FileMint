// SPDX-License-Identifier: LGPL-2.1-or-later
#ifndef FILEMINT_COMPRESSION_H
#define FILEMINT_COMPRESSION_H
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Synchronous, borrowed 8-bit sRGB premultiplied RGBA, tightly packed rows.
// The caller owns the validated pixels and a private staging path for the
// entire call. No source paths, metadata, decoding or format discovery API.
enum FMCompressionFormat {
    FMCompressionJPEG = 1,
    FMCompressionPNG = 2,
    FMCompressionTIFF = 3
};
__attribute__((visibility("default")))
int fm_compression_encode(const uint8_t *rgba, size_t length,
                          int width, int height, int format, int quality,
                          const char *staging_path);
__attribute__((visibility("default")))
const char *fm_compression_version(void);

#ifdef __cplusplus
}
#endif
#endif
