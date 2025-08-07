//
//  LlamaCppBridge.mm
//  LLMTest
//
//  Clean implementation using Swift wrapper for SpeziLLM integration
//

#import "LlamaCppBridge.h"
#import <CoreData/CoreData.h>
#import "LLMTest-Swift.h"
#include <string>
#include <vector>
#include <memory>
#include <mutex>

NSString * const LlamaCppBridgeErrorDomain = @"LlamaCppBridgeErrorDomain";

@interface LlamaCppBridge ()
{
    LlamaSwiftWrapper* _swiftWrapper;
    std::mutex _mutex;
}
@end

@implementation LlamaCppBridge

// MARK: - Initialization

- (instancetype)init {
    self = [super init];
    if (self) {
        _swiftWrapper = [[LlamaSwiftWrapper alloc] init];
    }
    return self;
}

- (void)dealloc {
    [self unloadModel];
    _swiftWrapper = nil;
}

// MARK: - Model Management

- (BOOL)loadModelAtPath:(NSString *)modelPath 
            contextSize:(int)contextSize 
                  error:(NSError **)error {
    std::lock_guard<std::mutex> lock(_mutex);
    
    // Validate input parameters
    if (!modelPath || modelPath.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:LlamaCppBridgeErrorDomain
                                         code:LlamaCppBridgeErrorInvalidParameters
                                     userInfo:@{NSLocalizedDescriptionKey: @"Model path cannot be empty"}];
        }
        return NO;
    }
    
    if (contextSize <= 0 || contextSize > 32768) {
        if (error) {
            *error = [NSError errorWithDomain:LlamaCppBridgeErrorDomain
                                         code:LlamaCppBridgeErrorInvalidParameters
                                     userInfo:@{NSLocalizedDescriptionKey: @"Context size must be between 1 and 32768"}];
        }
        return NO;
    }
    
    // Check if file exists
    if (![[NSFileManager defaultManager] fileExistsAtPath:modelPath]) {
        if (error) {
            *error = [NSError errorWithDomain:LlamaCppBridgeErrorDomain
                                         code:LlamaCppBridgeErrorModelNotFound
                                     userInfo:@{NSLocalizedDescriptionKey: @"Model file not found at specified path"}];
        }
        return NO;
    }
    
    // Load model using Swift wrapper
    BOOL success = [_swiftWrapper loadModelAtPath:modelPath 
                                      contextSize:contextSize 
                                          threads:4 
                                       gpuEnabled:NO];
    
    if (!success) {
        if (error) {
            *error = [NSError errorWithDomain:LlamaCppBridgeErrorDomain
                                         code:LlamaCppBridgeErrorModelLoadFailed
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to load model file"}];
        }
        return NO;
    }
    
    NSLog(@"[LlamaCppBridge] Model loaded successfully: %@ (context: %d)", modelPath, contextSize);
    return YES;
}

- (BOOL)isModelLoaded {
    std::lock_guard<std::mutex> lock(_mutex);
    return [_swiftWrapper getModelLoadedStatus];
}

- (void)unloadModel {
    std::lock_guard<std::mutex> lock(_mutex);
    [_swiftWrapper unloadModel];
    NSLog(@"[LlamaCppBridge] Model unloaded successfully");
}

// MARK: - Inference

- (nullable NSString *)generateTextWithPrompt:(NSString *)prompt
                                    maxTokens:(int)maxTokens
                                  temperature:(float)temperature
                                         topP:(float)topP
                                        error:(NSError **)error {
    std::lock_guard<std::mutex> lock(_mutex);
    
    if (![_swiftWrapper getModelLoadedStatus]) {
        if (error) {
            *error = [NSError errorWithDomain:LlamaCppBridgeErrorDomain
                                         code:LlamaCppBridgeErrorNoModelLoaded
                                     userInfo:@{NSLocalizedDescriptionKey: @"No model is currently loaded"}];
        }
        return nil;
    }
    
    if (!prompt || prompt.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:LlamaCppBridgeErrorDomain
                                         code:LlamaCppBridgeErrorInvalidParameters
                                     userInfo:@{NSLocalizedDescriptionKey: @"Prompt cannot be empty"}];
        }
        return nil;
    }
    
    if (maxTokens <= 0 || maxTokens > 4096) {
        if (error) {
            *error = [NSError errorWithDomain:LlamaCppBridgeErrorDomain
                                         code:LlamaCppBridgeErrorInvalidParameters
                                     userInfo:@{NSLocalizedDescriptionKey: @"Max tokens must be between 1 and 4096"}];
        }
        return nil;
    }
    
    // Use Swift wrapper for text generation
    NSString *result = [_swiftWrapper generateTextWithPrompt:prompt
                                                   maxTokens:maxTokens
                                                 temperature:temperature
                                                        topP:topP];
    
    if (!result) {
        if (error) {
            *error = [NSError errorWithDomain:LlamaCppBridgeErrorDomain
                                         code:LlamaCppBridgeErrorInferenceFailed
                                     userInfo:@{NSLocalizedDescriptionKey: @"Text generation failed"}];
        }
        return nil;
    }
    
    return result;
}

