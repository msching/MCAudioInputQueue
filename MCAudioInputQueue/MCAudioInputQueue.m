//
//  MCAudioInputQueue.m
//  MCAudioQueue
//
//  Created by Chengyin on 15-4-6.
//  Copyright (c) 2015年 Chengyin. All rights reserved.
//

#import "MCAudioInputQueue.h"

const int MCAudioQueueBufferCount = 3;

@interface MCAudioInputQueue ()
{
@private
    __weak id<MCAudioInputQueueDelegate> _delegate;
    AudioQueueRef _audioQueue;
    
    BOOL _started;
    BOOL _isRunning;
    UInt32 _bufferSize;
    NSMutableData *_buffer;
    
    AudioQueueLevelMeterState *_meterStateDB;
}
@end

@implementation MCAudioInputQueue
@synthesize format = _format;
@synthesize bufferDuration = _bufferDuration;
@synthesize bufferSize = _bufferSize;
@synthesize isRunning = _isRunning;
@synthesize delegate = _delegate;
@dynamic available;

#pragma mark - init & dealloc
+ (instancetype)inputQueueWithFormat:(AudioStreamBasicDescription)format bufferDuration:(NSTimeInterval)bufferDuration delegate:(id<MCAudioInputQueueDelegate>)delegate
{
    return [[self alloc] initWithFormat:format bufferDuration:bufferDuration delegate:delegate];
}

- (instancetype)initWithFormat:(AudioStreamBasicDescription)format bufferDuration:(NSTimeInterval)bufferDuration delegate:(id<MCAudioInputQueueDelegate>)delegate
{
    if (bufferDuration <= 0)
    {
        return nil;
    }
    
    self = [super init];
    if (self)
    {
        _format = format;
        _bufferDuration = bufferDuration;
        
        //lenInByte = bitDepth * channelCount * samplerate * duration / 8;
        _bufferSize = _format.mBitsPerChannel * _format.mChannelsPerFrame * _format.mSampleRate * _bufferDuration / 8;
        _buffer = [[NSMutableData alloc] init];
        
        _meterStateDB = malloc(sizeof(AudioQueueLevelMeterState) * _format.mChannelsPerFrame);
        
        _delegate = delegate;
        [self _createAudioInputQueue];
        [self _updateMeteringEnabled];
    }
    return self;
}


- (void)dealloc
{
    free(_meterStateDB);
    [self _disposeAudioOutputQueue];
}

#pragma mark - error
- (void)_errorForOSStatus:(OSStatus)status error:(NSError *__autoreleasing *)outError
{
    if (status != noErr && outError != NULL)
    {
        *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
    }
}

- (BOOL)_checkAudioQueueSuccess:(OSStatus)status
{
    if (status != noErr)
    {
        if (_audioQueue)
        {
            AudioQueueDispose(_audioQueue, YES);
            _audioQueue = NULL;
        }
        
        NSError *error = nil;
        [self _errorForOSStatus:status error:&error];
        [_delegate inputQueue:self errorOccur:error];
        return NO;
    }
    return YES;
}

#pragma mark - audio queue
- (void)_createAudioInputQueue
{
    if (![self _checkAudioQueueSuccess:AudioQueueNewInput(&_format, MCAudioQueueInuputCallback, (__bridge void *)(self), NULL, NULL, 0, &_audioQueue)])
    {
        return;
    }
    
    AudioQueueAddPropertyListener(_audioQueue, kAudioQueueProperty_IsRunning, MCAudioInputQueuePropertyCallback, (__bridge void *)(self));
    
    for (int i = 0; i < MCAudioQueueBufferCount; ++i)
    {
        AudioQueueBufferRef buffer;
        if (![self _checkAudioQueueSuccess:AudioQueueAllocateBuffer(_audioQueue, _bufferSize, &buffer)])
        {
            break;
        }
        
        if (![self _checkAudioQueueSuccess:AudioQueueEnqueueBuffer(_audioQueue, buffer, 0, NULL)])
        {
            break;
        }
    }
}

- (void)_disposeAudioOutputQueue
{
    [self stop];
    if (_audioQueue != NULL)
    {
        AudioQueueDispose(_audioQueue,true);
        _audioQueue = NULL;
    }
}

- (BOOL)start
{
    OSStatus status = AudioQueueStart(_audioQueue, NULL);
    _started = status == noErr;
    return _started;
}

- (BOOL)pause
{
    OSStatus status = AudioQueuePause(_audioQueue);
    return status == noErr;
}

- (BOOL)reset
{
    OSStatus status = AudioQueueReset(_audioQueue);
    return status == noErr;
}

- (BOOL)stop
{
    _started = NO;
    OSStatus status = AudioQueueStop(_audioQueue, true);
    return status == noErr;
}

- (BOOL)available
{
    return _audioQueue != NULL;
}

#pragma mark - metering
- (void)_updateMeteringEnabled
{
    UInt32 size = sizeof(UInt32);
    UInt32 enabledLevelMeter = 0;
    [self getProperty:kAudioQueueProperty_EnableLevelMetering dataSize:&size data:&enabledLevelMeter error:nil];
    _meteringEnabled = enabledLevelMeter == 0 ? NO : YES;
}

