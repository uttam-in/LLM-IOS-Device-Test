//
//  LlamaCppBridge.h
//  LLMTest
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Objective-C++ bridge for llama.cpp integration
 * This class provides a bridge between Swift and the C++ llama.cpp library
 */
@interface LlamaCppBridge : NSObject

// MARK: - Initialization
- (instancetype)init;
- (void)dealloc;

// MARK: - Model Management
/**
 * Load a model from the specified file path
 * @param modelPath The path to the GGML/GGUF model file
 * @param contextSize The context size for the model (default: 2048)
 * @param error Error object if loading fails
 * @return YES if successful, NO otherwise
 */
- (BOOL)loadModelAtPath:(NSString *)modelPath 
            contextSize:(int)contextSize 
                  error:(NSError **)error;

/**
 * Check if a model is currently loaded
 * @return YES if model is loaded, NO otherwise
 */
- (BOOL)isModelLoaded;

/**
 * Unload the current model and free memory
 */
- (void)unloadModel;

// MARK: - Inference
/**
 * Generate text completion for the given prompt
 * @param prompt The input text prompt
 * @param maxTokens Maximum number of tokens to generate
 * @param temperature Sampling temperature (0.0 to 2.0)
 * @param topP Top-p sampling parameter
 * @param error Error object if inference fails
 * @return Generated text or nil if failed
 */
- (nullable NSString *)generateTextWithPrompt:(NSString *)prompt
                                    maxTokens:(int)maxTokens
                                  temperature:(float)temperature
                                         topP:(float)topP
                                        error:(NSError **)error;

/**
 * Generate text with streaming callback
 * @param prompt The input text prompt
 * @param maxTokens Maximum number of tokens to generate
 * @param temperature Sampling temperature
 * @param topP Top-p sampling parameter
 * @param callback Callback block called for each generated token
 * @param error Error object if inference fails
 * @return YES if successful, NO otherwise
 */
- (BOOL)generateTextStreamWithPrompt:(NSString *)prompt
                           maxTokens:(int)maxTokens
                         temperature:(float)temperature
                                topP:(float)topP
                            callback:(void (^)(NSString *token, BOOL isComplete))callback
                               error:(NSError **)error;

// MARK: - Model Information
/**
 * Get the vocabulary size of the loaded model
 * @return Vocabulary size or 0 if no model loaded
 */
- (int)getVocabularySize;

/**
 * Get the context size of the loaded model
 * @return Context size or 0 if no model loaded
 */
- (int)getContextSize;

/**
 * Get the embedding size of the loaded model
 * @return Embedding size or 0 if no model loaded
 */
- (int)getEmbeddingSize;

// MARK: - Memory Management
/**
 * Get current memory usage in bytes
 * @return Memory usage in bytes
 */
- (size_t)getMemoryUsage;

/**
 * Clear the KV cache to free memory
 */
- (void)clearKVCache;

// MARK: - Tokenization
/**
 * Tokenize text into token IDs
 * @param text Input text to tokenize
 * @param error Error object if tokenization fails
 * @return Array of token IDs as NSNumbers
 */
- (nullable NSArray<NSNumber *> *)tokenizeText:(NSString *)text error:(NSError **)error;

/**
 * Detokenize token IDs back to text
 * @param tokenIds Array of token IDs as NSNumbers
 * @param error Error object if detokenization fails
 * @return Detokenized text or nil if failed
 */
- (nullable NSString *)detokenizeTokenIds:(NSArray<NSNumber *> *)tokenIds error:(NSError **)error;

// MARK: - Configuration
/**
 * Set the number of threads for inference
 * @param threads Number of threads (default: 4)
 */
- (void)setThreads:(int)threads;

/**
 * Enable or disable GPU acceleration if available
 * @param enabled YES to enable GPU, NO to disable
 */
- (void)setGPUEnabled:(BOOL)enabled;

@end

// MARK: - Error Domain
extern NSString * const LlamaCppBridgeErrorDomain;

// MARK: - Error Codes
typedef NS_ENUM(NSInteger, LlamaCppBridgeError) {
    LlamaCppBridgeErrorModelNotFound = 1000,
    LlamaCppBridgeErrorModelLoadFailed = 1001,
    LlamaCppBridgeErrorContextCreationFailed = 1002,
    LlamaCppBridgeErrorInferenceFailed = 1003,
    LlamaCppBridgeErrorInvalidParameters = 1004,
    LlamaCppBridgeErrorOutOfMemory = 1005,
    LlamaCppBridgeErrorTokenizationFailed = 1006,
    LlamaCppBridgeErrorNoModelLoaded = 1007
};

NS_ASSUME_NONNULL_END