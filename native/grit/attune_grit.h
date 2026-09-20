#ifndef ATTUNE_GRIT_H
#define ATTUNE_GRIT_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Runs one Grit program over one in-memory source file.
 *
 * Every input is a byte slice; embedded NUL bytes are data. On return,
 * out_data/out_len own a UTF-8 JSON envelope allocated by Rust. The caller
 * must release it exactly once with attune_grit_buffer_free. A non-zero status
 * is reserved for host/ABI failures; ordinary compile and language errors are
 * classified in the JSON envelope.
 */
int32_t attune_grit_run(
    const uint8_t *language, size_t language_len,
    const uint8_t *program, size_t program_len,
    const uint8_t *path, size_t path_len,
    const uint8_t *source, size_t source_len,
    uint8_t **out_data, size_t *out_len
);

/* Releases the exact data/length pair returned by attune_grit_run. */
void attune_grit_buffer_free(uint8_t *data, size_t len);

#ifdef __cplusplus
}
#endif

#endif
