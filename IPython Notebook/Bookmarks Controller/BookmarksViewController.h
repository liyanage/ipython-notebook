//
//  BookmarksViewController.h
//  IPython Notebook
//
//  Created by Marc Liyanage on 2/22/13.
//  Copyright (c) 2013 Marc Liyanage. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface BookmarksViewController : NSViewController

@property (weak) IBOutlet NSArrayController *bookmarksArrayController;
@property (weak) IBOutlet NSTableView *bookmarksTableView;
@property (strong) NSString *userDefaultsContentKey;
@property (copy) NSString *labelText;
@property (copy) NSString *dragExplanationText;

- (IBAction)addBookmark:(id)sender;
- (IBAction)removeBookmark:(id)sender;
- (IBAction)doubleClickInTableView:(NSTableView *)sender;

- (BOOL)addBookmarkEntriesForPaths:(NSArray *)paths;
- (BOOL)addBookmarkEntriesForURLs:(NSArray *)urls;

- (NSArray *)bookmarkURLs;

@end
