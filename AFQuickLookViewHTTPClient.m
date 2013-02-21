// AFQuickLookViewHTTPClient.m
// Copyright (c) 2013 XING AG (http://www.xing.com/)

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "AFQuickLookViewHTTPClient.h"
#import <AFNetworking.h>

static AFQuickLookViewHTTPClient *_sharedClient = nil;

@implementation AFQuickLookViewHTTPClient

+ (AFQuickLookViewHTTPClient*)sharedClient {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (_sharedClient == nil) {
            NSURL* baseURL = [NSURL URLWithString:@"http://your-api.example.com"];
            _sharedClient = [[AFQuickLookViewHTTPClient alloc] initWithBaseURL:baseURL];
        }
    });
    return _sharedClient;
}

- (id)initWithBaseURL:(NSURL *)url {
    self = [super initWithBaseURL:url];
    if (self) {
        [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:YES];;
    }
    return self;
}

- (void)getPath:(NSString *)path
     parameters:(NSDictionary *)parameters
        success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
        failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure
       progress:(void (^)(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead))progress {
	NSURLRequest *request = [self requestWithMethod:@"GET" path:path parameters:parameters];
    AFHTTPRequestOperation *operation = [self HTTPRequestOperationWithRequest:request success:success failure:failure];
    [operation setDownloadProgressBlock:progress];
    [self enqueueHTTPRequestOperation:operation];
}

@end
