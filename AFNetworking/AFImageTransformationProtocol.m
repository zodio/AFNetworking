// AFImageTransformationProtocol.m
// 
// Copyright (c) 2012年 __MyCompanyName__
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "AFImageTransformationProtocol.h"

#import "AFImageRequestOperation.h"
#import "AFHTTPClient.h"
#import "UIImageView+AFNetworking.h"

NSString * const AFImageTransformationScale = @"X-AF-Image-Scale";
NSString * const AFImageTransformationCrop = @"X-AF-Image-Crop";
NSString * const AFImageTransformationGrayscale = @"X-AF-Image-Grayscale";

static NSDictionary * AFParametersFromURLRequest(NSURLRequest *request) {
    NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionary];
    for (NSString *pair in [[[request URL] query] componentsSeparatedByString:@"&"]) {
        NSArray *components = [pair componentsSeparatedByString:@"="];
        if ([components count] != 2) {
            continue;
        }
        
        NSString *key = [components objectAtIndex:0];
        NSString *value = [components objectAtIndex:1];
        
        [mutableParameters setValue:value forKey:key];
    }
    
    return mutableParameters;
}

#pragma mark -

@interface AFProtocolProxiedImageRequestOperation : AFImageRequestOperation
- (id)initWithRequest:(NSURLRequest *)urlRequest
             protocol:(NSURLProtocol *)urlProtocol;
@end

#pragma mark -

@interface AFImageTransformationProtocol () <NSStreamDelegate>
@property (readwrite, nonatomic, strong) AFProtocolProxiedImageRequestOperation *imageRequestOperation;
@property (readwrite, nonatomic, strong) UIImage *processedImage;
@end

@implementation AFImageTransformationProtocol
@synthesize imageRequestOperation = _imageRequestOperation;

+ (NSArray *)recognizedTransformations {
    static NSArray *_recognizedTransformations = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _recognizedTransformations = [NSArray arrayWithObjects:AFImageTransformationScale, AFImageTransformationCrop, AFImageTransformationGrayscale, nil];
    });
    
    return _recognizedTransformations;
}

//+ (AFHTTPClient *)sharedClient {
//    static AFHTTPClient *_sharedClient = nil;
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        _sharedClient = [[AFHTTPClient alloc] init];
//    });
//}

+ (NSOperationQueue *)sharedOperationQueue {
    static NSOperationQueue *_sharedOperationQueue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedOperationQueue = [[NSOperationQueue alloc] init];
        [_sharedOperationQueue setMaxConcurrentOperationCount:1];
    });
    
    return _sharedOperationQueue;
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    BOOL canProcess = [AFImageRequestOperation canProcessRequest:request];
    BOOL hasTransformation = NO;
    for (NSString *header in [self recognizedTransformations]) {
        if ([request valueForHTTPHeaderField:header]) {
            hasTransformation = YES;
            break;
        }
    }
    
    return canProcess && hasTransformation;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    NSMutableURLRequest *mutableRequest = [request mutableCopy];
    for (NSString *header in [self recognizedTransformations]) {
        [mutableRequest setValue:nil forHTTPHeaderField:header];
    }
    
    return mutableRequest;
}

- (void)startLoading {
    self.imageRequestOperation = [[AFProtocolProxiedImageRequestOperation alloc] initWithRequest:[[self class] canonicalRequestForRequest:self.request] protocol:self];
//    [[[self class] sharedOperationQueue] addOperation:self.imageRequestOperation];

    [self.imageRequestOperation start];
}

- (void)stopLoading {
    if ([self.imageRequestOperation isFinished]) {
        NSLog(@"Finished");
    } else {
        NSLog(@"Wat");
        [self.imageRequestOperation cancel];
    }
}

+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)requestA
                       toRequest:(NSURLRequest *)requestB
{
    return NO;
}

@end

#pragma mark -

@interface AFProtocolProxiedImageRequestOperation ()
@property (readwrite, nonatomic, strong) NSURLProtocol *URLProtocol;
@property (readwrite, nonatomic, strong) UIImage *responseImage;
@property (readwrite, nonatomic, strong) NSData *responseData;

@end

@implementation AFProtocolProxiedImageRequestOperation
@synthesize URLProtocol = _URLProtocol;

- (id)initWithRequest:(NSURLRequest *)urlRequest protocol:(NSURLProtocol *)urlProtocol {
    self = [super initWithRequest:urlRequest];
    if (!self) {
        return nil;
    }
    
    self.URLProtocol = urlProtocol;
    
    return self;
}

#pragma mark - NSURLConnectionDelegate

//- (BOOL)connection:(NSURLConnection *)connection
//canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace
//{
//    return [super connection:connection canAuthenticateAgainstProtectionSpace:protectionSpace];
//}

- (void)connection:(NSURLConnection *)connection
didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    [self.URLProtocol.client URLProtocol:self.URLProtocol didReceiveAuthenticationChallenge:challenge];
    [super connection:connection didReceiveAuthenticationChallenge:challenge];
}

//- (NSURLRequest *)connection:(NSURLConnection *)connection
//             willSendRequest:(NSURLRequest *)request
//            redirectResponse:(NSURLResponse *)redirectResponse
//{
//    NSURLRequest *redirectRequest = [super connection:connection willSendRequest:request redirectResponse:redirectResponse];
//    if (redirectResponse) {
//        redirectRequest = nil;
//    }
//    
//    [self.URLProtocol.client URLProtocol:self.URLProtocol wasRedirectedToRequest:redirectRequest redirectResponse:redirectResponse];
//    
//    return redirectRequest;
//}

//- (void)connection:(NSURLConnection *)connection
//   didSendBodyData:(NSInteger)bytesWritten
// totalBytesWritten:(NSInteger)totalBytesWritten
//totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
//{
//    [super connection:connection didSendBodyData:bytesWritten totalBytesWritten:totalBytesWritten totalBytesExpectedToWrite:totalBytesExpectedToWrite];
//}

- (void)connection:(NSURLConnection *)connection
didReceiveResponse:(NSURLResponse *)response
{
    [super connection:connection didReceiveResponse:response];
    [self.URLProtocol.client URLProtocol:self.URLProtocol didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowed];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [super connectionDidFinishLoading:connection];
    self.responseImage = [UIImage imageNamed:@"Icon.png"];
    self.responseData = UIImagePNGRepresentation(self.responseImage);
    [self.URLProtocol.client URLProtocol:self.URLProtocol didLoadData:self.responseData];
    [self.URLProtocol.client URLProtocolDidFinishLoading:self.URLProtocol];
}

- (void)connection:(NSURLConnection *)connection
  didFailWithError:(NSError *)error
{
    [super connection:connection didFailWithError:error];
    [self.URLProtocol.client URLProtocol:self.URLProtocol didFailWithError:error];
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection
                  willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
    return [super connection:connection willCacheResponse:cachedResponse];
}

@end

#pragma mark -

@implementation UIImageView (AFImageTransformation)

- (void)setImageWithURL:(NSURL *)url
       placeholderImage:(UIImage *)placeholderImage
           scaledToSize:(CGSize)size
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPShouldHandleCookies:NO];
    [request addValue:@"image/*" forHTTPHeaderField:@"Accept"];
    [request addValue:@"true" forHTTPHeaderField:AFImageTransformationScale];
    
    [self setImageWithURLRequest:request placeholderImage:placeholderImage success:nil failure:nil];
}

@end
