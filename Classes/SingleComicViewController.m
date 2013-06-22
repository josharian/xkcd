//
//  SingleComicViewController.m
//  xkcd
//

#import "SingleComicViewController.h"
#import "Comic.h"
#import "TiledImage.h"
#import "CGGeometry_TLCommon.h"
#import "xkcdAppDelegate.h"
#import "SingleComicImageFetcher.h"
#import "ComicListViewController.h"
#import "TLLoadingView.h"
#import "UIBarButtonItem_TLCommon.h"
#import "TLMersenneTwister.h"
#import "LambdaSheet.h"
#import "OpenInSafariActivity.h"
#import "OpenInChromeActivity.h"
#import "UIAlertView_TLCommon.h"
#import "UIScrollView+Helper.h"

#define kTileWidth 1024.0f
#define kTileHeight 1024.0f

#pragma mark -

@interface SingleComicViewController ()

- (void)toggleToolbarsAnimated:(BOOL)animated;
- (void)goToPreviousComic;
- (void)goToRandomComic;
- (void)goToNextComic;
- (void)displayComicImage;
- (void)setupToolbar;
- (void)displayLoadingView;
- (void)goToComicNumbered:(NSUInteger)comicNumber;
- (void)calculateZoomScaleAndAnimate:(BOOL)animate;

@property(nonatomic, strong, readwrite) Comic *comic;
@property(nonatomic, strong, readwrite) NSMutableArray *comicImageViews;
@property(nonatomic, strong, readwrite) UIView *contentView;
@property(nonatomic, strong, readwrite) UIScrollView *imageScroller;
@property(nonatomic, strong, readwrite) TLLoadingView *loadingView;
@property(nonatomic, strong, readwrite) SingleComicImageFetcher *imageFetcher;

@end

#pragma mark -

@implementation SingleComicViewController

- (id)initWithComic:(Comic *)comicToView {
  if(self = [super initWithNibName:nil bundle:nil]) {
    _comic = comicToView;
    self.title = _comic.name;
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;

  [self setupToolbar];

  if(self.comic.downloaded) {
    [self displayComicImage];    
  } else {
    [self displayLoadingView];
    self.imageFetcher = [[SingleComicImageFetcher alloc] init];
    self.imageFetcher.delegate = self;    
    [self.imageFetcher fetchImageForComic:self.comic context:nil];
  }
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
  [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
  [self calculateZoomScaleAndAnimate:YES];
}

- (void)setupToolbar {
  UIBarButtonItem *systemActionItem = [UIBarButtonItem barButtonSystemItem:UIBarButtonSystemItemAction
                                                                    target:self
                                                                    action:@selector(systemAction:)];
  
  UIBarButtonItem *previousItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"down"]
                                                                    style:UIBarButtonItemStylePlain
                                                                   target:self
                                                                   action:@selector(goToPreviousComic)];
  previousItem.accessibilityLabel = NSLocalizedString(@"Older comic", @"older_comic_accessibility_label");
  previousItem.enabled = (self.comic.number.unsignedIntegerValue != kMinComicNumber);

  UIBarButtonItem *randomItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"glyphish_shuffle"]
                                                                  style:UIBarButtonItemStylePlain
                                                                 target:self
                                                                 action:@selector(goToRandomComic)];
  randomItem.accessibilityLabel = NSLocalizedString(@"Random comic", @"random_comic_accessibility_label");

  UIBarButtonItem *nextItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"up"]
                                                                style:UIBarButtonItemStylePlain
                                                               target:self
                                                               action:@selector(goToNextComic)];
  nextItem.accessibilityLabel = NSLocalizedString(@"Newer comic", @"newer_comic_accessibility_label");
  nextItem.enabled = (self.comic.number.unsignedIntegerValue != [Comic lastKnownComic].number.unsignedIntegerValue);
  
  NSArray *toolbarItems = @[systemActionItem,
                           [UIBarButtonItem flexibleSpaceBarButtonItem],
                           [UIBarButtonItem flexibleSpaceBarButtonItem],
                           [UIBarButtonItem flexibleSpaceBarButtonItem],
                           [UIBarButtonItem flexibleSpaceBarButtonItem],
                           previousItem,
                           [UIBarButtonItem flexibleSpaceBarButtonItem],
                           randomItem,
                           [UIBarButtonItem flexibleSpaceBarButtonItem],
                           nextItem];
  
  [self setToolbarItems:toolbarItems animated:NO];
  [self.navigationController setToolbarHidden:NO animated:NO];  
}

