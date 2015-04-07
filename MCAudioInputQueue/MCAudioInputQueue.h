//
//  MCAudioInputQueue
//  MCAudioQueue
//
//  Created by Chengyin on 15-4-6.
//  Copyright (c) 2015年 Chengyin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@class MCAudioInputQueue;
@protocol MCAudioInputQueueDelegate <NSObject>
@required
- (void)inputQueue:(MCAudioInputQueue *)inputQueue inputData:(NSData *)data numberOfPackets:(UInt32)numberOfPackets;
- (void)inputQueue:(MCAudioInputQueue *)inputQueue errorOccur:(NSError *)error;
@end

@interface MCAudioInputQueue : NSObject

@property (nonatomic,weak,readonly) id<MCAudioInputQueueDelegate> delegate;
@property (nonatomic,assign,readonly) BOOL available;
@property (nonatomic,assign,readonly) BOOL isRunning;
@property (nonatomic,assign,readonly) AudioStreamBasicDescription format;
@property (nonatomic,assign,readonly) NSTimeInterval bufferDuration;
@property (nonatomic,assign,readonly) UInt32 bufferSize;

+ (instancetype)queueWithFormat:(AudioStreamBasicDescription)format bufferDuration:(NSTimeInterval)bufferDuration delegate:(id<MCAudioInputQueueDelegate>)delegate;
- (instancetype)initWithFormat:(AudioStreamBasicDescription)format bufferDuration:(NSTimeInterval)bufferDuration delegate:(id<MCAudioInputQueueDelegate>)delegate;

- (BOOL)start;
- (BOOL)pause;
- (BOOL)stop;
- (BOOL)reset;

- (BOOL)setProperty:(AudioQueuePropertyID)propertyID dataSize:(UInt32)dataSize data:(const void *)data error:(NSError **)outError;
- (BOOL)getProperty:(AudioQueuePropertyID)propertyID dataSize:(UInt32 *)dataSize data:(void *)data error:(NSError **)outError;
- (BOOL)setParameter:(AudioQueueParameterID)parameterId value:(AudioQueueParameterValue)value error:(NSError **)outError;
- (BOOL)getParameter:(AudioQueueParameterID)parameterId value:(AudioQueueParameterValue *)value error:(NSError **)outError;
@end
