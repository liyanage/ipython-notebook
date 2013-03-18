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
    self.notebookController.pythonPathURLs = [self.pythonPathBookmarksViewController bookmarkURLs];
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[self.notebookController showWindow:nil];
}


- (IBAction)openPreferencesWindow:(id)sender
{
    BookmarksViewController *bvc = self.bookmarksViewController;
	if (![bvc.view superview]) {
		[self.bookmarksPlaceholderView addSubview:bvc.view];
	}
    
    bvc = self.pythonPathBookmarksViewController;
	if (![bvc.view superview]) {
		[self.pythonPathBookmarksPlaceholderView addSubview:bvc.view];
        bvc.labelText = NSLocalizedString(@"Add the following folders to the PYTHONPATH", nil);
        bvc.dragExplanationText = NSLocalizedString(@"Drag folders to this list. Changes require a restart.", nil);
	}
	[self.preferencesWindow makeKeyAndOrderFront:sender];
}


- (IBAction)openProjectWebsite:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[self projectInfoURL]];
}


- (NSURL *)projectInfoURL
{
    return [NSURL URLWithString:@"https://github.com/liyanage/ipython-notebook/wiki"];
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


