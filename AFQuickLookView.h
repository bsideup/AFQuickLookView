// AFQuickLookView.h
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

#import <UIKit/UIKit.h>
#import <QuickLook/QuickLook.h>

@interface AFQuickLookView : UIView

/**
 <#add description#>
 */
@property(nonatomic, strong, readonly) UIView* preDownloadDetailView;

/**
 <#add description#>
 */
@property(nonatomic, strong, readonly) UIProgressView* preDownloadProgressView;

/**
 <#add description#>
 */
@property(nonatomic, strong, readonly) UILabel* preDownloadFilenameLabel;

/**
 <#add description#>
 */
@property(nonatomic, strong, readonly) UIImageView* preDownloadFileImageView;

/**
 <#add description#>
 */
@property(nonatomic, assign, readwrite) BOOL preDownloadDetailViewVisible;


/**
 <#add description#>
 */
- (id)initWithFrame:(CGRect)frame preDownloadDetailViewVisible:(BOOL)showPreDownloadDetailView;

/**
 <#add description#>
 */

- (id)initWithFrame:(CGRect)frame preDownloadDetailViewVisible:(BOOL)showPreDownloadDetailView preDownloadPlaceholderImage:(UIImage*)image filename:(NSString*)filename;

/**
<#add description#>
*/
- (void)cancelDownloadOperation;

/**
 <#add description#>
 */
- (void)previewDocumentAtURL:(NSURL*)url;

/**
 <#add description#>
 */
- (void)previewDocumentAtURL:(NSURL*)url
                     success:(void (^)(void))success
                     failure:(void (^)(NSError* error))failure;

/**
 <#add description#>
 */
- (void)previewDocumentAtURL:(NSURL*)url
                     success:(void (^)(void))success
                     failure:(void (^)(NSError* error))failure
                    progress:(void (^)(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead))progress;
@end
