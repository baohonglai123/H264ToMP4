//
//  ViewController.m
//  H264ToMP4
//
//  Created by 包红来 on 2017/6/20.
//  Copyright © 2017年 包红来. All rights reserved.
//

#import "ViewController.h"
#import "H264ToMp4.h"

#define NAL_SLICE 1
#define NAL_SLICE_DPA 2
#define NAL_SLICE_DPB 3
#define NAL_SLICE_DPC 4
#define NAL_SLICE_IDR 5
#define NAL_SEI 6
#define NAL_SPS 7
#define NAL_PPS 8
#define NAL_AUD 9
#define NAL_FILLER 12

typedef struct _NaluUnit
{
    int type; //IDR or INTER：note：SequenceHeader is IDR too
    int size; //note: don't contain startCode
    unsigned char *data; //note: don't contain startCode
} NaluUnit;

@interface ViewController () {
    H264ToMp4 *_h264MP4;
    uint8_t   *_videoData;
    int       _cur_pos;
    int       _frameIndex;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.view.backgroundColor = [UIColor whiteColor];
    UIButton *startBt = [[UIButton alloc] initWithFrame:CGRectMake(0, 80, 100, 40)];
    [startBt setTitle:@"开始写入" forState:UIControlStateNormal];
    [startBt addTarget:self action:@selector(startWrite) forControlEvents:UIControlEventTouchUpInside];
    [startBt setBackgroundColor:[UIColor blueColor]];
    [self.view addSubview:startBt];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) startWrite {
    _h264MP4 = [[H264ToMp4 alloc] initWithVideoSize:CGSizeMake(480, 854)];
    NSString *path = [[NSBundle mainBundle] pathForResource:@"video" ofType:@"h264"];
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:path];
    NSData *allData = [fileHandle readDataToEndOfFile];
    _videoData = (uint8_t*)[allData bytes];
    
    NaluUnit naluUnit;
    NSData *sps = nil;
    NSData *pps = nil;
    int frame_size = 0;
    
    while(readOneNaluFromAnnexBFormatH264(&naluUnit, _videoData, allData.length, &_cur_pos))
    {
        _frameIndex ++;
        //        NSLog(@"naluUnit.type :%d,frameIndex:%d",naluUnit.type,_frameIndex);
        if(naluUnit.type == NAL_SPS || naluUnit.type == NAL_PPS || naluUnit.type == NAL_SEI) {
            if (naluUnit.type == NAL_SPS) {
                sps = [NSData dataWithBytes:naluUnit.data length:naluUnit.size];
            } else if(naluUnit.type == NAL_PPS) {
                pps = [NSData dataWithBytes:naluUnit.data length:naluUnit.size];
            } else {
                continue;
            }
            if (sps && pps) {
                [_h264MP4 setupWithSPS:sps PPS:pps];
            }
            continue;
        }
        //获取NALUS的长度，开辟内存
        frame_size += naluUnit.size;
        BOOL isIFrame = NO;
        if (naluUnit.type == NAL_SLICE_IDR) {
            isIFrame = YES;
        }
        frame_size = naluUnit.size + 4;
        uint8_t *frame_data = (uint8_t *) calloc(1, naluUnit.size + 4);//avcc header 占用4个字节
        uint32_t littleLength = CFSwapInt32HostToBig(naluUnit.size);
        uint8_t *lengthAddress = (uint8_t*)&littleLength;
        memcpy(frame_data, lengthAddress, 4);
        memcpy(frame_data+4, naluUnit.data, naluUnit.size);
        //        NSLog(@"frame_data:%d,%d,%d,%d",*frame_data,*(frame_data+1),*(frame_data+3),*(frame_data+3));
        [_h264MP4 pushH264Data:frame_data length:frame_size isIFrame:isIFrame timeOffset:0];
        free(frame_data);
        //        usleep(5*1000);
    }
    
    [_h264MP4 endWritingCompletionHandler:nil];
}

/**
 *  从data流中读取1个NALU
 *
 *  @param nalu     NaluUnit
 *  @param buf      data流指针
 *  @param buf_size data流长度
 *  @param cur_pos  当前位置
 *
 *  @return 成功 or 失败
 */
static bool readOneNaluFromAnnexBFormatH264(NaluUnit *nalu, unsigned char * buf, size_t buf_size, int *cur_pos)
{
    int i = *cur_pos;
    while(i + 2 < buf_size)
    {
        if(buf[i] == 0x00 && buf[i+1] == 0x00 && buf[i+2] == 0x01) {
            i = i + 3;
            int pos = i;
            while (pos + 2 < buf_size)
            {
                if(buf[pos] == 0x00 && buf[pos+1] == 0x00 && buf[pos+2] == 0x01)
                    break;
                pos++;
            }
            if(pos+2 == buf_size) {
                (*nalu).size = pos+2-i;
            } else {
                while(buf[pos-1] == 0x00)
                    pos--;
                (*nalu).size = pos-i;
            }
            (*nalu).type = buf[i] & 0x1f;
            (*nalu).data = buf + i;
            *cur_pos = pos;
            return true;
        } else {
            i++;
        }
    }
    return false;
}

@end
