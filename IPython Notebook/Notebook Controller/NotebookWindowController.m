//
//	NotebookWindowController.m
//	IPython Notebook
//
//	Created by Marc Liyanage on 3/4/13.
//	Copyright (c) 2013 Marc Liyanage. All rights reserved.
//

#import "NotebookWindowController.h"

@interface NotebookWindowController ()
@property NSTask *task;
@property NSURL *documentDirectoryURL;
@property NSURL *notebookURL;
@property NSArray *deferredNotebookDocumentsToOpen;
@property NSUInteger notebookServerStartupCheckCount;
@property (weak) NSOpenPanel *currentOpenDocumentPanel;
@end


typedef void (^alertCompletionHandler)(NSInteger returnCode);

@implementation NotebookWindowController

- (void)windowDidLoad
{
	[super windowDidLoad];
	[self checkConfiguredDocumentsDirectory];
}



- (void)checkConfiguredDocumentsDirectory
{
	self.applicationState = ApplicationStateCheckingDocumentsDirectory;
	
	// for testing: zap preferences with defaults delete ch.entropy.ipython-notebook
	NSData *documentsBookmarkData = [[NSUserDefaults standardUserDefaults] dataForKey:@"DocumentsDirectoryBookmarkData"];
	BOOL isStale = NO;
	NSError *error = nil;
	NSURL *documentsURL = documentsBookmarkData ? [NSURL URLByResolvingBookmarkData:documentsBookmarkData
																			options:NSURLBookmarkResolutionWithSecurityScope
																	  relativeToURL:nil
																bookmarkDataIsStale:&isStale
																			  error:&error] : nil;
	
	
	if (isStale) {
		documentsURL = nil;
	}
	if (documentsURL) {
		[documentsURL startAccessingSecurityScopedResource];
		self.applicationState = ApplicationStateCheckingPersistedDocumentsDirectory;
	}
	
	[self checkDocumentsDirectoryAtURL:documentsURL];
}


- (void)checkDocumentsDirectoryAtURL:(NSURL *)documentsDirectoryURL
{
	if (documentsDirectoryURL) {
		if ([[NSFileManager defaultManager] isWritableFileAtPath:[documentsDirectoryURL path]]) {
			self.documentDirectoryURL = documentsDirectoryURL;
			if (self.applicationState != ApplicationStateCheckingPersistedDocumentsDirectory) {
				NSData *bookmarkData = [documentsDirectoryURL bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope includingResourceValuesForKeys:nil relativeToURL:nil error:nil];
				if (bookmarkData) {
					[[NSUserDefaults standardUserDefaults] setObject:bookmarkData forKey:@"DocumentsDirectoryBookmarkData"];
				}
				[self copyExampleNoteBookToDocmentsDirectory];
			}
			[self copyDefaultProfileToDocumentsDirectory];
			self.applicationState = ApplicationStateReady;
			[self.firstTimeView setHidden:YES];
			if (![self launchNotebookServerTask]) {
				self.applicationState = ApplicationStateTerminating;
				[NSApp terminate:self];
			}
			[self waitForNotebookServer];
			return;
		}
	}
	
	self.applicationState = ApplicationStateCheckingDocumentsDirectory;
	[self.firstTimeView setHidden:NO];
	
}


- (void)copyExampleNoteBookToDocmentsDirectory
{
	NSURL *exampleDocURL = [[NSBundle mainBundle] URLForResource:@"Welcome to IPython Notebook" withExtension:NOTEBOOK_PATH_EXTENSION];

	NSURL *destinationURL = [self.documentDirectoryURL URLByAppendingPathComponent:[exampleDocURL lastPathComponent]];
	NSFileManager *fm = [NSFileManager defaultManager];
	
	if ([fm fileExistsAtPath:[destinationURL path]]) {
		return;
	}
	
	NSError *error = nil;
	if (![fm copyItemAtURL:exampleDocURL toURL:destinationURL error:&error]) {
		NSLog(@"Unable to copy example document from %@ to %@: %@", exampleDocURL, destinationURL, error);
	}
}


