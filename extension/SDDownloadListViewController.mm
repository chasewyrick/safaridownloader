/*
 * SDDownloadListViewController
 * SDM
 * Dustin Howett 2012-01-30
 */
#import <QuartzCore/QuartzCore.h>
#import "SDDownloadManager.h"
#import "SDDownloadListViewController.h"
#import "DownloadCell.h"
#import "DownloaderCommon.h"
#import "ModalAlert.h"
#import "SDResources.h"

#import "SDMVersioning.h"
#import "SDMCommonClasses.h"
#import "SDDownloadPromptView.h"
#import "SDFileType.h"

#import "SDDownloadModel.h"

@interface UIDevice (Wildcat)
- (BOOL)isWildcat;
@end

@interface UIApplication (Safari)
- (void)applicationOpenURL:(id)url;
@end

@interface SDDownloadListViewController ()
- (NSString *)_formatSize:(double)size;
- (void)_updateRightButton;
- (SDDownloadCell*)_cellForDownload:(SDSafariDownload*)download;
- (void)_updateCell:(SDDownloadCell *)cell forDownload:(SDSafariDownload *)download;
@end
@implementation SDDownloadListViewController
@synthesize currentSelectedIndexPath = _currentSelectedIndexPath;

#pragma mark -

- (void)_attachToDownloadManager {
	if(!_dataModel) {
		_dataModel = [[SDDownloadManager sharedManager] dataModel];
		[_dataModel addObserver:self forKeyPath:@"runningDownloads" options:0 context:NULL];
		[_dataModel addObserver:self forKeyPath:@"finishedDownloads" options:0 context:NULL];
	}
	[[SDDownloadManager sharedManager] setDownloadObserver:self];
}

- (void)_detachFromDownloadManager {
	if(_dataModel) {
		[_dataModel removeObserver:self forKeyPath:@"finishedDownloads"];
		[_dataModel removeObserver:self forKeyPath:@"runningDownloads"];
		_dataModel = nil;
	}
	[[SDDownloadManager sharedManager] setDownloadObserver:nil];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inter {
	return YES;
}

- (void)dealloc {
	[self _detachFromDownloadManager];
	[_currentSelectedIndexPath release];
	[super dealloc];
}

- (void)cancelAllDownloads {
	UIAlertView* alert = nil;
	if(_dataModel.runningDownloads.count > 0) {
		alert = [[UIAlertView alloc] initWithTitle:SDLocalizedString(@"Cancel All Downloads?")
						   message:nil
						  delegate:self
					 cancelButtonTitle:SDLocalizedString(@"No")
					 otherButtonTitles:SDLocalizedString(@"Yes"), nil];
	} else {
		alert = [[UIAlertView alloc] initWithTitle:SDLocalizedString(@"Nothing to Cancel")
						   message:nil
						  delegate:self
					 cancelButtonTitle:SDLocalizedString(@"OK")
					 otherButtonTitles:nil];
	}
	
	[alert show];
	[alert release];
}

- (void)alertView:(UIAlertView *)alert clickedButtonAtIndex:(NSInteger)buttonIndex {
	/*
	if (buttonIndex == 1) {
		if (_currentDownloads.count > 0) {
			[_downloadQueue cancelAllOperations];
			[_currentDownloads removeAllObjects];
		[self saveData];
			[_tableView deleteSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationFade];
		}
	} 
	*/
}

- (SDDownloadCell*)_cellForDownload:(SDSafariDownload*)download {
	return (SDDownloadCell *)[self.tableView cellForRowAtIndexPath:[_dataModel indexPathForDownload:download]];
}

- (void)clearAllDownloads {
	[_dataModel emptyList:SDDownloadModelFinishedList];
}

#pragma mark -/*}}}*/
#pragma mark UIViewController Methods/*{{{*/

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning]; 
}

- (void)viewDidLoad {
	[super viewDidLoad];

	UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle:@"---" 
									 style:UIBarButtonItemStylePlain
									target:self
									action:NULL];
	self.navigationItem.rightBarButtonItem = cancelButton;
	self.navigationItem.rightBarButtonItem.enabled = YES;
	
	if(!SDM$WildCat) {
		UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:SDLocalizedString(@"Done")
									 style:UIBarButtonItemStyleDone 
									target:[self navigationController]
									action:@selector(close)];
		self.navigationItem.leftBarButtonItem = doneButton;
		self.navigationItem.leftBarButtonItem.enabled = YES;
	}

	self.tableView.rowHeight = 56;
}

- (void)viewDidUnload {
	[super viewDidUnload]; 
}

