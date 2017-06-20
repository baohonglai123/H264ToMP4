//
//  H264ToMp4.h
//  MTLiveStreamingKit
//
//  Created by 包红来 on 2017/6/16.
//  Copyright © 2017年 LGW. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface H264ToMp4 : NSObject

@property (nonatomic) CGFloat rotate;
@property (nonatomic) NSString *filePath;

- (instancetype) initWithVideoSize:(CGSize) videoSize;
- (void) setupWithSPS:(NSData *)sps PPS:(NSData *)pps;
- (void) setup2;
- (void) pushH264Data:(unsigned char *)dataBuffer length:(uint32_t)len isIFrame:(BOOL)isIFrame timeOffset:(int64_t)timestamp;
- (void) pushSampleBufferRef:(CMSampleBufferRef) sampleBuffer;
- (void) endWritingCompletionHandler:(void (^)(void))handler;
@end
