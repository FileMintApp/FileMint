// SPDX-License-Identifier: LGPL-2.1-or-later
#include "FileMintCompression.h"
#include <pthread.h>
#include <vips/vips.h>

static pthread_once_t initialized = PTHREAD_ONCE_INIT;
static pthread_mutex_t job_lock = PTHREAD_MUTEX_INITIALIZER;
static int initialization_status = -1;

static void initialize(void) {
    initialization_status = vips_init("FileMintCompression");
    if (initialization_status == 0) {
        vips_concurrency_set(2);
        // Do not retain user pixels between jobs, or spill to temporary files.
        vips_cache_set_max(0);
        vips_cache_set_max_files(0);
    }
}

const char *fm_compression_version(void) { return VIPS_VERSION; }

int fm_compression_encode(const uint8_t *rgba, size_t length,
                          int width, int height, int format, int quality,
                          const char *staging_path) {
    if (!rgba || !staging_path || width < 1 || height < 1 ||
        width > 16384 || height > 16384 || width > 16000000 / height ||
        length != (size_t)width * (size_t)height * 4 ||
        format < FMCompressionJPEG || format > FMCompressionTIFF ||
        quality < 1 || quality > 100) return -1;
    pthread_once(&initialized, initialize);
    if (initialization_status != 0) return -1;
    // libvips' error buffer and global configuration are shared. Public Swift
    // jobs are serialized; also protect direct clients of the C interface.
    pthread_mutex_lock(&job_lock);
    int status = -1;
    VipsImage *memory = NULL, *srgb = NULL, *straight = NULL;
    VipsImage *rounded = NULL, *pixels = NULL, *rgb = NULL;
    memory = vips_image_new_from_memory(rgba, length, width, height, 4, VIPS_FORMAT_UCHAR);
    if (!memory || vips_copy(memory, &srgb, "interpretation", VIPS_INTERPRETATION_sRGB, NULL) ||
        vips_unpremultiply(srgb, &straight, "max_alpha", 255.0, NULL) ||
        vips_round(straight, &rounded, VIPS_OPERATION_ROUND_RINT, NULL) ||
        vips_cast(rounded, &pixels, VIPS_FORMAT_UCHAR, NULL)) goto cleanup;
    switch (format) {
        case FMCompressionJPEG:
            // The native sRGB context has already filled transparency white.
            if (vips_extract_band(pixels, &rgb, 0, "n", 3, NULL)) break;
            status = vips_jpegsave(rgb, staging_path, "Q", quality,
                "optimize_coding", TRUE, "interlace", TRUE,
                "trellis_quant", TRUE, "optimize_scans", TRUE,
                "keep", VIPS_FOREIGN_KEEP_ICC, "profile", "srgb", NULL);
            break;
        case FMCompressionPNG:
            status = vips_pngsave(pixels, staging_path, "compression", 9,
                "filter", VIPS_FOREIGN_PNG_FILTER_ALL, "palette", FALSE,
                "bitdepth", 8, "keep", VIPS_FOREIGN_KEEP_ICC, "profile", "srgb", NULL);
            break;
        case FMCompressionTIFF:
            status = vips_tiffsave(pixels, staging_path,
                "compression", VIPS_FOREIGN_TIFF_COMPRESSION_DEFLATE,
                "predictor", VIPS_FOREIGN_TIFF_PREDICTOR_HORIZONTAL,
                "level", 9, "premultiply", FALSE,
                "keep", VIPS_FOREIGN_KEEP_ICC, "profile", "srgb", NULL);
            break;
    }
cleanup:
    VIPS_UNREF(rgb);
    VIPS_UNREF(pixels);
    VIPS_UNREF(rounded);
    VIPS_UNREF(straight);
    VIPS_UNREF(srgb);
    VIPS_UNREF(memory);
    vips_error_clear(); // Do not expose source content or paths in diagnostics.
    pthread_mutex_unlock(&job_lock);
    return status;
}
