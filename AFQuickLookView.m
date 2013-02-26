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

// Control the positioning of attachmentDetailView subviews here
static CGFloat kPaddingTopBetweenFileImageViewAndSuperview = 10.0f;
static CGFloat kPaddingTopBetweenFilenameLabelAndImageView = 10.0f;
static CGFloat kPaddingTopBetweenProgressViewAndFilenameLabel = 10.0f;
static CGFloat kPaddingLeftAndRightFilenameLabel = 60.0f;
static CGFloat kPaddingLeftAndRightProgressView = 80.0f;

static CGSize kPreDownloadFileImageViewSize = {100.0f, 120.0f};
static CGFloat kPreDownloadFilenameLabelHeight = 30.0f;
static CGFloat kPreDownloadProgressViewHeight = 11.0f;

static NSMutableDictionary* _mimeTypesToExtensionsDictionary = nil;

typedef void (^AFQuickLookPreviewSuccessBlock)(void);
typedef void (^AFQuickLookPreviewFailureBlock)(NSError* error);
typedef void (^AFQuickLookPreviewProgressBlock)(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead);

@interface AFQuickLookView () <QLPreviewControllerDelegate, QLPreviewControllerDataSource>
@property(nonatomic, strong, readwrite) QLPreviewController *previewController;
@property(nonatomic, strong, readwrite) NSURL* fileURL;
@property(nonatomic, strong, readwrite) AFQuickLookPreviewSuccessBlock successBlock;
@property(nonatomic, strong, readwrite) AFQuickLookPreviewFailureBlock failureBlock;
@property(nonatomic, strong, readwrite) AFQuickLookPreviewProgressBlock progressBlock;
@property(nonatomic, strong, readwrite) UIView* preDownloadDetailView;
@property(nonatomic, strong, readwrite) UIProgressView* preDownloadProgressView;
@property(nonatomic, strong, readwrite) UILabel* preDownloadFilenameLabel;
@property(nonatomic, strong, readwrite) UIImageView* preDownloadFileImageView;
@end

@implementation AFQuickLookView

