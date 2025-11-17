// llmchain.h
// LLM Chain - Interface for LLM inference
//
// Copyright RIME Developers
// Distributed under the BSD License

#ifndef LLMCHAIN_H
#define LLMCHAIN_H

#include <string>
#include <functional>

#ifdef RIME_ENABLE_LLAMA
// ============================================================
// llama.cpp Local Inference Interface
// ============================================================

/// Initialize llama service (call once at application startup)
/// @param model_path Path to .gguf model file
/// @param n_ctx Context window size (default: 512)
/// @param n_workers Number of worker threads (default: 2)
/// @param chat_template_path Optional path to jinja chat template file
/// @return true if initialization succeeded
bool llama_initialize(const std::string& model_path,
                     int n_ctx = 512,
                     int n_workers = 2,
                     const std::string& chat_template_path = "");

/// Synchronous generation interface (blocking)
/// @param prompt Input text prompt
/// @param max_tokens Maximum tokens to generate
/// @param context Optional context string (e.g., commit history)
/// @return Generated text or error string ("__BAD__", "__TIMEOUT__")
std::string llama_generate_sync(
    const std::string& prompt,
    int max_tokens = 32,
    const std::string& context = ""
);

/// Async generation interface (non-blocking)
/// @param prompt Input text prompt
/// @param on_complete Callback when generation completes
/// @param max_tokens Maximum tokens to generate
/// @param context Optional context string (e.g., commit history)
void llama_generate_async(
    const std::string& prompt,
    std::function<void(const std::string&)> on_complete,
    int max_tokens = 32,
    const std::string& context = ""
);

/// Shutdown llama service (call at application exit)
void llama_shutdown();

#else
// ============================================================
// HTTP Interface (Fallback - original ollama implementation)
// ============================================================

/// Synchronous HTTP-based generation (blocking)
std::string py_generate(const std::string& url,
                       const std::string& model,
                       const std::string& prompt,
                       const bool first_flag);

#endif // RIME_ENABLE_LLAMA

#endif // LLMCHAIN_H
