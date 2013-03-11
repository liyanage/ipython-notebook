//
//  DragDestinationView.h
//  IPython Notebook
//
//  Created by Marc Liyanage on 2/27/13.
//  Copyright (c) 2013 Marc Liyanage. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class BookmarksViewController;

@interface DragDestinationView : NSView
@property (weak) IBOutlet BookmarksViewController *viewController;
@property (weak) IBOutlet NSScrollView *tableView;

@end