- (void)updateRunningDownloads:(NSTimer *)timer {
	NSArray *indexPaths = [self.tableView indexPathsForVisibleRows];
	for(NSIndexPath *indexPath in indexPaths) {
		if(indexPath.section != 0) continue;
		SDSafariDownload *download = [_dataModel.runningDownloads objectAtIndex:indexPath.row];
		if(download.status != SDDownloadStatusRunning) continue;

		[self _updateProgressForDownload:download inCell:[self.tableView cellForRowAtIndexPath:indexPath]];
	}
}

- (void)viewWillAppear:(BOOL)animated {
	[self _attachToDownloadManager];
	[self _updateRightButton];
	[super viewWillAppear:animated];
	[self.tableView reloadData];
	_updateTimer = [[NSTimer scheduledTimerWithTimeInterval:.5f target:self selector:@selector(updateRunningDownloads:) userInfo:nil repeats:YES] retain];
}

- (void)viewWillDisappear:(BOOL)animated {
	[_updateTimer invalidate];
	[_updateTimer release];
	[self _detachFromDownloadManager];
	[super viewWillDisappear:animated];
}

- (id)title {
	return @"Downloads";
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	NSUInteger section;
	if([keyPath isEqualToString:@"runningDownloads"]) section = 0;
	else section = 1;
	NSIndexSet *indexSet = [change objectForKey:NSKeyValueChangeIndexesKey];
	NSUInteger indices[indexSet.count];
	[indexSet getIndexes:indices maxCount:indexSet.count inIndexRange:nil];
	NSMutableArray *newIndexPaths = [NSMutableArray array];
	for(unsigned int i = 0; i < indexSet.count; i++) {
		[newIndexPaths addObject:[NSIndexPath indexPathForRow:indices[i] inSection:section]];
	}
	switch([[change objectForKey:NSKeyValueChangeKindKey] intValue]) {
		case NSKeyValueChangeInsertion:
			[self.tableView insertRowsAtIndexPaths:newIndexPaths withRowAnimation:UITableViewRowAnimationFade];
			break;
		case NSKeyValueChangeRemoval:
			[self.tableView deleteRowsAtIndexPaths:newIndexPaths withRowAnimation:UITableViewRowAnimationFade];
			break;
	}
	[self _updateRightButton];
}

- (NSString *)_formatSize:(double)size {
	if(size < 1024.) return [NSString stringWithFormat:@"%.1lf B", size];
	size /= 1024.;
	if(size < 1024.) return [NSString stringWithFormat:@"%.1lf KB", size];
	size /= 1024.;
	return [NSString stringWithFormat:@"%.1lf MB", size];
}

/* {{{ Download Observer */
- (void)downloadDidChangeStatus:(SDSafariDownload *)download {
	SDDownloadCell *cell = [self _cellForDownload:download];
	if(!cell) return;
	[self _updateCell:cell forDownload:download];
}

- (void)downloadDidReceiveData:(SDSafariDownload *)download {
	SDDownloadCell *cell = [self _cellForDownload:download];
	if(!cell) return;
	[self _updateCell:cell forDownload:download];
}
/* }}} */

- (void)_updateRightButton {
	if(_dataModel.runningDownloads.count > 0) {
		self.navigationItem.rightBarButtonItem.title = SDLocalizedString(@"Cancel All");
		self.navigationItem.rightBarButtonItem.action = @selector(cancelAllDownloads);
	} else {
		self.navigationItem.rightBarButtonItem.title = SDLocalizedString(@"Clear All");
		self.navigationItem.rightBarButtonItem.action = @selector(clearAllDownloads);
	}
}