- (NSURL *)customCssFileUrl
{
	return [self.documentDirectoryURL URLByAppendingPathComponent:@"profile_default/static/custom/custom.css"];
}


- (NSURL *)defaultCustomCssFileUrl
{
	NSURL *url = [[NSBundle mainBundle] URLForResource:@"profile_default" withExtension:nil];
	url = [url URLByAppendingPathComponent:@"static/custom/custom.css"];
	return url;
}


- (void)copyDefaultProfileToDocumentsDirectory
{
	NSURL *destinationURL = [self customCssFileUrl];
	NSFileManager *fm = [NSFileManager defaultManager];
	if ([fm fileExistsAtPath:[destinationURL path]]) {
		return;
	}

	NSURL *defaultProfileURL = [[NSBundle mainBundle] URLForResource:@"profile_default" withExtension:nil];
	NSArray *arguments = @[@"-a", [defaultProfileURL path], [self.documentDirectoryURL path]];
	NSTask *rsyncTask = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/rsync" arguments:arguments];
	[rsyncTask waitUntilExit];
	int status = [rsyncTask terminationStatus];
	if (status != 0) {
		NSLog(@"Unable to copy default profile, non-zero termination status %d", status);
	}
}


- (IBAction)newDocument:(id)sender
{
	dispatch_block_t newDocumentAction = ^{
		NSURLRequest *request = [NSURLRequest requestWithURL:[self.notebookURL URLByAppendingPathComponent:@"new"]];
		[[self.webView mainFrame] loadRequest:request];
	};

	if (![self currentPageIsNotebookWithUnsavedChanges]) {
		newDocumentAction();
		return;
	}

	alertCompletionHandler handler = ^(NSInteger returnCode) {
		if (returnCode == NSAlertThirdButtonReturn) {
			return;
		}
		
		if (returnCode == NSAlertFirstButtonReturn) {
			[self saveCurrentNotebook];
		}
		newDocumentAction();
	};
	[self promptForUnsavedChangesWithCompletionHandler:handler];
}


- (IBAction)openDocument:(id)sender
{
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	self.currentOpenDocumentPanel = openPanel;
	openPanel.canChooseDirectories = NO;
	openPanel.canChooseFiles = YES;
	openPanel.allowsMultipleSelection = YES;
	openPanel.allowedFileTypes = @[NOTEBOOK_PATH_EXTENSION];
	openPanel.message = NSLocalizedString(@"Choose IPython Notebook documents to import into the notebook documents folder.", nil);
	openPanel.canCreateDirectories = YES;
	openPanel.delegate = self;
	
	NSButton *copyCheckbox = [[NSButton alloc] initWithFrame:NSZeroRect];
	[copyCheckbox setButtonType:NSSwitchButton];
	[copyCheckbox setTitle:NSLocalizedString(@"Copy the documents instead of moving them", nil)];
	[copyCheckbox sizeToFit];
	[copyCheckbox setTarget:self];
	[copyCheckbox setAction:@selector(toggleOpenPanelCopyCheckbox:)];
	BOOL userDefaultsShouldCopy = [[NSUserDefaults standardUserDefaults] boolForKey:@"CopyOpenedDocuments"];
	[copyCheckbox setIntegerValue:userDefaultsShouldCopy];
	[self toggleOpenPanelCopyCheckbox:copyCheckbox]; // to update the initial prompt string

	openPanel.accessoryView = copyCheckbox;
	
	[openPanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
		if (result != NSFileHandlingPanelOKButton) {
			return;
		}
		NSArray *paths = [[openPanel URLs] valueForKey:@"path"];
		BOOL shouldCopy = [copyCheckbox integerValue];
		if (userDefaultsShouldCopy != shouldCopy) {
			[[NSUserDefaults standardUserDefaults] setBool:shouldCopy forKey:@"CopyOpenedDocuments"];
		}
		[self importNotebookDocuments:paths shouldMove:!shouldCopy];
	}];
}