- (void)displayComicImage {
  // Load up the comic image/view
  UIImage *comicImage = self.comic.image;
  CGSize contentSize = comicImage.exifAgnosticSize;
  TiledImage *tiles = [[TiledImage alloc] initWithImage:comicImage tileWidth:kTileWidth tileHeight:kTileHeight];
  self.contentView = [[UIView alloc] initWithFrame:CGRectZeroWithSize(contentSize)];
  self.comicImageViews = [NSMutableArray arrayWithCapacity:(tiles.widthCount * tiles.heightCount)];
  for(NSUInteger x = 0; x < tiles.widthCount; ++x) {
    for(NSUInteger y = 0; y < tiles.heightCount; ++y) {
      UIImageView *comicImageView = [[UIImageView alloc] initWithImage:[tiles imageAtXIndex:x YIndex:y]];
      comicImageView.frame = CGRectWithXYAndSize(x * kTileWidth, y * kTileHeight, comicImageView.frame.size); // adjust origin appropriately
      [self.comicImageViews addObject:comicImageView];
    }
  }
  
  // Scroll view
  self.imageScroller = [[UIScrollView alloc] initWithFrame:self.view.bounds];
  self.imageScroller.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  self.imageScroller.backgroundColor = [UIColor whiteColor];
  self.imageScroller.delaysContentTouches = NO;
  self.imageScroller.alwaysBounceVertical = YES;
  self.imageScroller.alwaysBounceHorizontal = YES;
  self.imageScroller.delegate = self;
  self.imageScroller.bouncesZoom = YES;
  self.imageScroller.scrollEnabled = YES;
  self.imageScroller.scrollsToTop = NO;
  [self.view addSubview:self.imageScroller];
  
  [self calculateZoomScaleAndAnimate:NO];
  
  for(UIView *tileView in self.comicImageViews) {
    [self.contentView addSubview:tileView];
  }
  [self.imageScroller addSubview:self.contentView];
  
  if([AppDelegate openZoomedOut]) {
    [self.imageScroller setZoomScale:self.imageScroller.minimumZoomScale animated:NO];
  }

  UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(showTitleText:)];
  longPress.minimumPressDuration = 0.5f;
  [self.view addGestureRecognizer:longPress];

  UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didDetectDoubleTap:)];
  doubleTap.numberOfTapsRequired = 2;
  [self.view addGestureRecognizer:doubleTap];

  UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didDetectSingleTap:)];
  [singleTap requireGestureRecognizerToFail:doubleTap];
  [self.view addGestureRecognizer:singleTap];
  
  self.view.isAccessibilityElement = YES;
  self.view.accessibilityHint = nil;

  if(self.comic.transcript.length == 0) {
    self.view.accessibilityLabel = @"Transcript not available";
    NSLog(@"Missing transcript for comic %i", self.comic.number.integerValue);
  } else {
    self.view.accessibilityLabel = self.comic.transcript; // TODO: Clean up the transcript some for a more pleasant listening experience
  }
}

- (void) calculateZoomScaleAndAnimate:(BOOL)animate {
  CGSize contentSize = self.comic.image.exifAgnosticSize;
  self.imageScroller.contentSize = contentSize;
  self.imageScroller.maximumZoomScale = 2;
  CGFloat xMinZoom = self.imageScroller.frame.size.width / contentSize.width;
  CGFloat yMinZoom = (self.imageScroller.frame.size.height - (self.navigationController.navigationBar.frame.size.height + self.navigationController.toolbar.frame.size.height)) / contentSize.height;
  self.imageScroller.minimumZoomScale = (xMinZoom < yMinZoom) ? xMinZoom : yMinZoom;
  if (self.imageScroller.zoomScale < self.imageScroller.minimumZoomScale) {
    [self.imageScroller setZoomScale:self.imageScroller.minimumZoomScale animated:animate];
  }
}

- (void)displayLoadingView {
  self.loadingView = [[TLLoadingView alloc] initWithFrame:self.view.bounds];
  self.loadingView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  [self.loadingView setNeedsLayout];
  [self.view addSubview:self.loadingView];
}

