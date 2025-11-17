// llmchain_c_bridge.h
// C Bridge for llama.cpp initialization - Swift compatible
//
// Copyright RIME Developers
// Distributed under the BSD License

#ifndef LLMCHAIN_C_BRIDGE_H
#define LLMCHAIN_C_BRIDGE_H

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Initialize llama service (C-compatible wrapper)
/// @param model_path Path to .gguf model file (C string)
/// @param n_ctx Context window size (default: 512)
/// @param n_workers Number of worker threads (default: 2)
/// @param chat_template_path Optional path to jinja chat template file (C string, can be NULL)
/// @return true if initialization succeeded
bool llama_initialize_c(const char* model_path, int n_ctx, int n_workers,
                       const char* chat_template_path);

/// Shutdown llama service (C-compatible wrapper)
void llama_shutdown_c(void);

#ifdef __cplusplus
}
#endif

#endif // LLMCHAIN_C_BRIDGE_H