- (void)toggleOpenPanelCopyCheckbox:(NSButton *)copyCheckbox
{
	NSString *prompt = [copyCheckbox integerValue] ? NSLocalizedString(@"Copy to Documents Folder", nil) : NSLocalizedString(@"Move to Documents Folder", nil);
	self.currentOpenDocumentPanel.prompt = prompt;
}


- (IBAction)chooseNotebooksFolder:(id)sender
{
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	openPanel.canChooseDirectories = YES;
	openPanel.canChooseFiles = NO;
	openPanel.allowsMultipleSelection = NO;
	openPanel.prompt = NSLocalizedString(@"Choose Notebook Folder", nil);
	openPanel.message = NSLocalizedString(@"Please choose a folder where iPython Notebook can store your documents.", nil);
	openPanel.canCreateDirectories = YES;
	
	[openPanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
		if (result != NSFileHandlingPanelOKButton) {
			return;
		}
		NSURL *url = [[openPanel URLs] lastObject];
		[self checkDocumentsDirectoryAtURL:url];
	}];
}


- (IBAction)openNotebooksFolder:(id)sender
{
	if (self.documentDirectoryURL) {
		[[NSWorkspace sharedWorkspace] openURL:self.documentDirectoryURL];
	}
}


- (BOOL)launchNotebookServerTask
{
	[self clearApplicationBundleLocationDependentCacheFiles];

	NSURL *virtualEnvPythonURL = [[NSBundle mainBundle] URLForResource:@"python" withExtension:nil subdirectory:@"virtualenv/bin"];
	NSURL *launchScriptURL = [[NSBundle mainBundle] URLForResource:@"launch-ipython" withExtension:@"py" subdirectory:@"virtualenv/bin"];
	NSAssert(launchScriptURL, NSLocalizedString(@"Unable to determine url to launch-ipython.py script in resources", nil));
	self.task = [[NSTask alloc] init];
	self.task.launchPath = [virtualEnvPythonURL path];
	self.task.arguments = @[[launchScriptURL path]];
	
	NSMutableDictionary *environment = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];
	NSInteger port = [self findAvailablePort];
	if (!port) {
		self.applicationState = ApplicationStateTerminating;
		NSAlert *alert = [self fatalErrorAlert];
		alert.messageText = NSLocalizedString(@"Unable to launch iPython Notebook", nil);
		alert.informativeText = NSLocalizedString(@"Unable to find free port", nil);
		[alert beginSheetModalForWindow:self.window modalDelegate:self didEndSelector:@selector(fatalErrorAlertDidEnd:returnCode:contextInfo:) contextInfo:NULL];
		return NO;
	}
	NSNumber *portNumber = [NSNumber numberWithInteger:port];
	environment[@"IPYTHON_NOTEBOOK_APP_PORT"] = [portNumber stringValue];
	environment[@"IPYTHON_NOTEBOOK_APP_IPYTHON_DIR"] = [self.documentDirectoryURL path];
	environment[@"PYTHONDONTWRITEBYTECODE"] = @"1";

	NSString *pythonPath = [self customPythonPath];
	if (pythonPath) {
		environment[@"IPYTHON_NOTEBOOK_APP_EXTRA_PYTHONPATH"] = pythonPath;
	}
	
	self.task.environment = environment;

	self.applicationState = ApplicationStateWaitingForNotebookStartup;
	self.operationInProgress = YES;
	[self.task launch];
	
	self.notebookURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%@", portNumber]];
	return YES;
}


- (void)clearApplicationBundleLocationDependentCacheFiles
{
	NSURL *homeDirectoryUrl = [NSURL fileURLWithPath:NSHomeDirectory()];
	NSURL *matplotlibFontListCacheUrl = [homeDirectoryUrl URLByAppendingPathComponent:@".matplotlib/fontList.cache"];

	NSFileManager *fm = [NSFileManager defaultManager];
	if ([fm fileExistsAtPath:[matplotlibFontListCacheUrl path]]) {
		NSLog(@"Removing cache file %@", [matplotlibFontListCacheUrl path]);
		NSError *error = nil;
		if (![fm removeItemAtURL:matplotlibFontListCacheUrl error:&error]) {
			NSLog(@"Unable to remove cache file: %@", error);
		}
	}
}


