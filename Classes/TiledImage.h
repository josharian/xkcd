//
//  TiledImage.h
//
//  Created by Josh Snyder
//

#import <Foundation/Foundation.h>

@interface TiledImage : NSObject

- (id)initWithImage:(UIImage *)imageToTile tileWidth:(NSUInteger)width tileHeight:(NSUInteger)height;
- (UIImage *)imageAtXIndex:(NSUInteger)xIndex YIndex:(NSUInteger)yIndex;

@property(nonatomic, assign, readonly) NSUInteger widthCount;
@property(nonatomic, assign, readonly) NSUInteger heightCount;
@property(nonatomic, assign, readonly) NSUInteger tileWidth;
@property(nonatomic, assign, readonly) NSUInteger tileHeight;
@property(nonatomic, strong, readonly) NSArray *allTiles; // a little expensive, use sparingly

@end
