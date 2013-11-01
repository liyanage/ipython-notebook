//
//  AppDelegate.h
//  IPython Notebook
//
//  Created by Marc Liyanage on 2/5/13.
//  Copyright (c) 2013 Marc Liyanage. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class BookmarksViewController;

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property (weak) IBOutlet NSWindow *preferencesWindow;

@property (strong) IBOutlet BookmarksViewController *bookmarksViewController;
@property (weak) IBOutlet NSView *bookmarksPlaceholderView;

@property (strong) IBOutlet BookmarksViewController *pythonPathBookmarksViewController;
@property (weak) IBOutlet NSView *pythonPathBookmarksPlaceholderView;

@property (strong) NSString *customCss;

- (IBAction)resetCustomCss:(id)sender;

@end