- (id)initWithFrame:(CGRect)frame preDownloadDetailViewVisible:(BOOL)preDownloadDetailViewVisible preDownloadPlaceholderImage:(UIImage*)image filename:(NSString*)filename {
    self = [super initWithFrame:frame];
    if (self) {
        _preDownloadDetailViewVisible = preDownloadDetailViewVisible;
        [self setupWithPreDownloadDetailViewVisible:preDownloadDetailViewVisible preDownloadPlaceholderImage:image filename:filename];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame preDownloadDetailViewVisible:(BOOL)preDownloadDetailViewVisible {
    self = [self initWithFrame:frame preDownloadDetailViewVisible:preDownloadDetailViewVisible preDownloadPlaceholderImage:nil filename:nil];
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    self = [self initWithFrame:frame preDownloadDetailViewVisible:YES preDownloadPlaceholderImage:nil filename:nil];
    return self;
}

#pragma mark - general view setup

- (void)setupWithPreDownloadDetailViewVisible:(BOOL)preDownloadDetailViewVisible preDownloadPlaceholderImage:(UIImage*)image filename:(NSString*)filename {
    if (preDownloadDetailViewVisible) {
        self.previewController = [[QLPreviewController alloc] init];
        [self setupPreviewController:self.previewController];
        
        self.preDownloadDetailView = [[UIView alloc] initWithFrame:self.bounds];
        [self addSubview:self.preDownloadDetailView];
        
        [self setupPreDownloadDetailView:self.preDownloadDetailView];
        
        [self setupPreDownloadPlaceholderImage:image filename:filename];
    }
}

- (void)setupPreDownloadPlaceholderImage:(UIImage*)image
                                filename:(NSString*)filename {
    self.preDownloadFilenameLabel.text = filename;
    self.preDownloadFileImageView.image = image;
}

- (void)setupPreviewController:(QLPreviewController*)controller {
    controller.dataSource = self;
    controller.view.frame = self.bounds;
}

#pragma mark - attachment detail view setup

- (void)initializePreDownloadDetailViewSubviews {
    self.preDownloadProgressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
    self.preDownloadFileImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.preDownloadFilenameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
}

- (void)addSubviewsToPreDownloadDetailView:(UIView*)attachmentDetailView {
    [attachmentDetailView addSubview:self.preDownloadFileImageView];
    [attachmentDetailView addSubview:self.preDownloadFilenameLabel];
    [attachmentDetailView addSubview:self.preDownloadProgressView];
}

- (void)setupPreDownloadDetailView:(UIView*)preDownloadDetailView {
    if (NO == self.preDownloadDetailViewVisible) {
        return;
    }
    
    [self initializePreDownloadDetailViewSubviews];
    [self setupSubviewsForPreDownloadDetailView:self.preDownloadDetailView];
    [self addSubviewsToPreDownloadDetailView:self.preDownloadDetailView];
}

- (void)layoutSubviews {
    [self layoutSubviewsForPreDownloadDetailView:self.preDownloadDetailView];
}

- (void)layoutSubviewsForPreDownloadDetailView:(UIView*)preDownloadDetailView {
    [self verticalAlignFileImageView:self.preDownloadFileImageView withProgressView:self.preDownloadProgressView detailView:preDownloadDetailView];
    [self verticalAlignFilenameLabel:self.preDownloadFilenameLabel withFileImageView:self.preDownloadFileImageView detailView:preDownloadDetailView];
    [self verticalAlignProgressView:self.preDownloadProgressView withFilenameLabel:self.preDownloadFilenameLabel detailView:preDownloadDetailView];
}

- (void)setupSubviewsForPreDownloadDetailView:(UIView*)preDownloadDetailView {
    [self setupFileImageView:self.preDownloadFileImageView withProgressView:self.preDownloadProgressView detailView:preDownloadDetailView];
    [self setupFilenameLabel:self.preDownloadFilenameLabel withFileImageView:self.preDownloadFileImageView detailView:preDownloadDetailView];
    [self setupProgressView:self.preDownloadProgressView withFilenameLabel:self.preDownloadFilenameLabel detailView:preDownloadDetailView];
}

#pragma mark - progress detail view setup method

- (void)setupFileImageView:(UIImageView*)fileImageView withProgressView:(UIProgressView*)progressView detailView:(UIView*)detailView {
    fileImageView.frame = CGRectMake(0.0f, 0.0f, kPreDownloadFileImageViewSize.width, kPreDownloadFileImageViewSize.height);
    fileImageView.center = detailView.center;
    [self verticalAlignFileImageView:fileImageView withProgressView:progressView detailView:detailView];
}

- (void)setupFilenameLabel:(UILabel*)filenameLabel withFileImageView:(UIImageView*)fileImageView detailView:(UIView*)detailView {
    filenameLabel.textAlignment = UITextAlignmentCenter;
    filenameLabel.frame = CGRectMake(0.0f, 0.0f, CGRectGetWidth(detailView.frame) - 2*kPaddingLeftAndRightFilenameLabel, kPreDownloadFilenameLabelHeight);
    filenameLabel.center = detailView.center;
    [self verticalAlignFilenameLabel:filenameLabel withFileImageView:fileImageView detailView:detailView];
}

- (void)setupProgressView:(UIProgressView*)progressView withFilenameLabel:(UILabel*)filenameLabel detailView:(UIView*)detailView {
    progressView.frame = CGRectMake(0.0f, 0.0f, CGRectGetWidth(detailView.frame) - 2*kPaddingLeftAndRightProgressView, kPreDownloadProgressViewHeight);
    progressView.center = detailView.center;
    [self verticalAlignProgressView:progressView withFilenameLabel:filenameLabel detailView:detailView];
}

#pragma mark - progress detail view align method

- (void)verticalAlignFileImageView:(UIImageView*)fileImageView withProgressView:(UIProgressView*)progressView detailView:(UIView*)detailView {
    CGFloat heightOfAllSubviews = CGRectGetHeight(fileImageView.frame) + CGRectGetHeight(progressView.frame) + CGRectGetHeight(self.preDownloadFilenameLabel.frame) + kPaddingTopBetweenFilenameLabelAndImageView + kPaddingTopBetweenProgressViewAndFilenameLabel;
    fileImageView.frame = CGRectMake(CGRectGetMinX(fileImageView.frame), (CGRectGetHeight(detailView.bounds) - heightOfAllSubviews) / 2,CGRectGetWidth(fileImageView.frame), CGRectGetHeight(fileImageView.frame));
}

- (void)verticalAlignFilenameLabel:(UILabel*)filenameLabel withFileImageView:(UIView*)fileImageView detailView:(UIView*)detailView {
    filenameLabel.frame = CGRectMake(CGRectGetMinX(filenameLabel.frame), CGRectGetMinY(fileImageView.frame) + CGRectGetHeight(fileImageView.frame) + kPaddingTopBetweenProgressViewAndFilenameLabel, CGRectGetWidth(filenameLabel.frame), CGRectGetHeight(filenameLabel.frame));
}

- (void)verticalAlignProgressView:(UIProgressView*)progressView withFilenameLabel:(UILabel*)filenameLabel detailView:(UIView*)detailView {
    progressView.frame = CGRectMake(CGRectGetMinX(progressView.frame), CGRectGetMinY(filenameLabel.frame) + CGRectGetHeight(filenameLabel.frame) + kPaddingTopBetweenProgressViewAndFilenameLabel, CGRectGetWidth(progressView.frame), CGRectGetHeight(progressView.frame));
}

#pragma mark - actions

- (void)refreshProgressViewWithTotalBytesRead:(long long)totalBytesRead
                     totalBytesExpectedToRead:(long long)totalBytesExpectedToRead {
    CGFloat progress = ((CGFloat)totalBytesRead / (CGFloat)totalBytesExpectedToRead);
    self.preDownloadProgressView.progress = progress;
}

- (void)downloadDocumentAtURL:(NSURL*)url
                      success:(void (^)(AFHTTPRequestOperation* operation, NSURL *localFileURL))success
                      failure:(void (^)(AFHTTPRequestOperation* operation, NSError* error))failure {
    [self downloadDocumentAtURL:url success:success failure:failure progress:NULL];
}

- (void)downloadDocumentAtURL:(NSURL*)url
                      success:(void (^)(AFHTTPRequestOperation* operation, NSURL *localFileURL))success
                      failure:(void (^)(AFHTTPRequestOperation* operation, NSError* error))failure
                     progress:(void (^)(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead))progress {
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
     } failure:failure progress:progress];
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
    __weak __typeof(&*self)weakSelf = self;
    [self previewDocumentAtURL:url inPreviewController:self.previewController success:NULL failure:NULL progress:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
        [weakSelf refreshProgressViewWithTotalBytesRead:totalBytesRead totalBytesExpectedToRead:totalBytesExpectedToRead];
    }];
}

