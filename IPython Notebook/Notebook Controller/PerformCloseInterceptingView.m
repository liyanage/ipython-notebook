//
//  PerformCloseInterceptingView.m
//  IPython Notebook
//
//  Created by Marc Liyanage on 3/7/13.
//  Copyright (c) 2013 Marc Liyanage. All rights reserved.
//

#import "PerformCloseInterceptingView.h"

@implementation PerformCloseInterceptingView

- (void)performClose:(id)sender
{
    // Forward straight to the window controller
    [(NSResponder *)[[self window] delegate] tryToPerform:_cmd with:sender];
}

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem
{
    return [(id <NSUserInterfaceValidations>)[[self window] delegate] validateUserInterfaceItem:anItem];
}

@end
