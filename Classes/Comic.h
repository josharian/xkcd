//
//  Comic.h
//  xkcd
//
//  Created by Joshua Bleecher Snyder on 9/1/09.
//  Copyright 2009 Treeline Labs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "UIImage+EXIFCompensation.h"

#define kMinComicNumber 1

@interface Comic : NSManagedObject

+ (Comic *)comic; // use this, not init/etc.

+ (void)deleteAllComics; // for total recreation from scratch
+ (NSArray *)allComics; // use sparingly!!
+ (NSArray *)comicsWithoutImages;

+ (Comic *)lastKnownComic; // highest numbered comic that has been fetched

+ (Comic *)comicNumbered:(NSInteger)comicNumber;

- (void)saveImageData:(NSData *)imageData;
- (BOOL)downloaded;
+ (NSEntityDescription *)entityDescription;
- (void)deleteImage;
- (NSString *)websiteURL;
+ (void)synchronizeDownloadedImages;
+ (NSSet *)downloadedImages;
+ (void)deleteDownloadedImage:(NSString *)downloadedImage; // strings drawn from +downloadedImages
+ (NSString *)imagePathForImageFilename:(NSString *)imageFilename;

@property(nonatomic, strong, readonly) UIImage *image;
@property (nonatomic, retain) NSNumber * number;
@property (nonatomic, retain) NSString * transcript;
@property (nonatomic, retain) NSString * titleText;
@property (nonatomic, retain) NSNumber * loading;
@property (nonatomic, retain) NSString * explanation;
@property (nonatomic, retain) NSString * imageURL;
@property (nonatomic, retain) NSString * name;

@end
