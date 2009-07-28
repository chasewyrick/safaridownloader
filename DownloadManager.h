//
//  DownloadManager.h
//  Downloader
//
//  Created by Youssef Francis on 7/23/09.
//  Copyright 2009 Brancipater Software. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SafariDownload.h"
#import "Safari/BrowserPanel.h"
#import "UIKitExtra/UIToolbarButton.h"

#define kProgressViewTag 238823
#define progressViewForCell(cell) ((UIProgressView*)[cell viewWithTag:kProgressViewTag])

@interface DownloadManagerPanel : NSObject <BrowserPanel>
{
  BOOL _allowsRotations; 
}
- (void)allowRotations:(BOOL)allow;
@end

@interface DownloadManager : UITableViewController <SafariDownloadDelegate, UITableViewDataSource, UITableViewDelegate, UIAlertViewDelegate> {
  UITableView*      _tableView;
  NSArray*          _mimeTypes;
  NSMutableArray*   _currentDownloads;
  NSMutableArray*   _finishedDownloads;
  NSOperationQueue* _downloadQueue;
  UIToolbarButton*  _portraitDownloadButton;
  UIToolbarButton*  _landscapeDownloadButton;
  UINavigationItem* _navItem;
  UINavigationBar*  _navBar;
  DownloadManagerPanel *_panel;
}

@property (nonatomic, retain) UINavigationItem* navItem;

+ (id)sharedManager;
- (UIImage *)iconForExtension:(NSString *)extension;
- (BOOL)supportedRequest:(NSURLRequest *)request 
            withMimeType:(NSString *)mimeType;

- (BOOL)addDownloadWithInfo:(NSDictionary*)info;
- (BOOL)addDownloadWithURL:(NSURL*)url;
- (BOOL)addDownloadWithRequest:(NSURLRequest*)url;
- (BOOL)addDownload:(SafariDownload *)download;
- (BOOL)cancelDownload:(SafariDownload *)download;
- (BOOL)cancelDownloadWithURL:(NSURL *)url;
- (IBAction)cancelAllDownloads;

- (DownloadManagerPanel*)browserPanel;
- (void)showDownloadManager;
- (IBAction)hideDownloadManager;

- (UIImage *)iconForExtension:(NSString *)extension;

// This seems hackish, but is for badging purposes.
- (void)setPortraitDownloadButton:(id)portraitButton;
- (void)setLandscapeDownloadButton:(id)landscapeButton;
- (void)updateBadges;
@end