- (NSString *)customPythonPath
{
	if (![self.pythonPathURLs count]) {
		return nil;
	}
	NSMutableArray *paths = [NSMutableArray array];
	for (NSURL *url in self.pythonPathURLs) {
		[paths addObject:[url path]];
	}
	return [paths componentsJoinedByString:@":"];
}



- (void)waitForNotebookServer
{
	NSURLRequest *request = [NSURLRequest requestWithURL:self.notebookURL];
	double delayInSeconds = 0.5;
	dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
	dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
		if (self.applicationState != ApplicationStateWaitingForNotebookStartup) {
			return;
		}
		self.notebookServerStartupCheckCount++;
		if (self.notebookServerStartupCheckCount > 30) {
			NSAlert *alert = [self fatalErrorAlert];
			self.applicationState = ApplicationStateTerminating;
			alert.messageText = NSLocalizedString(@"Unable to launch iPython Notebook", nil);
			alert.informativeText = NSLocalizedString(@"Server failed to start up", nil);
			[alert beginSheetModalForWindow:self.window modalDelegate:self didEndSelector:@selector(fatalErrorAlertDidEnd:returnCode:contextInfo:) contextInfo:NULL];
			return;
		}
		
		[NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
//			NSLog(@"Notebook server startup test request completion: %lu %ld", self.notebookServerStartupCheckCount, ((NSHTTPURLResponse *)response).statusCode);
			if (self.applicationState == ApplicationStateTerminating) {
				return;
			}
			if (response) {
				self.applicationState = ApplicationStateNotebookRunning;
				self.operationInProgress = NO;
				[self initializeWebView];
				[self importDeferredNotebookDocuments];
				return;
			}
			if (self.applicationState == ApplicationStateWaitingForNotebookStartup) {
				[self waitForNotebookServer];
			}
		}];
	});
}


- (NSAlert *)fatalErrorAlert
{
	NSAlert *alert = [[NSAlert alloc] init];
	[alert addButtonWithTitle:NSLocalizedString(@"Quit", nil)];
	return alert;
}


- (void)fatalErrorAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[NSApp terminate:self];
}


- (void)initializeWebView
{
	NSURLRequest *request = [NSURLRequest requestWithURL:[self launchURL]];
	[[self.webView mainFrame] loadRequest:request];
}


- (NSURL *)launchURL
{
	NSString *launchNotebookIdentifier = [self launchNotebookIdentifier];
	if (!launchNotebookIdentifier) {
		return self.notebookURL;
	}

	NSURLComponents *components = [NSURLComponents componentsWithURL:self.notebookURL resolvingAgainstBaseURL:NO];
	components.path = [NSString stringWithFormat:@"/%@", launchNotebookIdentifier];

	return [components URL];
}


- (NSString *)launchNotebookIdentifier
{
	NSString *lastOpenNotebookName = [[NSUserDefaults standardUserDefaults] stringForKey:@"CurrentNotebookName"];
	if (!lastOpenNotebookName) {
		return nil;
	}

	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"CurrentNotebookName"];

	__block NSString *notebookIdentifier = nil;
	[[self notebookInfo] enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *notebookInfo, BOOL *stop) {
		if ([notebookInfo[@"name"] isEqualToString:lastOpenNotebookName]) {
			*stop = YES;
			notebookIdentifier = key;
		}
	}];

	return notebookIdentifier;
}


- (NSInteger)findAvailablePort
{
	
	for (unsigned short port = 7777; port < 9000; port++) {
		NSSocketPort *socket = [[NSSocketPort alloc] initWithTCPPort:port];
		if (socket) {
			[socket invalidate];
			return port;
		}
	}
	return 0;
}


