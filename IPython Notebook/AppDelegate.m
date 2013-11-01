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
@property BOOL didSetupCustomCss;
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

	[self setupCustomCss];

	[self.preferencesWindow makeKeyAndOrderFront:sender];

}


- (void)setupCustomCss
{
	if (self.didSetupCustomCss) {
		return;
	}

	NSURL *url = [self.notebookController customCssFileUrl];
	if (!url) {
		NSLog(@"Unable to get custom css file URL");
		return;
	}

	NSError *error = nil;
	NSString *customCss = [NSString stringWithContentsOfURL:url usedEncoding:NULL error:&error];
	if (!customCss) {
		NSLog(@"Unable to load custom CSS: %@", error);
	}
	self.customCss = customCss;
	self.didSetupCustomCss = YES;

	[self addObserver:self forKeyPath:@"customCss" options:0 context:nil];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	NSURL *url = [self.notebookController customCssFileUrl];
	if (!url) {
		NSLog(@"Custom CSS location not available, unable to save changes");
		return;
	}
	if (self.customCss) {
		NSError *error = nil;
		BOOL didWrite = [self.customCss writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:&error];
		if (!didWrite) {
			NSLog(@"Unable to write custom CSS: %@", error);
		}
	}
	[[NSURLCache sharedURLCache] removeAllCachedResponses];
}


- (IBAction)openProjectWebsite:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[self projectInfoURL]];
}


- (NSURL *)projectInfoURL
{
    return [NSURL URLWithString:@"https://github.com/liyanage/ipython-notebook/wiki"];
}


- (IBAction)resetCustomCss:(id)sender
{
	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = NSLocalizedString(@"Do you want to reset the custom CSS code?", nil);
	alert.informativeText = NSLocalizedString(@"You cannot undo this action.", nil);
	[alert addButtonWithTitle:@"Reset"];
	[alert addButtonWithTitle:@"Cancel"];
	[alert beginSheetModalForWindow:self.preferencesWindow completionHandler:^(NSModalResponse returnCode) {
		if (returnCode != NSAlertFirstButtonReturn) {
			return;
		}
		[self.preferencesWindow makeFirstResponder:nil];
		NSError *error = nil;
		NSString *defaultCssString = [NSString stringWithContentsOfURL:[self.notebookController defaultCustomCssFileUrl] usedEncoding:NULL error:&error];
		if (!defaultCssString) {
			NSLog(@"Unable to load default custom CSS: %@", error);
			return;
		}
		self.customCss = defaultCssString;
	}];
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


#pragma mark - NSWindowDelegate protocol

- (void)windowWillClose:(NSNotification *)notification
{
	// Commit changes to custom CSS text view
	[self.preferencesWindow makeFirstResponder:nil];
}


#pragma mark - NSUserInterfaceValidations protocol


- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem
{
	if ([anItem action] == @selector(openPreferencesWindow:)) {
		return self.notebookController.applicationState == ApplicationStateNotebookRunning;
	}
	return YES;
}

@end


