//
//  DragDestinationView.m
//  IPython Notebook
//
//  Created by Marc Liyanage on 2/27/13.
//  Copyright (c) 2013 Marc Liyanage. All rights reserved.
//

#import "DragDestinationView.h"
#import "BookmarksViewController.h"
#import <QuartzCore/QuartzCore.h>

@implementation DragDestinationView

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender
{
	[self beginHighlight];
	return NSDragOperationLink;
}

- (void)draggingExited:(id<NSDraggingInfo>)sender
{
	[self endHighlight];
}

- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender
{
	return [[self urlsFromDraggingInfo:sender] count] > 0;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
	[self endHighlight];
	NSArray *urls = [self urlsFromDraggingInfo:sender];
	return [self.viewController addBookmarkEntriesForURLs:urls];
}

- (void)beginHighlight
{
	[NSAnimationContext beginGrouping];
	[NSAnimationContext currentContext].allowsImplicitAnimation = YES;
	[NSAnimationContext currentContext].duration = 0.2;
	self.tableView.layer.borderWidth = 2.5;
	self.tableView.layer.borderColor = [[NSColor selectedControlColor] CGColor];
	[NSAnimationContext endGrouping];
}

- (void)endHighlight
{
	[NSAnimationContext beginGrouping];
	[NSAnimationContext currentContext].allowsImplicitAnimation = YES;
	[NSAnimationContext currentContext].duration = 0.2;
	self.tableView.layer.borderWidth = 0.0;
	[NSAnimationContext endGrouping];
}

- (NSArray *)urlsFromDraggingInfo:(id<NSDraggingInfo>)sender
{
	NSMutableArray *urls = [NSMutableArray array];
	for (id item in [[sender draggingPasteboard] pasteboardItems]) {
        NSString *urlString = [[NSString alloc] initWithData:[item dataForType:@"public.file-url"] encoding:NSUTF8StringEncoding];
        if (urlString) {
            NSURL *url = [NSURL URLWithString:urlString];
            if (url) {
                [urls addObject:url];
            }
        }
	}
	return urls;
}


- (void)viewDidMoveToSuperview
{
	NSDictionary *views = NSDictionaryOfVariableBindings(self);
	NSMutableArray *constraints = [NSMutableArray array];
	[constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[self]|" options:0 metrics:nil views:views]];
	[constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[self]|" options:0 metrics:nil views:views]];
	[[self superview] addConstraints:constraints];
}

@end