- (NSArray *)unimportedNotebookDocumentsFromArray:(NSArray *)notebookDocumentPaths
{
	NSMutableArray *result = [NSMutableArray array];
	NSAssert(self.documentDirectoryURL, @"documentDirectoryURL must be set");
	for (NSString *path in notebookDocumentPaths) {
		NSURL *url = [[NSURL fileURLWithPath:path] URLByDeletingLastPathComponent];
		if (![[url path] isEqualToString:[self.documentDirectoryURL path]]) {
			[result addObject:path];
		}
	}
	return result;
}


- (void)promptForImportOfNotebookDocuments:(NSArray *)notebookDocumentPaths
{
	if (self.applicationState != ApplicationStateNotebookRunning) {
		self.deferredNotebookDocumentsToOpen = notebookDocumentPaths;
		return;
	}
	
	notebookDocumentPaths = [self unimportedNotebookDocumentsFromArray:notebookDocumentPaths];

	if (![notebookDocumentPaths count]) {
		return;
	}

	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = NSLocalizedString(@"Would you like to copy or move these files into your notebook documents folder?", nil);
	NSString *introString = NSLocalizedString(@"IPython Notebook needs to copy or move these files into your “%@” folder to use them.", nil);
	introString = [NSString stringWithFormat:introString, [self.documentDirectoryURL lastPathComponent]];
	NSArray *filenames = [notebookDocumentPaths valueForKey:@"lastPathComponent"];
	introString = [introString stringByAppendingFormat:@"\n\n%@", [filenames componentsJoinedByString:@"\n"]];
	alert.informativeText = introString;
	[alert addButtonWithTitle:NSLocalizedString(@"Move", nil)];
	[alert addButtonWithTitle:NSLocalizedString(@"Copy", nil)];
	[alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
	[alert beginSheetModalForWindow:self.window modalDelegate:self didEndSelector:@selector(importAlertDidEnd:returnCode:contextInfo:) contextInfo:(void *)CFBridgingRetain(notebookDocumentPaths)];
}


- (void)importAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	NSArray *paths = CFBridgingRelease(contextInfo);
	if (returnCode == NSAlertThirdButtonReturn) {
		return;
	}
	BOOL shouldMove = returnCode == NSAlertFirstButtonReturn;
	[self importNotebookDocuments:paths shouldMove:shouldMove];
}


- (void)importNotebookDocuments:(NSArray *)notebookDocumentPaths shouldMove:(BOOL)shouldMove
{
	NSFileManager *fm = [NSFileManager defaultManager];
	for (NSString *path in notebookDocumentPaths) {
		NSURL *sourceURL = [NSURL fileURLWithPath:path];
		NSURL *destinationURL = [self uniqueDocumentURLForSourceURL:[NSURL fileURLWithPath:path]];
		if (!destinationURL) {
			continue;
		}

		NSError *error;
		BOOL fileSystemOperationResult = NO;
		if (shouldMove) {
			fileSystemOperationResult = [fm moveItemAtURL:sourceURL toURL:destinationURL error:&error];
		} else {
			fileSystemOperationResult = [fm copyItemAtURL:sourceURL toURL:destinationURL error:&error];
		}

		if (!fileSystemOperationResult) {
			NSAlert *alert = [NSAlert alertWithError:error];
			[alert runModal];
		}
	}
	[self updateNotebookList];
}


- (NSURL *)uniqueDocumentURLForSourceURL:(NSURL *)sourceURL
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *filename = [sourceURL lastPathComponent];
	NSString *extension = [filename pathExtension];
	NSString *filenameWithoutExtension = [filename stringByDeletingPathExtension];
	
	NSURL *destinationURL = [self.documentDirectoryURL URLByAppendingPathComponent:filename];
	
	NSUInteger counter = 0;
	while ([fm fileExistsAtPath:[destinationURL path]]) {
		counter++;
		NSString *counterString = [NSNumberFormatter localizedStringFromNumber:@(counter) numberStyle:NSNumberFormatterDecimalStyle];
		filename = [[NSString stringWithFormat:@"%@ %@", filenameWithoutExtension, counterString] stringByAppendingPathExtension:extension];
		destinationURL = [self.documentDirectoryURL URLByAppendingPathComponent:filename];
	}
	
	return destinationURL;
}


