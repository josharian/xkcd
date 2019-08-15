//
//  FetchComicImageFromWeb.m
//  xkcd
//
//  Created by Joshua Bleecher Snyder on 9/2/09.
//  Copyright 2009 Treeline Labs. All rights reserved.
//

#import "FetchComicImageFromWeb.h"
#import "TLMacros.h"
#import "xkcd-Swift.h"

#pragma mark -

@interface FetchComicImageFromWeb ()

@property (nonatomic) NSInteger comicNumber;
@property (nonatomic) NSString *comicImageURL;
@property (nonatomic) NSData *comicImageData;
@property (nonatomic, weak) id target;
@property (nonatomic) SEL action;
@property (nonatomic) NSError *error;
@property (nonatomic) id context;
@property (nonatomic) NSURLSession *URLSession;
@property (nonatomic) bool tryLarge;
@property (nonatomic) bool try2x;

@end

#pragma mark -


@implementation FetchComicImageFromWeb

- (instancetype)initWithComicNumber:(NSInteger)number
                           imageURL:(NSString *)imageURL
                         URLSession:(NSURLSession *)session
                   completionTarget:(id)completionTarget
                             action:(SEL)completionAction
                            context:(id)aContext {
    if(self = [super init]) {
        _comicNumber = number;
        _comicImageURL = imageURL;
        _target = completionTarget;
        _action = completionAction;
        _context = aContext;
        _URLSession = session;
    }
    return self;
}

- (NSString *)addSuffixToURL:(NSString *)url
                      suffix:(NSString *)suffix {
    NSString *extension = [url pathExtension];
    if ([extension length] == 0) {
        return [url stringByAppendingString:suffix];
    }
    NSString *withoutExtension = [url substringToIndex:([url length] - [extension length] - 1)];
    NSString *withSuffix = [withoutExtension stringByAppendingString:suffix];
    return [[withSuffix stringByAppendingString:@"."] stringByAppendingString:extension];
}

- (void)main {
    // self.comicImageURL is the image url given by the xkcd API.
    // It is usually the lowest resolution image available. This
    // code uses some hard-coded special cases as well as trial
    // and error to find the best image available. It's best to
    // do this here and not in the NewComicFetcher because it
    // reduces the number of image requests sent to xkcd servers
    // during inital app load, and also older users who have
    // already loaded all comics can get the high-res version
    // simply by redownloading a single comic instead of having
    // to redownload the whole app to refresh the comic list.
    
    self.tryLarge = false;
    // 1084 is the first comic to have a 2x version
    // Some comics have large, some have 2x,
    // some have both, some have neither.
    self.try2x = (self.comicNumber >= 1084);
    
    // Special cases
    if (self.comicNumber == 256) {
        [self doFetch:@"https://imgs.xkcd.com/comics/online_communities.png"];
        return;
    } else if (self.comicNumber == 273) {
        [self doFetch:@"https://imgs.xkcd.com/comics/electromagnetic_spectrum.png"];
        return;
    }
//    else if (self.comicNumber == 980) {
//        // TODO: This image is only ~7MB, but attempting to
//        // display it results in gigabytes of memory usage.
//        // Not sure if a bug in Apple's image view or in
//        // this app.
//        [self doFetch:@"https://imgs.xkcd.com/comics/money_huge.png"];
//        return;
    else if (self.comicNumber <= 2189) { // Newest comic at time of writing
        // Hardcode known "large" comics up until a specific point.
        // This is not necessary, but avoids extra image lookups
        // and spam to xkcd servers.
        switch (self.comicNumber) {
            case 657:  case 681:  case 802:  case 832:
            case 850:  case 930:  case 1000: case 1040:
            case 1071: case 1079: case 1080: case 1127:
            case 1196: case 1212: case 1256: case 1298:
            case 1389: case 1392: case 1407: case 1461:
            case 1491: case 1509: case 1688: case 1939:
            case 1970:
                self.tryLarge = true;
                break;
        }
    } else {
        // Check for large on all newer comics.
        self.tryLarge = true;
    }
    
    [self doFetch:@""];
}

- (void)doFetch:(NSString *)specialURL {
    bool special = ![specialURL isEqualToString:@""];
    NSString *url;
    
    if (special) {
        url = specialURL;
    } else if (self.tryLarge) {
        url = [self addSuffixToURL:self.comicImageURL suffix:@"_large"];
    } else if (self.try2x) {
        url = [self addSuffixToURL:self.comicImageURL suffix:@"_2x"];
    } else {
        url = self.comicImageURL;
    }
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:url]
                                                                cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                            timeoutInterval:180.0f];
    [request setValue:[Constants userAgent] forHTTPHeaderField:@"User-Agent"];
    
    TLDebugLog(@"Fetching image at %@", url);
    
    [[self.URLSession dataTaskWithRequest:request
                        completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                            self.comicImageData = data;
                            self.error = error;
                            
                            if (self.error) {
                                TLDebugLog(@"Image fetch completed with error: %@", self.error);
                            } else if (response
                                       && [response isKindOfClass:[NSHTTPURLResponse class]]
                                       && [((NSHTTPURLResponse *)response) statusCode] == 404) {
                                TLDebugLog(@"Image fetch completed with 404");
                                
                                if (special) {
                                    [self doFetch:@""];
                                    return;
                                } else if (self.tryLarge) {
                                    self.tryLarge = false;
                                    [self doFetch:@""];
                                    return;
                                } else if (self.try2x) {
                                    self.try2x = false;
                                    [self doFetch:@""];
                                    return;
                                } else {
                                    // Failed to find default image. Right now
                                    // this just results in an empty screen.
                                }
                            }
                            
                            if(![self isCancelled]) {
                                [self.target performSelectorOnMainThread:self.action
                                                              withObject:self
                                                           waitUntilDone:NO];
                            }
                        }
      ] resume];
}

@end
