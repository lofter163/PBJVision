//
//  PBJMediaWriter.m
//  Vision
//
//  Created by Patrick Piemonte on 1/27/14.
//  Copyright (c) 2014 Patrick Piemonte. All rights reserved.
//

#import "PBJMediaWriter.h"
#import "PBJVisionUtilities.h"

#import <UIKit/UIDevice.h>
#import <MobileCoreServices/UTCoreTypes.h>


@interface PBJMediaWriter ()
{
    AVAssetWriter *_assetWriter;
	AVAssetWriterInput *_assetWriterAudioIn;
	AVAssetWriterInput *_assetWriterVideoIn;
    
    NSURL *_outputURL;
    BOOL _audioReady;
    BOOL _videoReady;
    BOOL _videoWrited;
}

@end

@implementation PBJMediaWriter

@synthesize outputURL = _outputURL;

#pragma mark - getters/setters

- (BOOL)isAudioReady
{
    return _audioReady;
}

- (BOOL)isVideoReady
{
    return _videoReady;
}

- (BOOL)isVideoWrited
{
    return _videoWrited;
}

- (NSError *)error
{
    return _assetWriter.error;
}

#pragma mark - init

- (id)initWithOutputURL:(NSURL *)outputURL
{
    self = [super init];
    if (self) {
        NSError *error = nil;
        _videoReady = NO;//初始化为未添加设备
        _audioReady = NO;
        _videoWrited = NO;
        _assetWriter = [[AVAssetWriter alloc] initWithURL:outputURL fileType:(NSString *)kUTTypeQuickTimeMovie error:&error];
        if (error) {
            WLogDebug(@"error setting up the asset writer (%@)", error);
            _assetWriter = nil;
            return nil;
        }

        _outputURL = outputURL;
        _assetWriter.shouldOptimizeForNetworkUse = YES;
        
        AVMutableMetadataItem *softwareItem = [[AVMutableMetadataItem alloc] init];
        [softwareItem setKeySpace:AVMetadataKeySpaceCommon];
        [softwareItem setKey:AVMetadataCommonKeySoftware];
        [softwareItem setValue:@"LOFTER"];
        
        _assetWriter.metadata = @[softwareItem];
        
        _audioTimestamp = kCMTimeInvalid;
        _videoTimestamp = kCMTimeInvalid;
        
        
        // It's possible to capture video without audio. If the user has denied access to the microphone, we don't need to setup the audio output device
        if ([[AVCaptureDevice class] respondsToSelector:@selector(authorizationStatusForMediaType:)]) {
            if ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio] == AVAuthorizationStatusDenied) {
                _audioReady = YES;
            }
        }
    }
    return self;
}

- (void)dealloc{
    NSLog(@"PBJMediaWriter dealloc");
    _assetWriter=nil;
	_assetWriterAudioIn=nil;
	_assetWriterVideoIn=nil;
}
#pragma mark - private


#pragma mark - sample buffer setup

- (BOOL)setupAudioOutputDeviceWithSettings:(NSDictionary *)audioSettings
{
	if ([_assetWriter canApplyOutputSettings:audioSettings forMediaType:AVMediaTypeAudio]) {
        
		_assetWriterAudioIn = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:audioSettings];
		_assetWriterAudioIn.expectsMediaDataInRealTime = YES;
        
		if ([_assetWriter canAddInput:_assetWriterAudioIn]) {
			[_assetWriter addInput:_assetWriterAudioIn];
            _audioReady = YES;
		} else {
			NSLog(@"严重错误:couldn't add asset writer audio input");
		}
        
	} else {
		NSLog(@"严重错误:couldn't apply audio output settings");
	}
    
    return _audioReady;
}

- (BOOL)setupVideoOutputDeviceWithSettings:(NSDictionary *)videoSettings
{
	if ([_assetWriter canApplyOutputSettings:videoSettings forMediaType:AVMediaTypeVideo]) {
    
		_assetWriterVideoIn = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
		_assetWriterVideoIn.expectsMediaDataInRealTime = YES;
		_assetWriterVideoIn.transform = CGAffineTransformIdentity;

		if ([_assetWriter canAddInput:_assetWriterVideoIn]) {
			[_assetWriter addInput:_assetWriterVideoIn];
            _videoReady = YES;
		} else {
			NSLog(@"严重错误:couldn't add asset writer video input");
		}
        
	} else {
    
		NSLog(@"严重错误:couldn't apply video output settings");
        
	}
    
    return _videoReady;
}

#pragma mark - sample buffer writing

- (void)writeSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(NSString *)mediaType
{
    if ( _assetWriter.status == AVAssetWriterStatusUnknown ) {
        if ([_assetWriter startWriting]) {
            CMTime startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
			[_assetWriter startSessionAtSourceTime:startTime];
            //NSLog(@"文件记录开始时间 (%ld)", (long)_assetWriter.status);
		} else {
			NSLog(@"严重错误: error when starting to write (%@)", [_assetWriter error]);
		}
	}
    
    if ( _assetWriter.status == AVAssetWriterStatusFailed ) {
        NSLog(@"严重错误:writer failure, (%@)", _assetWriter.error.localizedDescription);
        return;
    }
	
	if ( _assetWriter.status == AVAssetWriterStatusWriting ) {
        CMTime timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
		if (mediaType == AVMediaTypeVideo) {
			if (_assetWriterVideoIn.readyForMoreMediaData) {
				if ([_assetWriterVideoIn appendSampleBuffer:sampleBuffer]) {
					_videoWrited = YES;
                    _videoTimestamp = timestamp;
				}else{
                    NSLog(@"文件记录appendSampleBuffer出错 appending video (%@)", [_assetWriter error]);
                }
			}
		} else if (mediaType == AVMediaTypeAudio) {
			if (_assetWriterAudioIn.readyForMoreMediaData) {
				if ([_assetWriterAudioIn appendSampleBuffer:sampleBuffer]) {
					_audioTimestamp = timestamp;
				}else{
                    WLogDebug(@"文件记录appendSampleBuffer出错  appending audio (%@)", [_assetWriter error]);
                }
			}
		}
	}
    
}

- (void)finishWritingWithCompletionHandler:(void (^)(void))handler
{
    //WLogDebug(@"will finishWritingWithCompletionHandler");
    if(!_videoWrited){
        NSLog(@"严重错误:!_videoWrited");
        handler();
        return;
    }
    
    if (_assetWriter.status == AVAssetWriterStatusUnknown) {
        NSLog(@"严重错误:asset writer is in an unknown state, wasn't recording");
        handler();
        return;
    }
    
    [_assetWriter finishWritingWithCompletionHandler:handler];
    //WLogDebug(@"did finishWritingWithCompletionHandler");    
}


@end