- (void)importDeferredNotebookDocuments
{
	if (self.deferredNotebookDocumentsToOpen) {
		[self promptForImportOfNotebookDocuments:self.deferredNotebookDocumentsToOpen];
		self.deferredNotebookDocumentsToOpen = nil;
	}
}


- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem
{
	if ([anItem action] == @selector(runCurrentCellInPlace:)) {
		return [self currentPageIsNotebook];
	}
	if ([anItem action] == @selector(openNotebooksFolder:)) {
		return self.documentDirectoryURL != nil;
	}
	if ([anItem action] == @selector(openDocument:)) {
		return self.documentDirectoryURL != nil;
	}
	if ([anItem action] == @selector(newDocument:)) {
		return self.documentDirectoryURL != nil;
	}
	if ([anItem action] == @selector(performClose:)) {
		NSMenuItem *item = (NSMenuItem *)anItem;
		if ([self currentPageIsNotebook]) {
			[item setTitle:NSLocalizedString(@"Close Notebook", nil)];
		} else {
			[item setTitle:NSLocalizedString(@"Close Window", nil)];
		}
		return YES;
	}
	return YES;
}


- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	NSString *name = [self currentNotebookName];
	if (name) {
		[[NSUserDefaults standardUserDefaults] setObject:name forKey:@"CurrentNotebookName"];
	}
	self.applicationState = ApplicationStateTerminating;
	if ([self.task isRunning]) {
		[self.task terminate];
	}
	self.task = nil;
}


- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
	if (self.applicationState != ApplicationStateNotebookRunning) {
		return NSTerminateNow;
	}

	if (![self currentPageIsNotebookWithUnsavedChanges]) {
		return NSTerminateNow;
	}
	
	alertCompletionHandler handler = ^(NSInteger returnCode) {
		if (returnCode == NSAlertThirdButtonReturn) {
			[NSApp replyToApplicationShouldTerminate:NO];
			return;
		}

		if (returnCode == NSAlertFirstButtonReturn) {
			[self saveCurrentNotebook];
		}
		[NSApp replyToApplicationShouldTerminate:YES];
	};
	[self promptForUnsavedChangesWithCompletionHandler:handler];

	return NSTerminateLater;
}


- (void)promptForUnsavedChangesWithCompletionHandler:(alertCompletionHandler)completionHandler
{
	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = NSLocalizedString(@"You have unsaved notebook documents. Do you want to save your changes?", nil);
	[alert addButtonWithTitle:NSLocalizedString(@"Save", nil)];
	[alert addButtonWithTitle:NSLocalizedString(@"Discard Changes", nil)];
	[alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
	[alert beginSheetModalForWindow:self.window modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:(void *)CFBridgingRetain(completionHandler)];
}


- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	alertCompletionHandler completionHandler = CFBridgingRelease(contextInfo);
	completionHandler(returnCode);
}


- (IBAction)runCurrentCellInPlace:(id)sender
{
	[self evaluateWebScript:@"IPython.notebook.execute_selected_cell({terminal:true});"];
}


#pragma mark - JavaScript interaction

- (void)updateNotebookList
{
	[self evaluateWebScript:@"IPython.notebook_list.load_list();"];
}


- (id)evaluateWebScript:(NSString *)script
{
	return [[self webScriptObject] evaluateWebScript:script];
}


- (WebScriptObject *)webScriptObject
{
	return [self.webView.mainFrame windowObject];
}


- (BOOL)currentPageIsNotebook
{
	return [self currentNotebookIdentifier] != nil;
}


- (NSString *)currentNotebookIdentifier
{
	NSString *currentURLPath = [[[[[self.webView mainFrame] dataSource] request] URL] path];
	if ([currentURLPath length] < 37) {
		return nil;
	}
	
	NSRange uuidRange = [currentURLPath rangeOfString:@"/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$" options:NSRegularExpressionSearch|NSCaseInsensitiveSearch|NSAnchoredSearch];
	return uuidRange.location != NSNotFound ? [currentURLPath substringFromIndex:1] : nil;
}


