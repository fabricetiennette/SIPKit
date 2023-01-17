#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdocumentation"
#import "PSCodecInfo.h"
#import "PSUtil.h"
#import <pjsua-lib/pjsua.h>
#import "PjSipPrivate.h"
#pragma clang diagnostic pop

@implementation PSCodecInfo {
    pjsua_codec_info _info;
}

- (id)initWithCodecInfo:(void *)buffer {
    self = [super init];
    if (self) {
        pjsua_codec_info *codecInfo = (pjsua_codec_info *)buffer;
        _info = *codecInfo;
    }
    return self;
}

- (NSString *)codecId {
    return [PSUtil stringWithPJString:&_info.codec_id];
}

- (NSString *)description {
    return [PSUtil stringWithPJString:&_info.desc];
}

- (NSUInteger)priority {
    return _info.priority;
}

- (BOOL)setPriority:(NSUInteger)newPriority {
    PSReturnNoIfFails(pjsua_codec_set_priority(&_info.codec_id, newPriority));
    _info.priority = newPriority; // update cached info
    return YES;
}

- (BOOL)setMaxPriority {
    return [self setPriority:254];
}


- (BOOL)disable {
    return [self setPriority:0]; // 0 disables the codec as said in pjsua online doc
}

@end