- (void)toggleToolbarsAnimated:(BOOL)animated {
  BOOL toolbarIsHidden = self.navigationController.toolbarHidden;
  [self.navigationController setToolbarHidden:!toolbarIsHidden animated:animated];
  [self.navigationController setNavigationBarHidden:!toolbarIsHidden animated:animated];  
}

- (void)systemAction:(UIBarButtonItem *)sender {
  OpenInSafariActivity *safariActivity = [[OpenInSafariActivity alloc] init];
  OpenInChromeActivity *chromeActivity = [[OpenInChromeActivity alloc] init];

  NSMutableArray *activityItems = [NSMutableArray arrayWithCapacity:2];
  NSURL *comicUrl = [NSURL URLWithString:self.comic.websiteURL];
  [activityItems addObject:comicUrl];
  if(self.comic.downloaded) {
    [activityItems addObject:self.comic.image];
  }

  UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:activityItems
                                                                                       applicationActivities:@[safariActivity, chromeActivity]];
  activityViewController.excludedActivityTypes = @[UIActivityTypeAssignToContact];
  [self presentViewController:activityViewController animated:YES completion:^{}];
}

- (void)goToPreviousComic {
  [self goToComicNumbered:([self.comic.number unsignedIntegerValue] - 1)];
}

- (void)goToRandomComic {
  NSUInteger maxComicNumber = [[Comic lastKnownComic].number unsignedIntegerValue];
  long randNumber = [TLMersenneTwister randInt31];
  NSUInteger randomComicNumber = randNumber % (maxComicNumber - kMinComicNumber) + kMinComicNumber;
  [self goToComicNumbered:randomComicNumber];
}

- (void)goToNextComic {
  [self goToComicNumbered:([self.comic.number unsignedIntegerValue] + 1)];
}

- (void)goToComicNumbered:(NSUInteger)comicNumber {
  NSMutableArray *viewControllerStack = [self.navigationController.viewControllers mutableCopy];
  Comic *newComic = [Comic comicNumbered:comicNumber];
  SingleComicViewController *newSingleComicViewController = [[SingleComicViewController alloc] initWithComic:newComic]; 
  [viewControllerStack replaceObjectAtIndex:[viewControllerStack count] - 1
                                 withObject:newSingleComicViewController];
  [self.navigationController setViewControllers:viewControllerStack animated:NO];

  ComicListViewController *comicList = [viewControllerStack objectAtIndex:0];
  [comicList.tableView selectRowAtIndexPath:[comicList indexPathForComicNumbered:[newComic.number integerValue]]
                                   animated:NO
                             scrollPosition:UITableViewScrollPositionMiddle];
}

#pragma mark - Gesture recognizer callbacks

- (void)didDetectDoubleTap:(UITapGestureRecognizer *)recognizer {
  CGFloat newZoomScale = 1.0f;
  if(self.imageScroller.zoomScale == self.imageScroller.minimumZoomScale) {
    newZoomScale = (self.imageScroller.minimumZoomScale * 2) > self.imageScroller.maximumZoomScale ? self.imageScroller.maximumZoomScale : (self.imageScroller.minimumZoomScale * 2);
    // zoom towards the user's double tap
    [self.imageScroller setZoomScale:newZoomScale animated:YES centerOnPoint:[recognizer locationInView:self.imageScroller]];
  } else {
    newZoomScale = self.imageScroller.minimumZoomScale;
    [self.imageScroller setZoomScale:newZoomScale animated:YES];
  }
  
}

- (void)didDetectSingleTap:(UITapGestureRecognizer *)recognizer {
  [self toggleToolbarsAnimated:YES];
}

- (void)showTitleText:(UILongPressGestureRecognizer *)recognizer {
  if(recognizer.state == UIGestureRecognizerStateBegan) {
    [UIAlertView showAlertWithTitle:nil message:self.comic.titleText];
  }
}

#pragma mark - SingleComicImageFetcherDelegate methods

- (void)singleComicImageFetcher:(SingleComicImageFetcher *)fetcher
          didFetchImageForComic:(Comic *)comic
                        context:(id)context {
  self.imageFetcher = nil;
  [self.loadingView removeFromSuperview];
  [self displayComicImage];
}

- (void)singleComicImageFetcher:(SingleComicImageFetcher *)fetcher
               didFailWithError:(NSError *)error
                        onComic:(Comic *)comic {
  [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - UIScrollViewDelegate methods

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
  return self.contentView;
}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(float)scale {
}

@end