- (NSDictionary *)notebookInfo
{
	NSURL *infoURL = [self.notebookURL URLByAppendingPathComponent:@"notebooks"];
	if (!infoURL) {
		return nil;
	}
	NSData *data = [NSData dataWithContentsOfURL:infoURL];
	if (!data) {
		return nil;
	}
	NSArray *notebookList = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
	if (!notebookList) {
		return nil;
	}
	
	NSMutableDictionary *info = [NSMutableDictionary dictionary];
	for (NSDictionary *notebookInfo in notebookList) {
		NSString *identifier = notebookInfo[@"notebook_id"];
		if (!identifier) {
			continue;
		}
		info[identifier] = notebookInfo;
	}
	return info;
}


- (NSString *)currentNotebookName
{
	NSString *identifier = [self currentNotebookIdentifier];
	if (!identifier) {
		return nil;
	}
	
	NSString *name = [self notebookInfo][identifier][@"name"];
	return name;
}


- (NSURL *)currentNotebookFileURL
{
	if (![self currentPageIsNotebook]) {
		return nil;
	}
	NSString *filename = [self currentNotebookName];
	filename = [filename stringByAppendingPathExtension:NOTEBOOK_PATH_EXTENSION];
	NSURL *notebookURL = [self.documentDirectoryURL URLByAppendingPathComponent:filename];
	notebookURL = [NSURL fileURLWithPath:[notebookURL path]];
	return notebookURL;
}


- (BOOL)currentPageIsNotebookWithUnsavedChanges
{
	if (![self currentPageIsNotebook]) {
		return NO;
	}
	id value = [self evaluateWebScript:@"IPython.notebook.dirty"];
	return [value respondsToSelector:@selector(boolValue)] && [value boolValue];
}


- (void)closeCurrentNotebook
{
	if (![self currentPageIsNotebook]) {
		return;
	}

	NSURLRequest *request = [NSURLRequest requestWithURL:self.notebookURL];
	[[self.webView mainFrame] loadRequest:request];
}


- (void)saveCurrentNotebook
{
	if (![self currentPageIsNotebook]) {
		return;
	}
	[self evaluateWebScript:@"IPython.notebook.save_notebook()"];

	for (int i = 1; i < 10; i++) {
		if (![self currentPageIsNotebookWithUnsavedChanges]) {
			break;
		}
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeInterval:i * 0.1 sinceDate:[NSDate date]]];
	}
}


- (BOOL)isNotebookServerURL:(NSURL *)url
{
	NSURL *notebookURL = self.notebookURL;
	
	if ([url port] != [notebookURL port]) {
		return NO;
	}

	if (![[url host] isEqualToString:[notebookURL host]]) {
		return NO;
	}

	return YES;
}


- (BOOL)URL:(NSURL *)url1 ignoringFragmentIsEqualToURL:(NSURL *)url2
{
	for (NSString *property in @[@"scheme", @"host", @"port", @"path", @"query"]) {
		id value1 = [url1 valueForKey:property];
		id value2 = [url2 valueForKey:property];
		if (!value1 && !value2) {
			continue;
		}
		if (![value1 isEqual:value2]) {
			return NO;
		}
	}
	
	return YES;
}

#pragma mark - NSWindowDelegate protocol

- (BOOL)windowShouldClose:(id)sender
{
	if (self.applicationState != ApplicationStateNotebookRunning) {
		return YES;
	}
	
	if ([self currentPageIsNotebookWithUnsavedChanges]) {
		alertCompletionHandler handler = ^(NSInteger returnCode) {
			if (returnCode == NSAlertThirdButtonReturn) {
				return;
			}
			
			if (returnCode == NSAlertFirstButtonReturn) {
				[self saveCurrentNotebook];
			}
			
			self.applicationState = ApplicationStateTerminating;
			[NSApp terminate:self];
		};
		[self promptForUnsavedChangesWithCompletionHandler:handler];
		return NO;
	}

	return YES;
}


- (BOOL)window:(NSWindow *)window shouldPopUpDocumentPathMenu:(NSMenu *)menu
{
	return self.applicationState == ApplicationStateNotebookRunning;
}


