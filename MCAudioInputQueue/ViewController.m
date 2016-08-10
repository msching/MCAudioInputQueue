//
//  ViewController.m
//  MCAudioInputQueue
//
//  Created by Chengyin on 15-4-7.
//  Copyright (c) 2015年 Chengyin. All rights reserved.
//

#import "ViewController.h"
#import "MCAudioInputQueue.h"
#import "AVAudioPlayer+PCM.h"
#import <AVFoundation/AVAudioSession.h>

static const NSTimeInterval bufferDuration = 0.2;

@interface ViewController ()<MCAudioInputQueueDelegate>
{
@private
    AudioStreamBasicDescription _format;
    BOOL _inited;
    
    MCAudioInputQueue *_recorder;
    BOOL _started;
    
    NSMutableData *_data;
    AVAudioPlayer *_player;
}
@property (nonatomic,strong) IBOutlet UIButton *startOrStopButton;
@property (nonatomic,strong) IBOutlet UIButton *playButton;
@property (nonatomic,strong) IBOutlet UILabel  *durationLabel;
@end

@implementation ViewController

#pragma mark - init & dealloc
- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        [self _commonInit];
    }
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    [self _commonInit];
}

- (void)_commonInit
{
    if (_inited)
    {
        return;
    }
    
    _inited = YES;
    
    _format.mFormatID = kAudioFormatLinearPCM;
    _format.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    _format.mBitsPerChannel = 16;
    _format.mChannelsPerFrame = 2;
    _format.mBytesPerPacket = _format.mBytesPerFrame = (_format.mBitsPerChannel / 8) * _format.mChannelsPerFrame;
    _format.mFramesPerPacket = 1;
    _format.mSampleRate = 8000.0f;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_interrupted:) name:AVAudioSessionInterruptionNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_interrupted:) name:AVAudioSessionRouteChangeNotification object:nil];
    
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
}

- (void)dealloc
{
    [_recorder stop];
    [_player stop];
    
    [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - lifecycle
- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [self _refreshUI];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - ui actions
- (IBAction)startOrStop:(id)sender
{
    if (_started)
    {
        [self _stopRecord];
    }
    else
    {
        [self _startRecord];
    }
}

- (IBAction)play:(id)sender
{
    [self _play];
}

- (void)_refreshUI
{
    if (_started)
    {
        [self.startOrStopButton setTitle:@"Stop" forState:UIControlStateNormal];
    }
    else
    {
        [self.startOrStopButton setTitle:@"Start" forState:UIControlStateNormal];
    }
    
    self.playButton.enabled = !_started && _data.length > 0;
}

#pragma mark - play
- (void)_play
{
    [_player stop];
    _player = [[AVAudioPlayer alloc] initWithPcmData:_data pcmFormat:_format error:nil];
    [_player play];
}

#pragma mark - record
- (void)_startRecord
{
    if (_started)
    {
        return;
    }
    
    [_player stop];
    _started = YES;
    
    _data = [NSMutableData data];
    _recorder = [MCAudioInputQueue inputQueueWithFormat:_format bufferDuration:bufferDuration delegate:self];
    _recorder.meteringEnabled = YES;
    [_recorder start];
    
    [self _refreshUI];
}

- (void)_stopRecord
{
    if (!_started)
    {
        return;
    }
    
    _started = NO;
    
    [_recorder stop];
    _recorder = nil;
    
    [self _refreshUI];
}

#pragma mark - interrupt
- (void)_interrupted:(NSNotification *)notification
{
    [self _stopRecord];
    [_player stop];
}

#pragma mark - inputqueue delegate
- (void)inputQueue:(MCAudioInputQueue *)inputQueue inputData:(NSData *)data numberOfPackets:(UInt32)numberOfPackets
{
    if (data)
    {
        [_data appendData:data];
    }
    
    [inputQueue updateMeters];
    NSLog(@"channel 0 averagePower = %lf, peakPower = %lf",[inputQueue averagePowerForChannel:0],[inputQueue peakPowerForChannel:0]);
    NSLog(@"channel 1 averagePower = %lf, peakPower = %lf",[inputQueue averagePowerForChannel:1],[inputQueue peakPowerForChannel:1]);
    
    double duration = _data.length / _recorder.bufferSize * _recorder.bufferDuration;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *durationString = [NSString stringWithFormat:@"duration = %.1lfs",duration];
        self.durationLabel.text = durationString;
    });
}

- (void)inputQueue:(MCAudioInputQueue *)inputQueue errorOccur:(NSError *)error
{
    [self _stopRecord];
}
@end
