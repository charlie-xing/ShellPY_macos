// llama_service.h
// Rime LLM Service - Local inference with llama.cpp
//
// Copyright RIME Developers
// Distributed under the BSD License
//
// 2025-11-01 Claude Code Integration

#ifndef RIME_LLAMA_SERVICE_H_
#define RIME_LLAMA_SERVICE_H_

#ifdef RIME_ENABLE_LLAMA

#include <string>
#include <functional>
#include <memory>
#include <mutex>
#include <atomic>
#include <queue>
#include <thread>
#include <condition_variable>
#include <vector>

// Forward declare llama.cpp types to avoid including headers here
struct llama_model;
struct llama_context;
struct llama_sampler;

namespace rime {

/// Request structure for generation tasks
struct GenerateRequest {
    uint64_t id;
    std::string prompt;
    std::string context;  // Optional: context string (e.g., commit history)
    int max_tokens;
    std::function<void(const std::string&)> on_token;     // Optional: per-token callback
    std::function<void(const std::string&)> on_complete;  // Required: completion callback
    std::function<void(const std::string&)> on_error;     // Required: error callback
};

// Forward declaration
class LlamaWorkerPool;

/// Main service class - Singleton pattern for managing llama.cpp model
class LlamaService {
public:
    /// Get singleton instance
    static LlamaService& getInstance();

    /// Initialize the service with model file
    /// @param model_path Path to .gguf model file
    /// @param n_ctx Context window size (default: 512 for pinyin)
    /// @param n_workers Number of worker threads (default: 2)
    /// @param chat_template_path Optional path to jinja chat template file
    /// @return true if initialization succeeded
    bool initialize(const std::string& model_path,
                   int n_ctx = 512,
                   int n_workers = 2,
                   const std::string& chat_template_path = "");

    /// Submit async generation request
    /// @param prompt Input text prompt
    /// @param context Optional context string (e.g., commit history)
    /// @param on_token Optional callback for each generated token
    /// @param on_complete Required callback when generation completes
    /// @param on_error Required callback on error
    /// @param max_tokens Maximum tokens to generate
    /// @return Request ID (0 on error)
    uint64_t generateAsync(
        const std::string& prompt,
        const std::string& context,
        std::function<void(const std::string&)> on_token,
        std::function<void(const std::string&)> on_complete,
        std::function<void(const std::string&)> on_error,
        int max_tokens = 32
    );

    /// Cancel a pending or running request
    /// @param request_id The request ID returned by generateAsync
    void cancelGeneration(uint64_t request_id);

    /// Shutdown service and free resources
    void shutdown();

    /// Check if service is initialized
    bool isInitialized() const { return initialized_; }

private:
    // Singleton - private constructor/destructor
    LlamaService() = default;
    ~LlamaService();

    // Disable copy/move
    LlamaService(const LlamaService&) = delete;
    LlamaService& operator=(const LlamaService&) = delete;

    llama_model* model_ = nullptr;
    std::unique_ptr<LlamaWorkerPool> worker_pool_;
    std::atomic<bool> initialized_{false};
    std::atomic<uint64_t> next_request_id_{1};
    std::mutex mutex_;
    std::string chat_template_;  // Jinja template for prompt formatting
};

/// Worker thread pool for parallel inference
class LlamaWorkerPool {
public:
    /// Constructor
    /// @param model Shared model pointer (thread-safe to read)
    /// @param num_workers Number of worker threads to create
    /// @param n_ctx Context size for each worker
    /// @param chat_template Jinja chat template string (empty for simple formatting)
    LlamaWorkerPool(llama_model* model, int num_workers, int n_ctx,
                    const std::string& chat_template = "");

    /// Destructor - stops all workers
    ~LlamaWorkerPool();

    /// Submit request to worker pool
    void submitRequest(GenerateRequest request);

    /// Gracefully shutdown all workers
    void shutdown();

private:
    /// Worker thread state
    struct Worker {
        std::thread thread;
        llama_context* ctx = nullptr;
        llama_sampler* sampler = nullptr;
        std::queue<GenerateRequest> request_queue;
        std::mutex queue_mutex;
        std::condition_variable cv;
        bool shutdown = false;
        int worker_id;
    };

    /// Worker thread main loop
    void workerLoop(Worker& worker);

    /// Process a single request
    void processRequest(Worker& worker, const GenerateRequest& request);

    std::vector<std::unique_ptr<Worker>> workers_;
    std::atomic<uint32_t> next_worker_idx_{0};  // Round-robin scheduling
    std::string chat_template_;  // Shared chat template string
    llama_model* model_;  // Store model pointer for chat template API
};

} // namespace rime

#endif // RIME_ENABLE_LLAMA
#endif // RIME_LLAMA_SERVICE_H_