- (void)performClose:(id)sender
{
	if ([self currentPageIsNotebookWithUnsavedChanges]) {
		alertCompletionHandler handler = ^(NSInteger returnCode) {
			if (returnCode == NSAlertThirdButtonReturn) {
				return;
			}
			
			if (returnCode == NSAlertFirstButtonReturn) {
				[self saveCurrentNotebook];
			}
			
			[self closeCurrentNotebook];
			
		};
		[self promptForUnsavedChangesWithCompletionHandler:handler];
		return;
	}
	
	if ([self currentPageIsNotebook]) {
		[self closeCurrentNotebook];
		return;
	}

	[self.window performClose:sender];
}


- (void)windowWillClose:(NSNotification *)notification
{
	[NSApp terminate:self];
}



#pragma mark - WebUIDelegate informal protocol implementation

- (WebView *)webView:(WebView *)sender createWebViewWithRequest:(NSURLRequest *)request
{
	[[sender mainFrame] loadRequest:request];
	return sender;
}


- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems
{
	NSMutableArray *allowedItems = [NSMutableArray array];
	
	for (NSMenuItem *item in defaultMenuItems) {
		switch ([item tag]) {
			case WebMenuItemTagCopy:
			case WebMenuItemTagPaste:
				[allowedItems addObject:item];
				break;
				
			default:
				break;
		}
	}
	
	return allowedItems;
}


#pragma mark - WebFrameLoadDelegate protocol

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
	[self updateWindowTitle];
	if (![self currentPageIsNotebook]) {
		return;
	}

	// Disable some menu items that are undesirable in the context of an app or are redundant with the app's menus
	[self evaluateWebScript:@"$('#new_notebook').parent().children('li').filter(function () {return $.inArray(this.id, ['copy_notebook', 'rename_notebook', 'save_checkpoint']) == -1}).hide();"];
}


- (void)webView:(WebView *)sender didReceiveTitle:(NSString *)title forFrame:(WebFrame *)frame
{
	// Handle renames by the user
	[self updateWindowTitle];
}


- (void)updateWindowTitle
{
	if (![self currentPageIsNotebook]) {
		[self.window setRepresentedURL:self.documentDirectoryURL];
		[self.window setTitleWithRepresentedFilename:[self.documentDirectoryURL path]];
		return;
	}
	[self.window setRepresentedURL:[self currentNotebookFileURL]];
	[self.window setTitleWithRepresentedFilename:[[self currentNotebookFileURL] path]];
}


#pragma mark - WebPolicyDelegate informal protocol implementation

- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id <WebPolicyDecisionListener>)listener
{
	NSURL *newURL = [request URL];

	if (![self isNotebookServerURL:newURL]) {
		[[NSWorkspace sharedWorkspace] openURL:newURL];
		[listener ignore];
		return;
	}
	
	NSURL *currentURL = [[[[webView mainFrame] dataSource] request] URL];
	BOOL fragmentChangeOnly = [self URL:currentURL ignoringFragmentIsEqualToURL:newURL];
	
	WebNavigationType type = [actionInformation[WebActionNavigationTypeKey] intValue];
	if (fragmentChangeOnly || type == WebNavigationTypeOther || ![self currentPageIsNotebookWithUnsavedChanges]) {
		[listener use];
		return;
	}

	[listener ignore];

	alertCompletionHandler handler = ^(NSInteger returnCode) {
		if (returnCode == NSAlertThirdButtonReturn) {
			return;
		}
		if (returnCode == NSAlertFirstButtonReturn) {
			[self saveCurrentNotebook];
		}
		[frame loadRequest:request];
	};
	[self promptForUnsavedChangesWithCompletionHandler:handler];
}


#pragma mark - NSOpenSavePanelDelegate

- (BOOL)panel:(id)sender shouldEnableURL:(NSURL *)url
{
	return [[[[url path] pathExtension] lowercaseString] isEqualToString:NOTEBOOK_PATH_EXTENSION];
}

@end