#pragma mark -/*}}}*/
#pragma mark UITableView methods/*{{{*/

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 2;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return 0.f;
}

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (tableView.numberOfSections == 2 && section == 0)
		return _dataModel.runningDownloads.count;
	else
		return _dataModel.finishedDownloads.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *CellIdentifier = @"SDDownloadCell";
	BOOL finished = NO;
	SDSafariDownload *download = nil;
	
	if(tableView.numberOfSections == 2 && indexPath.section == 0) {
		download = [_dataModel.runningDownloads objectAtIndex:indexPath.row];
		finished = NO;
	} else {
		CellIdentifier = @"FinishedSDDownloadCell";
		download = [_dataModel.finishedDownloads objectAtIndex:indexPath.row];
		finished = YES;
	}
	
	SDDownloadCell *cell = (SDDownloadCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	if (cell == nil) {
		cell = [[[SDDownloadCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
	}
	
	// Set up the cell...
	cell.finished = finished;
	//cell.icon = [SDResources iconForFileType:[SDFileType fileTypeForExtension:[download.filename pathExtension] orMIMEType:download.mimetype]];
	cell.icon = [SDResources iconForFileType:[SDFileType fileTypeForExtension:[download.filename pathExtension] orMIMEType:nil]];
	cell.nameLabel = download.filename;
	cell.sizeLabel = [self _formatSize:download.totalBytes];

	if(!finished && download.status != SDDownloadStatusFailed) {
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
	} else {
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	}

	[self _updateCell:cell forDownload:download];
	return cell;
}

- (void)_updateProgressForDownload:(SDSafariDownload *)download inCell:(SDDownloadCell *)cell {
	float speed = ((double)download.downloadedBytes - (double)download.startedFromByte) / (-1*[download.startDate timeIntervalSinceNow]);
	cell.progressView.progress = (double)download.downloadedBytes / (double)download.totalBytes;
	cell.progressLabel = [NSString stringWithFormat:@"Downloading @ %@/sec", [self _formatSize:speed]];
}

- (void)_updateCell:(SDDownloadCell *)cell forDownload:(SDSafariDownload *)download {
	BOOL finished = download.status == SDDownloadStatusCompleted;
	cell.failed = download.status == SDDownloadStatusFailed;
	if(!finished && download.status != SDDownloadStatusFailed) {
		if(download.status == SDDownloadStatusRunning) {
			[self _updateProgressForDownload:download inCell:cell];
		} else {
			cell.progressLabel = SDLocalizedString(@"Waiting...");
		}
		cell.progressView.progress = (double)download.downloadedBytes / (double)download.totalBytes;
	} else {
		if (download.status == SDDownloadStatusFailed) {
			cell.progressLabel = SDLocalizedString(@"Download Failed");
		}
		else {
			cell.progressLabel = [download.path stringByAbbreviatingWithTildeInPath];
		}
	}
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if(indexPath.section == 0) return 74;
	else return 58;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if(indexPath.section == 0) {
		[tableView deselectRowAtIndexPath:indexPath animated:YES];
		return;
	}
	self.currentSelectedIndexPath = indexPath;
	if(indexPath.section == 1) {
		id download = [_dataModel.finishedDownloads objectAtIndex:indexPath.row];
		id launch = [[SDDownloadActionSheet alloc] initWithDownload:download delegate:self];
		[launch showInView:self.view];
		[launch release];
	}
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	return YES;
}

- (NSString *)tableView:(UITableView *)tableView 
titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
	if(indexPath.section == 0)
		return SDLocalizedString(@"Cancel");
	else // local files
		return SDLocalizedString(@"Clear");
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		if(indexPath.section == 0) {
			id download = [_dataModel.runningDownloads objectAtIndex:indexPath.row];//[_currentDownloads objectAtIndex:indexPath.row];
			[[SDDownloadManager sharedManager] cancelDownload:download];
		} else {
			[_dataModel removeDownload:[_dataModel.finishedDownloads objectAtIndex:indexPath.row] fromList:SDDownloadModelFinishedList];
		}
	}
}
/*}}}*/

- (void)downloadActionSheet:(SDDownloadActionSheet *)actionSheet retryDownload:(SDSafariDownload *)download {
	/*
	int row = [_finishedDownloads indexOfObject:download];
	int section = (_currentDownloads.count > 0) ? 1 : 0;
	[download retain];
	[_finishedDownloads removeObjectAtIndex:row];
	[_tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:row inSection:section]] 
										withRowAnimation:UITableViewRowAnimationFade];
	download.failed = NO;
	download.useSuggest = NO;
	[self addDownload:download browser:NO];
	*/
}

- (void)downloadActionSheet:(SDDownloadActionSheet *)actionSheet deleteDownload:(SDSafariDownload *)download {
	[[SDDownloadManager sharedManager] deleteDownload:download];
/*
	NSString *path = [NSString stringWithFormat:@"%@/%@", download.path, download.filename];
	int row = [_finishedDownloads indexOfObject:download];
	int section = (_currentDownloads.count > 0) ? 1 : 0;

	[_finishedDownloads removeObjectAtIndex:row];
	[_tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:row inSection:section]] 
										withRowAnimation:UITableViewRowAnimationFade];

	[[objc_getClass("SandCastle") sharedInstance] removeItemAtResolvedPath:path];
	*/
}

- (void)downloadActionSheetWillDismiss:(SDDownloadActionSheet *)actionSheet {
	[(UITableView *)self.view deselectRowAtIndexPath:self.currentSelectedIndexPath animated:YES];
	self.currentSelectedIndexPath = nil;
}
@end

// vim:filetype=objc:ts=8:sw=8:noexpandtab