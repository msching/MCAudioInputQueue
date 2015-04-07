# MCAudioInputQueue
Simple Recorder based on AudioQueue


# Usage

init & start

``` objc
MCAudioInputQueue *_recorder;
```

```objc

AudioStreamBasicDescription format;
format.mFormatID = kAudioFormatLinearPCM;
format.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
format.mBitsPerChannel = 16;
format.mChannelsPerFrame = 1;
format.mBytesPerPacket = _format.mBytesPerFrame = (_format.mBitsPerChannel / 8) * format.mChannelsPerFrame;
format.mFramesPerPacket = 1;
format.mSampleRate = 8000.0f;

_recorder = [[MCAudioInputQueue alloc] initWithFormat:format bufferDuration:1 delegate:self];
[_recorder start];
```

handle data & error

```objc
- (void)inputQueue:(MCAudioInputQueue *)inputQueue inputData:(NSData *)data numberOfPackets:(UInt32)numberOfPackets
{
    //handle data
}

- (void)inputQueue:(MCAudioInputQueue *)inputQueue errorOccur:(NSError *)error
{
    //handle error
}

```