- (BOOL)generateTextStreamWithPrompt:(NSString *)prompt
                           maxTokens:(int)maxTokens
                         temperature:(float)temperature
                                topP:(float)topP
                            callback:(void (^)(NSString *token, BOOL isComplete))callback
                               error:(NSError **)error {
    std::lock_guard<std::mutex> lock(_mutex);
    
    if (![_swiftWrapper getModelLoadedStatus]) {
        if (error) {
            *error = [NSError errorWithDomain:LlamaCppBridgeErrorDomain
                                         code:LlamaCppBridgeErrorNoModelLoaded
                                     userInfo:@{NSLocalizedDescriptionKey: @"No model is currently loaded"}];
        }
        return NO;
    }
    
    if (!callback) {
        if (error) {
            *error = [NSError errorWithDomain:LlamaCppBridgeErrorDomain
                                         code:LlamaCppBridgeErrorInvalidParameters
                                     userInfo:@{NSLocalizedDescriptionKey: @"Callback cannot be nil"}];
        }
        return NO;
    }
    
    // Mock streaming implementation using Swift wrapper
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *fullResponse = [self generateTextWithPrompt:prompt 
                                                    maxTokens:maxTokens 
                                                  temperature:temperature 
                                                         topP:topP 
                                                        error:nil];
        
        if (fullResponse) {
            NSArray *words = [fullResponse componentsSeparatedByString:@" "];
            
            for (NSUInteger i = 0; i < words.count; i++) {
                NSString *token = words[i];
                if (i > 0) token = [@" " stringByAppendingString:token];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    callback(token, i == words.count - 1);
                });
                
                // Simulate streaming delay
                usleep(50000); // 50ms between tokens
            }
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                callback(@"", YES); // Signal completion with empty token
            });
        }
    });
    
    return YES;
}

// MARK: - Model Information

- (int)vocabularySize {
    std::lock_guard<std::mutex> lock(_mutex);
    return [_swiftWrapper vocabularySize];
}

- (int)contextLength {
    std::lock_guard<std::mutex> lock(_mutex);
    return [_swiftWrapper getContextSize];
}

- (int)embeddingSize {
    std::lock_guard<std::mutex> lock(_mutex);
    return [_swiftWrapper embeddingSize];
}

- (size_t)modelMemoryUsage {
    std::lock_guard<std::mutex> lock(_mutex);
    return [_swiftWrapper getModelSize];
}

- (void)clearMemoryCache {
    std::lock_guard<std::mutex> lock(_mutex);
    // Clear cache - placeholder implementation
    NSLog(@"[LlamaCppBridge] Clear cache called");
}

// MARK: - Missing Methods from Header

- (int)getVocabularySize {
    return [self vocabularySize];
}

- (int)getContextSize {
    return [self contextLength];
}

- (int)getEmbeddingSize {
    return [self embeddingSize];
}

- (size_t)getMemoryUsage {
    return [self modelMemoryUsage];
}

- (void)clearKVCache {
    [self clearMemoryCache];
}

- (nullable NSArray<NSNumber *> *)tokenizeText:(NSString *)text error:(NSError **)error {
    std::lock_guard<std::mutex> lock(_mutex);
    
    if (![_swiftWrapper getModelLoadedStatus]) {
        if (error) {
            *error = [NSError errorWithDomain:LlamaCppBridgeErrorDomain
                                         code:LlamaCppBridgeErrorNoModelLoaded
                                     userInfo:@{NSLocalizedDescriptionKey: @"No model is currently loaded"}];
        }
        return nil;
    }
    
    if (!text || text.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:LlamaCppBridgeErrorDomain
                                         code:LlamaCppBridgeErrorInvalidParameters
                                     userInfo:@{NSLocalizedDescriptionKey: @"Text cannot be empty"}];
        }
        return nil;
    }
    
    // TODO: Implement tokenization via SpeziLLM
    // For now, return mock token IDs based on word count
    NSArray *words = [text componentsSeparatedByString:@" "];
    NSMutableArray *tokenIds = [NSMutableArray array];
    
    for (NSUInteger i = 0; i < words.count; i++) {
        // Mock token ID based on word hash
        NSUInteger hash = [words[i] hash] % 32000; // Typical vocab size
        [tokenIds addObject:@(hash)];
    }
    
    return [tokenIds copy];
}

- (nullable NSString *)detokenizeTokenIds:(NSArray<NSNumber *> *)tokenIds error:(NSError **)error {
    std::lock_guard<std::mutex> lock(_mutex);
    
    if (![_swiftWrapper getModelLoadedStatus]) {
        if (error) {
            *error = [NSError errorWithDomain:LlamaCppBridgeErrorDomain
                                         code:LlamaCppBridgeErrorNoModelLoaded
                                     userInfo:@{NSLocalizedDescriptionKey: @"No model is currently loaded"}];
        }
        return nil;
    }
    
    if (!tokenIds || tokenIds.count == 0) {
        if (error) {
            *error = [NSError errorWithDomain:LlamaCppBridgeErrorDomain
                                         code:LlamaCppBridgeErrorInvalidParameters
                                     userInfo:@{NSLocalizedDescriptionKey: @"Token IDs cannot be empty"}];
        }
        return nil;
    }
    
    // TODO: Implement detokenization via SpeziLLM
    // For now, return mock text based on token count
    NSMutableArray *words = [NSMutableArray array];
    
    for (NSNumber *tokenId in tokenIds) {
        // Mock word based on token ID
        [words addObject:[NSString stringWithFormat:@"token_%@", tokenId]];
    }
    
    return [words componentsJoinedByString:@" "];
}

// MARK: - Configuration

- (void)setThreads:(int)threads {
    std::lock_guard<std::mutex> lock(_mutex);
    [_swiftWrapper setThreads:threads];
    NSLog(@"[LlamaCppBridge] Threads set to: %d", threads);
}

- (void)setGPUEnabled:(BOOL)enabled {
    std::lock_guard<std::mutex> lock(_mutex);
    [_swiftWrapper setGPUEnabled:enabled];
    NSLog(@"[LlamaCppBridge] GPU enabled: %@", enabled ? @"YES" : @"NO");
}

@end
