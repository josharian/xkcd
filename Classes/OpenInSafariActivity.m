//
//  OpenInSafariActivity.m
//  xkcd
//

#import "OpenInSafariActivity.h"

#pragma mark -

@implementation OpenInSafariActivity

- (NSString *)activityType {
  return @"com.treelinelabs.xkcdapp.open_in_safari";
}

- (NSString *)activityTitle {
  return NSLocalizedString(@"Open in Safari", @"Open in Safari Activity Title");
}

- (void)performActivity {
  [[UIApplication sharedApplication] openURL:self.urlToOpen];
  [self activityDidFinish:YES];
}

@end