- (void)previewDocumentAtURL:(NSURL*)url
                     success:(void (^)(void))success
                     failure:(void (^)(NSError* error))failure {
    __weak __typeof(&*self)weakSelf = self;
    [self previewDocumentAtURL:url inPreviewController:self.previewController success:success failure:failure progress:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
        [weakSelf refreshProgressViewWithTotalBytesRead:totalBytesRead totalBytesExpectedToRead:totalBytesExpectedToRead];
    }];
}

- (void)previewDocumentAtURL:(NSURL*)url
                     success:(void (^)(void))success
                     failure:(void (^)(NSError* error))failure
                    progress:(void (^)(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead))progress {
    [self previewDocumentAtURL:url inPreviewController:self.previewController success:success failure:failure progress:progress];
}

- (void)previewDocumentAtURL:(NSURL*)url
         inPreviewController:(QLPreviewController*)previewController
                     success:(void (^)(void))success
                     failure:(void (^)(NSError* error))failure
                    progress:(void (^)(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead))progress {
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
         } progress:progress];
    }
}

- (void)openDocumentPreviewAtLocalURL:(NSURL*)url
                  inPreviewController:(QLPreviewController *)previewController {
    [_preDownloadDetailView removeFromSuperview];
    
    self.fileURL = url;
    [self addSubview:_previewController.view];
    [previewController reloadData];
    
    if (self.successBlock) {
        self.successBlock();
    }
}

#pragma mark - cancel request

- (void)cancelDownloadOperation {
    [[AFQuickLookViewHTTPClient sharedClient] cancelAllDownloadOperations];
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

#pragma mark - handle file extensions for MIME types

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
