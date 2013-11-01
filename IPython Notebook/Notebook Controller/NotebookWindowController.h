//
//  NotebookWindowController.h
//  IPython Notebook
//
//  Created by Marc Liyanage on 3/4/13.
//  Copyright (c) 2013 Marc Liyanage. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

#define NOTEBOOK_PATH_EXTENSION @"ipynb"

typedef NS_ENUM(NSUInteger, ApplicationState) {
	ApplicationStateUnknown = 0,
	ApplicationStateCheckingPersistedDocumentsDirectory,
	ApplicationStateCheckingDocumentsDirectory,
	ApplicationStateReady,
	ApplicationStateTerminating,
	ApplicationStateWaitingForNotebookStartup,
	ApplicationStateNotebookRunning,
};

@interface NotebookWindowController : NSWindowController <NSOpenSavePanelDelegate>

@property (assign) ApplicationState applicationState;
@property (weak) IBOutlet NSView *firstTimeView;
@property (weak) IBOutlet WebView *webView;
@property (retain) NSArray *pythonPathURLs;
@property (assign) BOOL operationInProgress;

- (void)promptForImportOfNotebookDocuments:(NSArray *)notebookDocumentPaths;
- (void)applicationWillTerminate:(NSNotification *)aNotification;
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender;
- (NSURL *)customCssFileUrl;
- (NSURL *)defaultCustomCssFileUrl;

@end