- (void)setMeteringEnabled:(BOOL)meteringEnabled
{
    _meteringEnabled = meteringEnabled;
    UInt32 enabledLevelMeter = _meteringEnabled ? 1 : 0;
    [self setProperty:kAudioQueueProperty_EnableLevelMetering dataSize:sizeof(UInt32) data:&enabledLevelMeter error:nil];
}

- (void)updateMeters
{
    UInt32 size = sizeof(AudioQueueLevelMeterState) * _format.mChannelsPerFrame;
    [self getProperty:kAudioQueueProperty_CurrentLevelMeterDB dataSize:&size data:_meterStateDB error:nil];
}

- (float)peakPowerForChannel:(NSUInteger)channelNumber
{
    if (channelNumber >= _format.mChannelsPerFrame)
    {
        return -160.0f;
    }
    return _meterStateDB[channelNumber].mPeakPower;
}

- (float)averagePowerForChannel:(NSUInteger)channelNumber
{
    if (channelNumber >= _format.mChannelsPerFrame)
    {
        return -160.0f;
    }
    return _meterStateDB[channelNumber].mAveragePower;
}

#pragma mark - property & paramters
- (BOOL)setProperty:(AudioQueuePropertyID)propertyID dataSize:(UInt32)dataSize data:(const void *)data error:(NSError *__autoreleasing *)outError
{
    OSStatus status = AudioQueueSetProperty(_audioQueue, propertyID, data, dataSize);
    [self _errorForOSStatus:status error:outError];
    return status == noErr;
}

- (BOOL)getProperty:(AudioQueuePropertyID)propertyID dataSize:(UInt32 *)dataSize data:(void *)data error:(NSError *__autoreleasing *)outError
{
    OSStatus status = AudioQueueGetProperty(_audioQueue, propertyID, data, dataSize);
    [self _errorForOSStatus:status error:outError];
    return status == noErr;
}

- (BOOL)getPropertySize:(AudioQueuePropertyID)propertyID dataSize:(UInt32 *)dataSize error:(NSError *__autoreleasing *)outError
{
    OSStatus status = AudioQueueGetPropertySize(_audioQueue, propertyID, dataSize);
    [self _errorForOSStatus:status error:outError];
    return status == noErr;
}

- (BOOL)setParameter:(AudioQueueParameterID)parameterId value:(AudioQueueParameterValue)value error:(NSError *__autoreleasing *)outError
{
    OSStatus status = AudioQueueSetParameter(_audioQueue, parameterId, value);
    [self _errorForOSStatus:status error:outError];
    return status == noErr;
}

- (BOOL)getParameter:(AudioQueueParameterID)parameterId value:(AudioQueueParameterValue *)value error:(NSError *__autoreleasing *)outError
{
    OSStatus status = AudioQueueGetParameter(_audioQueue, parameterId, value);
    [self _errorForOSStatus:status error:outError];
    return status == noErr;
}

#pragma mark - call back
static void MCAudioQueueInuputCallback(void *inClientData,
                                       AudioQueueRef inAQ,
                                       AudioQueueBufferRef inBuffer,
                                       const AudioTimeStamp *inStartTime,
                                       UInt32 inNumberPacketDescriptions,
                                       const AudioStreamPacketDescription *inPacketDescs)
{
	MCAudioInputQueue *audioOutputQueue = (__bridge MCAudioInputQueue *)inClientData;
	[audioOutputQueue handleAudioQueueOutputCallBack:inAQ
                                              buffer:inBuffer
                                         inStartTime:inStartTime
                          inNumberPacketDescriptions:inNumberPacketDescriptions
                                       inPacketDescs:inPacketDescs];
}

- (void)handleAudioQueueOutputCallBack:(AudioQueueRef)audioQueue
                                buffer:(AudioQueueBufferRef)buffer
                           inStartTime:(const AudioTimeStamp *)inStartTime
            inNumberPacketDescriptions:(UInt32)inNumberPacketDescriptions
                         inPacketDescs:(const AudioStreamPacketDescription *)inPacketDescs
{
    if (_started)
    {
        [_buffer appendBytes:buffer->mAudioData length:buffer->mAudioDataByteSize];
        if ([_buffer length] >= _bufferSize)
        {
            NSRange range = NSMakeRange(0, _bufferSize);
            NSData *subData = [_buffer subdataWithRange:range];
            [_delegate inputQueue:self inputData:subData numberOfPackets:inNumberPacketDescriptions];
            [_buffer replaceBytesInRange:range withBytes:NULL length:0];
        }
        [self _checkAudioQueueSuccess:AudioQueueEnqueueBuffer(_audioQueue, buffer, 0, NULL)];
    }
}

- (void)handleAudioQueuePropertyCallBack:(AudioQueueRef)audioQueue property:(AudioQueuePropertyID)property
{
    if (property == kAudioQueueProperty_IsRunning)
    {
        UInt32 isRunning = 0;
        UInt32 size = sizeof(isRunning);
        AudioQueueGetProperty(audioQueue, property, &isRunning, &size);
        _isRunning = isRunning;
    }
}

static void MCAudioInputQueuePropertyCallback(void *inUserData, AudioQueueRef inAQ, AudioQueuePropertyID inID)
{
    __unsafe_unretained MCAudioInputQueue *audioQueue = (__bridge MCAudioInputQueue *)inUserData;
    [audioQueue handleAudioQueuePropertyCallBack:inAQ property:inID];
}
@end
