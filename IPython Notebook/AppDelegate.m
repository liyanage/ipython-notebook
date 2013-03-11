//
//  AppDelegate.m
//  IPython Notebook
//
//  Created by Marc Liyanage on 2/5/13.
//  Copyright (c) 2013 Marc Liyanage. All rights reserved.
//

#import "AppDelegate.h"
#import "BookmarksViewController.h"
#import "NotebookWindowController.h"

@interface AppDelegate ()
@property (strong) NotebookWindowController *notebookController;
@end


@implementation AppDelegate

- (void)awakeFromNib
{
	self.notebookController = [[NotebookWindowController alloc] initWithWindowNibName:@"NotebookWindowController"];
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[self.notebookController showWindow:nil];
}


- (IBAction)openPreferencesWindow:(id)sender
{
	if (![self.bookmarksViewController.view superview]) {
		NSView *bookmarksView = self.bookmarksViewController.view;
		[self.bookmarksPlaceholderView addSubview:bookmarksView];
	}
	[self.preferencesWindow makeKeyAndOrderFront:sender];
}


#pragma mark - NSApplicationDelegate protocol implementation

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
	return [self.notebookController applicationShouldTerminate:(NSApplication *)sender];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	[self.notebookController applicationWillTerminate:aNotification];
}


- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames
{
	NSMutableArray *folders = [NSMutableArray array];
	NSMutableArray *notebookDocuments = [NSMutableArray array];
	for (NSString *path in filenames) {
		if (![[path pathExtension] compare:NOTEBOOK_PATH_EXTENSION options:NSCaseInsensitiveSearch]) {
			[notebookDocuments addObject:path];
		} else {
			[folders addObject:path];
		}
	}
	[self.bookmarksViewController addBookmarkEntriesForPaths:folders];
	if ([notebookDocuments count]) {
		[self.notebookController promptForImportOfNotebookDocuments:notebookDocuments];
	}
	[NSApp replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
}


#pragma mark - NSMenuDelegate protocol

- (void)menuNeedsUpdate:(NSMenu *)menu
{
    NSMenuItem *item = [menu itemWithTag:1];
    [item setTitle:NSLocalizedString(@"Close", nil)];
}

@end


