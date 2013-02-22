// AFQuickLookView.m
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
#import "AFQuickLookView.h"
#import <AFNetworking/AFNetworking.h>

static NSMutableDictionary* _mimeTypesToExtensionsDictionary = nil;

typedef void (^AFQuickLookPreviewSuccessBlock)(void);
typedef void (^AFQuickLookPreviewFailureBlock)(NSError* error);

@interface AFQuickLookView () <QLPreviewControllerDelegate, QLPreviewControllerDataSource>
@property(nonatomic, strong, readwrite) QLPreviewController *previewController;
@property(nonatomic, strong, readwrite) NSURL* fileURL;
@property(nonatomic, strong, readwrite) AFQuickLookPreviewSuccessBlock successBlock;
@property(nonatomic, strong, readwrite) AFQuickLookPreviewFailureBlock failureBlock;

@end

@implementation AFQuickLookView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // initialize the QuickLookPreviewController
        _previewController = [[QLPreviewController alloc] init];
        _previewController.dataSource = self;
        _previewController.view.frame = CGRectMake(0, 0, frame.size.width, frame.size.height);
    }
    return self;
}

- (void)downloadDocumentAtURL:(NSURL*)url
                      success:(void (^)(AFHTTPRequestOperation* operation, NSURL *localFileURL))success
                      failure:(void (^)(AFHTTPRequestOperation* operation, NSError* error))failure {
    __weak __typeof(&*self)weakSelf = self;
    [[AFQuickLookViewHTTPClient sharedClient] getPath:url.absoluteString
                                           parameters:nil
                                              success:
     ^(AFHTTPRequestOperation *operation, id responseObject) {
         [weakSelf saveDataToTemporaryFileWithOperation:operation
                                                success:success
                                                failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                    [weakSelf handleCouldNotSaveDataToTemporaryFileWithOperation:operation error:error];
                                                }];
     } failure:failure progress:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
     }];
}

- (void)saveDataToTemporaryFileWithOperation:(AFHTTPRequestOperation*)operation
                                     success:(void (^)(AFHTTPRequestOperation* operation, NSURL *localFileURL))success
                                     failure:(void (^)(AFHTTPRequestOperation* operation, NSError* error))failure {
    NSData* data = operation.responseData;
    BOOL isResponseDataValid = (data && data.length > 0);
    if (NO == isResponseDataValid) {
        failure(operation, nil);
    }
    
    NSError* error = nil;
    NSURL* url = [self temporaryFileURLWithResponse:operation.response];
    BOOL didWriteToFile = [data writeToURL:url options:NSDataWritingAtomic error:&error];
    if (didWriteToFile) {
        success(operation, url);
    } else {
        failure(operation, error);
    }
}

#pragma mark - handle errors

- (void)handleCouldNotSaveDataToTemporaryFileWithOperation:(AFHTTPRequestOperation*)operation
                                                     error:(NSError*)error {
    [self handleFailureBlockWithError:error];
}

- (void)handleCouldNotDownloadDataForGivenURL:(NSURL*)url
                                    operation:(AFHTTPRequestOperation*)operation
                                        error:(NSError*)error {
    [self handleFailureBlockWithError:error];
}

- (void)handleFailureBlockWithError:(NSError*)error {
    if (self.failureBlock) {
        self.failureBlock(error);
    }
}

#pragma mark - preview methods

- (void)previewDocumentAtURL:(NSURL*)url {
    [self previewDocumentAtURL:url inPreviewController:self.previewController success:NULL failure:NULL];
}

- (void)previewDocumentAtURL:(NSURL*)url
                     success:(void (^)(void))success
                     failure:(void (^)(NSError* error))failure {
    [self previewDocumentAtURL:url inPreviewController:self.previewController success:success failure:failure];
}

- (void)previewDocumentAtURL:(NSURL*)url
         inPreviewController:(QLPreviewController*)previewController
                     success:(void (^)(void))success
                     failure:(void (^)(NSError* error))failure {
    self.successBlock = success;
    self.failureBlock = failure;
    __weak __typeof(&*self)weakSelf = self;
    if(url.isFileURL) {
        [self openDocumentPreviewAtLocalURL:url inPreviewController:previewController];
    } else {
        [self downloadDocumentAtURL:url
                            success:
         ^(AFHTTPRequestOperation *operation, NSURL *localFileURL) {
             [weakSelf openDocumentPreviewAtLocalURL:localFileURL inPreviewController:previewController];
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            [weakSelf handleCouldNotDownloadDataForGivenURL:url operation:operation error:error];
        }];
    }
}

- (void)openDocumentPreviewAtLocalURL:(NSURL*)url
                  inPreviewController:(QLPreviewController *)previewController {
    self.fileURL = url;
    [self addSubview:_previewController.view];
    [previewController reloadData];
    
    if (self.successBlock) {
        self.successBlock();
    }
}

#pragma mark - QLPreviewControllerDataSource delegate

- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)previewController {
    NSInteger numToPreview = 0;
    return numToPreview;
}

- (id)previewController:(QLPreviewController *)previewController previewItemAtIndex:(NSInteger)idx {
    NSURL* fileURL = self.fileURL;
    return fileURL;
}

#pragma mark - build temporary file path

- (NSURL*)temporaryFileURLWithResponse:(NSHTTPURLResponse*)response {
    NSString* path = [self temporaryFilePathForResponse:response];
    return [NSURL fileURLWithPath:path isDirectory:NO];
}

- (NSString*)temporaryFilePathForResponse:(NSHTTPURLResponse*)response {
    NSString* filename = [self filenameFromResponse:response];
    NSString* directory = [self directoryForTemporaryFiles];
    NSString* filePath = [directory stringByAppendingPathComponent:filename];
    return filePath;
}

- (NSString*)filenameFromResponse:(NSHTTPURLResponse*)response {
    NSString* filename = nil;
    NSString* filenameFromContentType = [self filenameFromContentTypeHeaderInResponse:response];
    NSString* filenameFromContentDisposition = [self filenameFromContentDispositionHeaderInResponse:response];
    if (filenameFromContentType) {
        filename = filenameFromContentType;
    } else if(filenameFromContentDisposition) {
        filename = filenameFromContentDisposition;
    } else {
        filename = [self genericTemporaryFileName];
    }
    return filename;
}

- (NSString*)filenameFromContentDispositionHeaderInResponse:(NSHTTPURLResponse*)response {
    NSString *filename = nil;
    NSString* contentDisposition = response.allHeaderFields[@"Content-Disposition"];
    if (contentDisposition) {
        filename = [[self getFilenameFrom:contentDisposition] stringByTrimmingCharactersInSet:self.characterSetToTrimFromFilename];
    }
    return filename;
}

- (NSString*)filenameFromContentTypeHeaderInResponse:(NSHTTPURLResponse*)response {
    NSString* filename = nil;
    if (response.MIMEType) {
        NSString* extension = [self fileExtensionForMIMEType:response.MIMEType];
        filename = self.genericTemporaryFileName;
        filename = [filename stringByAppendingFormat:@".%@", extension];
    }
    return filename;
}

- (NSString*)directoryForTemporaryFiles {
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    return documentsDirectory;
}

- (NSString*)genericTemporaryFileName {
    return @"com.afquicklook.temp";
}

- (NSCharacterSet*)characterSetToTrimFromFilename {
    return [NSCharacterSet characterSetWithCharactersInString:@"\""];
}

/*
 - this method has been taken from:
 - http://stackoverflow.com/questions/10278791/get-filename-from-content-disposition-header
 */
- (NSString *)getFilenameFrom:(NSString *)string {
    NSRange startRange = [string rangeOfString:@"filename="];
    
    if (startRange.location != NSNotFound && startRange.length != NSNotFound) {
        int filenameStart = startRange.location + startRange.length;
        NSRange endRange = [string rangeOfString:@" " options:NSLiteralSearch range:NSMakeRange(filenameStart, [string length] - filenameStart)];
        int filenameLength = 0;
        
        if (endRange.location != NSNotFound && endRange.length != NSNotFound) {
            filenameLength = endRange.location - filenameStart;
        } else {
            filenameLength = [string length] - filenameStart;
        }
        
        return [string substringWithRange:NSMakeRange(filenameStart, filenameLength)];
    }
    return nil;
}


- (NSString*)fileExtensionForMIMEType:(NSString*)mimeType {
    if (NO == [mimeType isKindOfClass:[NSString class]]) {
        return nil;
    }
    
    NSMutableDictionary* extensions = [AFQuickLookView mimeTypesToExtensionsDictionary];
    NSString* extension = extensions[mimeType];
    
    return extension;
}

+ (NSMutableDictionary*) mimeTypesToExtensionsDictionary {
    if (nil == _mimeTypesToExtensionsDictionary) {
        _mimeTypesToExtensionsDictionary = [NSMutableDictionary dictionary];
        _mimeTypesToExtensionsDictionary[@"application/pdf"] = @"pdf";
        _mimeTypesToExtensionsDictionary[@"application/msword"] = @"doc";
        _mimeTypesToExtensionsDictionary[@"image/jpeg"] = @"jpeg";
        _mimeTypesToExtensionsDictionary[@"application/pdf"] = @"pdf";
        _mimeTypesToExtensionsDictionary[@"application/vnd.ms-powerpoint"] = @"ppt";
        _mimeTypesToExtensionsDictionary[@"application/rtf"] = @"rtf";
        _mimeTypesToExtensionsDictionary[@"image/tiff"] = @"tiff";
        _mimeTypesToExtensionsDictionary[@"text/plain"] = @"txt";
        _mimeTypesToExtensionsDictionary[@"application/vnd.ms-excel"] = @"xls";
    }
    return _mimeTypesToExtensionsDictionary;
}

@end
