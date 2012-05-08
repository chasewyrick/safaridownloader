#import "SDDownloadModel.h"

#import <SandCastle/SandCastle.h>
#import "SDMCommonClasses.h"
#import "SDSafariDownload.h"

#define DL_ARCHIVE_PATH @"/var/mobile/Library/Caches/net.howett.safaridownloader.plist"

@interface SDDownloadModel ()
- (NSMutableArray *)_arrayForListType:(SDDownloadModelList)list keyName:(NSString **)keyNamePtr;
@end

@implementation SDDownloadModel
@synthesize runningDownloads = _runningDownloads, finishedDownloads = _finishedDownloads;
- (id)init {
	if((self = [super init]) != nil) {
		_runningDownloads = [[NSMutableArray alloc] init];
		_finishedDownloads = [[NSMutableArray alloc] init];
	} return self;
}

- (void)loadData {
	NSString *path = @"/tmp/.sdm.plist";
	[[SDM$SandCastle sharedInstance] copyItemAtPath:DL_ARCHIVE_PATH toPath:path];
	NSDictionary *loaded = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
	if(loaded) {
		[_runningDownloads addObjectsFromArray:[loaded objectForKey:@"running"]];
		[_finishedDownloads addObjectsFromArray:[loaded objectForKey:@"finished"]];
	}
	NSLog(@"loaded %@", loaded);
}

- (void)saveData {
	NSString *path = @"/tmp/.sdm.plist";
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:
			[NSDictionary dictionaryWithObjectsAndKeys:_runningDownloads, @"running",
								_finishedDownloads, @"finished", nil]];
	if(data) {
		[data writeToFile:path atomically:YES];
		[[SDM$SandCastle sharedInstance] copyItemAtPath:path toPath:DL_ARCHIVE_PATH];
	}
}

- (NSMutableArray *)_arrayForListType:(SDDownloadModelList)list keyName:(NSString **)keyNamePtr {
	switch(list) {
		case SDDownloadModelRunningList:
			if(keyNamePtr) *keyNamePtr = @"runningDownloads";
			return _runningDownloads;
		case SDDownloadModelFinishedList:
			if(keyNamePtr) *keyNamePtr = @"finishedDownloads";
			return _finishedDownloads;
	}
	return nil;
}

- (SDSafariDownload *)downloadWithURL:(NSURL*)url {
	for (SDSafariDownload *download in _runningDownloads) {
		if ([[download.URLRequest URL] isEqual:url])
			return download;
	}
	return nil; 
}

- (void)addDownload:(SDSafariDownload *)download toList:(SDDownloadModelList)list {
	NSString *keyName = nil;
	NSMutableArray *array = [self _arrayForListType:list keyName:&keyName];
	NSLog(@"Adding download %@ to list %@ key %@", download, array, keyName);
	NSInteger count = array.count;
	[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:[NSIndexSet indexSetWithIndex:count] forKey:keyName];
	[array addObject:download];
	[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:[NSIndexSet indexSetWithIndex:count] forKey:keyName];
	[self saveData];
}

- (void)removeDownload:(SDSafariDownload *)download fromList:(SDDownloadModelList)list {
	NSString *keyName = nil;
	NSMutableArray *array = [self _arrayForListType:list keyName:&keyName];
	NSInteger index = [array indexOfObjectIdenticalTo:download];
	if(index == NSNotFound) return;
	[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:keyName];
	[array removeObjectAtIndex:index];
	[self didChange:NSKeyValueChangeRemoval valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:keyName];
	[self saveData];
}

- (void)emptyList:(SDDownloadModelList)list {
	NSString *keyName = nil;
	NSMutableArray *array = [self _arrayForListType:list keyName:&keyName];
	NSRange removals = (NSRange){0, array.count};
	[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:[NSIndexSet indexSetWithIndexesInRange:removals] forKey:keyName];
	[array removeAllObjects];
	[self didChange:NSKeyValueChangeRemoval valuesAtIndexes:[NSIndexSet indexSetWithIndexesInRange:removals] forKey:keyName];
	[self saveData];
}

- (void)moveDownload:(SDSafariDownload *)download toList:(SDDownloadModelList)list {
	[download retain];
	NSMutableArray *target = [self _arrayForListType:list keyName:NULL];
	if(![target containsObject:download]) {
		[self removeDownload:download fromList:(list == SDDownloadModelFinishedList ? SDDownloadModelRunningList : SDDownloadModelFinishedList)];
		[self addDownload:download toList:list];
	}
	[download release];
}

- (NSIndexPath *)indexPathForDownload:(SDSafariDownload *)download {
	int row = -1;
	if((row = [_runningDownloads indexOfObjectIdenticalTo:download]) != NSNotFound) {
		return [NSIndexPath indexPathForRow:row inSection:0];
	} else if((row = [_finishedDownloads indexOfObjectIdenticalTo:download]) != NSNotFound) {
		return [NSIndexPath indexPathForRow:row inSection:1];
	}
	return nil;
}
@end