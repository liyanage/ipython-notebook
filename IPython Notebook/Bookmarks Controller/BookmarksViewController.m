//
//  BookmarksViewController.m
//  IPython Notebook
//
//  Created by Marc Liyanage on 2/22/13.
//  Copyright (c) 2013 Marc Liyanage. All rights reserved.
//

#import "BookmarksViewController.h"


@interface BookmarksViewController ()
@property (strong) NSMutableDictionary *bookmarkPathToURLMap;
@end


@implementation BookmarksViewController


- (void)awakeFromNib
{
	[self startUsingPersistedBookmarks];
	[self.view registerForDraggedTypes:@[@"public.file-url"]];
	[self.bookmarksTableView setTarget:self];
	[self.bookmarksTableView setDoubleAction:@selector(doubleClickInTableView:)];

}

- (void)startUsingPersistedBookmarks
{
	self.bookmarkPathToURLMap = [NSMutableDictionary dictionary];
	for (NSDictionary *bookmarkInfo in self.bookmarksArrayController.arrangedObjects) {
		NSData *bookmarkData = bookmarkInfo[@"bookmarkData"];
		BOOL isStale = NO;
		NSURL *url = [NSURL URLByResolvingBookmarkData:bookmarkData options:NSURLBookmarkResolutionWithSecurityScope relativeToURL:nil bookmarkDataIsStale:&isStale error:nil];
		if (!url || isStale) {
			continue;
		}
		[url startAccessingSecurityScopedResource];
		self.bookmarkPathToURLMap[bookmarkInfo[@"bookmarkPath"]] = url;
	}
}

- (IBAction)addBookmark:(id)sender {
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	openPanel.canChooseDirectories = YES;
	openPanel.canChooseFiles = YES;
	openPanel.allowsMultipleSelection = YES;
	openPanel.prompt = NSLocalizedString(@"Allow Access", nil);
	openPanel.message = NSLocalizedString(@"Choose folders and files to which iPython Notebook should get access.", nil);
	openPanel.canCreateDirectories = YES;
	
	[openPanel beginSheetModalForWindow:[self.view window] completionHandler:^(NSInteger result) {
		if (result != NSFileHandlingPanelOKButton) {
			return;
		}
		[self addBookmarkEntriesForURLs:[openPanel URLs]];
	}];
}

- (IBAction)doubleClickInTableView:(NSTableView *)sender
{
	if (![[self.bookmarksArrayController selectionIndexes] containsIndex:[sender clickedRow]]) {
		return;
	}

	NSMutableArray *urls = [NSMutableArray array];
	for (NSDictionary *bookmarkInfo in self.bookmarksArrayController.selectedObjects) {
		NSURL *url = self.bookmarkPathToURLMap[bookmarkInfo[@"bookmarkPath"]];
		NSAssert(url, @"URL for path %@ not found", bookmarkInfo[@"bookmarkPath"]);
		if (!url) {
			continue;
		}
		[urls addObject:url];
	}

	[[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:urls];
}

- (BOOL)addBookmarkEntriesForPaths:(NSArray *)paths
{
	NSMutableArray *urls = [NSMutableArray array];
	for (NSString *path in paths) {
		NSURL *url = [NSURL fileURLWithPath:path];
		if (url) {
			[urls addObject:url];
		}
	}
	return [self addBookmarkEntriesForURLs:urls];
}


- (BOOL)addBookmarkEntriesForURLs:(NSArray *)urls
{
	BOOL didAddSuccessfully = YES;
	NSMutableArray *newEntries = [NSMutableArray array];
	for (NSURL *url in urls) {
		NSString *path = [url path];
		if ([self.bookmarkPathToURLMap objectForKey:path]) {
			continue;
		}
		NSDictionary *dict = [self bookmarkDictionaryItemForURL:url];
		if (!dict) {
			didAddSuccessfully = NO;
			continue;
		}
		self.bookmarkPathToURLMap[path] = url;
		[newEntries addObject:dict];
	}
	if ([newEntries count]) {
		[self.bookmarksArrayController addObjects:newEntries];
	}
	return didAddSuccessfully;
}


- (NSMutableDictionary *)bookmarkDictionaryItemForURL:(NSURL *)url
{
	NSMutableDictionary *item = [NSMutableDictionary dictionary];
	item[@"bookmarkPath"] = [url path];
	
	NSImage *iconImage = [[NSWorkspace sharedWorkspace] iconForFile:[url path]];
	NSImageRep *rep = [iconImage bestRepresentationForRect:NSMakeRect(0, 0, 32, 32) context:nil hints:nil];
	NSImage *smallImage = [[NSImage alloc] init];
	[smallImage addRepresentation:rep];
	item[@"iconImageData"] = [NSKeyedArchiver archivedDataWithRootObject:smallImage];
	
	NSError *error;
	NSData *bookmarkData = [url bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope includingResourceValuesForKeys:nil relativeToURL:nil error:&error];
	if (!bookmarkData) {
		NSLog(@"Unable to add bookmark data for %@: %@", url, error);
		return nil;
	}
	item[@"bookmarkData"] = bookmarkData;
	
	return item;
}

- (IBAction)removeBookmark:(id)sender {
	for (NSDictionary *bookmarkInfo in [self.bookmarksArrayController selectedObjects]) {
		NSString *path = bookmarkInfo[@"bookmarkPath"];
		NSURL *url = [self.bookmarkPathToURLMap objectForKey:path];
		if (url) {
			[url stopAccessingSecurityScopedResource];
			[self.bookmarkPathToURLMap removeObjectForKey:path];
		}
	}
	[self.bookmarksArrayController remove:sender];
}


@end
