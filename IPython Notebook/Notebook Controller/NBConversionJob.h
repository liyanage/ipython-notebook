//
//  NBConversionJob.h
//  IPython Notebook
//
//  Created by Marc Liyanage on 12/8/13.
//  Copyright (c) 2013 Marc Liyanage. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, JobState) {
	JobStateUnknown,
	JobStateReady,
	JobStateRunning,
	JobStateCompletedWithSuccess,
	JobStateCompletedWithFailure
};

@interface NBConversionJob : NSObject
@property JobState state;
@property NSError *error;
+ (instancetype)conversionJobWithInputDocumentURL:(NSURL *)documentURL destinationURL:(NSURL *)destinationURL;
- (void)startWithCompletionHandler:(dispatch_block_t)completionHandler;
@end
