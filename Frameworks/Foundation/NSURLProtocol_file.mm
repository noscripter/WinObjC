/* Copyright (c) 2006-2007 Christopher J. W. Lloyd

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
documentation files (the "Software"), to deal in the Software without restriction, including without limitation the
rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit
persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the
Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

#import "Starboard.h"
#import "Foundation/NSMutableString.h"
#import "Foundation/NSURLProtocol.h"
#import "Foundation/NSMutableArray.h"
#import "Foundation/NSNumber.h"
#import "Foundation/NSMutableData.h"
#import "Foundation/NSMutableDictionary.h"
#import "Foundation/NSRunLoop.h"
#import "Foundation/NSTimer.h"
#import "Foundation/NSStream.h"
#import "NSInputStream_socket.h"
#import "NSOutputStream_socket.h"
#import "Foundation/NSError.h"
#import "Foundation/NSHTTPURLResponse.h"
#import "NSURLProtocol_file.h"
#import "NSURLProtocolInternal.h"
#import "LoggingNative.h"

static const wchar_t* TAG = L"NSURLProtocol_file";

@implementation NSURLProtocol_file
+ (void)load {
    [NSURLProtocol registerClass:self];
}

+ (BOOL)canInitWithRequest:(id)request {
    id scheme = [[request URL] scheme];

    if ([scheme isEqualToString:@"file"])
        return YES;

    return NO;
}

- (id)initWithRequest:(id)request cachedResponse:(id)response client:(id)client {
    [super initWithRequest:request cachedResponse:response client:client];

    _modes = [[NSMutableArray arrayWithObject:@"kCFRunLoopDefaultMode"] retain];

    id url = [_request URL];
    TraceVerbose(TAG, L"Loading %hs", [[url absoluteString] UTF8String]);

    _path = [[url path] copy];
    // id host = [NSHost hostWithName:hostName];

    return self;
}

- (id)startLoading {
    const char* pFilePath = [_path UTF8String];

    fpIn = EbrFopen(pFilePath, "rb");
    if (!fpIn) {
        TraceVerbose(TAG, L"Couldn't open %hs", pFilePath);
    } else {
        TraceVerbose(TAG, L"Opened %hs", pFilePath);
    }
    return self;
}

- (id)stopLoading {
    return self;
}

- (id)statusVersion:(id)versionStr {
    return self;
}

- (id)scheduleInRunLoop:(id)runLoop forMode:(id)mode {
    [runLoop performSelector:@selector(_doFileLoad) target:self argument:nil order:0 modes:[NSArray arrayWithObject:mode]];
    return self;
}

- (id)_doFileLoad {
    id url = [_request URL];

    if (fpIn == NULL) {
        TraceVerbose(TAG, L"doFileLoad: fpIn = NULL! self=%x", self);
        id error = [NSError errorWithDomain:@"Couldn't open file" code:100 userInfo:nil];
        [_client URLProtocol:self didFailWithError:error];
        return self;
    }

    EbrFseek(fpIn, 0, SEEK_END);
    int len = EbrFtell(fpIn);
    EbrFseek(fpIn, 0, SEEK_SET);

    char* pData = (char*)IwMalloc(len);
    len = EbrFread(pData, 1, len, fpIn);
    id dataReceived = [NSData dataWithBytes:pData length:len];
    IwFree(pData);

    EbrFclose(fpIn);

    [_client URLProtocol:self didReceiveResponse:nil cacheStoragePolicy:NSURLCacheStorageAllowed];
    [_client URLProtocol:self didLoadData:dataReceived];
    [_client URLProtocolDidFinishLoading:self];

    return self;
}

- (id)unscheduleFromRunLoop:(id)runLoop forMode:(id)mode {
    return self;
}

@end
