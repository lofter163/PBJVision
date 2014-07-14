//
//  PBJMediaWriter.h
//  Vision
//
//  Created by Patrick Piemonte on 1/27/14.
//  Copyright (c) 2014 Patrick Piemonte. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface PBJMediaWriter : NSObject

- (id)initWithOutputURL:(NSURL *)outputURL;

@property (nonatomic, readonly) NSURL *outputURL;
@property (nonatomic, readonly) NSError *error;

// setup output devices before writing

@property (nonatomic, readonly, getter=isAudioReady) BOOL audioReady;
@property (nonatomic, readonly, getter=isVideoReady) BOOL videoReady;

@property (nonatomic, readonly, getter=isVideoWrited) BOOL videoWrited;//已经写入视频

- (BOOL)setupAudioOutputDeviceWithSettings:(NSDictionary *)audioSettings;
- (BOOL)setupVideoOutputDeviceWithSettings:(NSDictionary *)videoSettings;

@property (nonatomic, readonly) CMTime audioTimestamp;
@property (nonatomic, readonly) CMTime videoTimestamp;

// write

- (void)writeSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(NSString *)mediaType;
- (void)finishWritingWithCompletionHandler:(void (^)(void))handler;

@end
