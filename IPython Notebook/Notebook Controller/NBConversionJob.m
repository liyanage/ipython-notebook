//
//  NBConversionJob.m
//  IPython Notebook
//
//  Created by Marc Liyanage on 12/8/13.
//  Copyright (c) 2013 Marc Liyanage. All rights reserved.
//

#import "NBConversionJob.h"

@interface NBConversionJob ()
@property NSTask *conversionTask;
@property NSURL *documentURL;
@property NSURL *destinationURL;
@property (strong) dispatch_block_t completionHandler;
@end


@implementation NBConversionJob

- (id)initWithDocumentURL:(NSURL *)documentURL destinationURL:(NSURL *)destinationURL
{
	NSParameterAssert(documentURL);
	NSParameterAssert(destinationURL);
    self = [super init];
    if (self) {
        self.documentURL = documentURL;
		self.destinationURL = destinationURL;
		self.state = JobStateReady;
    }
    return self;
}


+ (instancetype)conversionJobWithInputDocumentURL:(NSURL *)documentURL destinationURL:(NSURL *)destinationURL
{
	return [[NBConversionJob alloc] initWithDocumentURL:documentURL destinationURL:destinationURL];
}


- (void)startWithCompletionHandler:(dispatch_block_t)completionHandler
{
	NSParameterAssert(completionHandler);
	self.completionHandler = completionHandler;
	NSAssert(self.state == JobStateReady, @"Job must be in ready state to be started");
	self.state = JobStateRunning;

	self.conversionTask = [self configuredTask];
	if (!self.conversionTask) {
		self.state = JobStateCompletedWithFailure;
		completionHandler();
		return;
	}
	@try {
		[self.conversionTask launch];
	}
	@catch (NSException *exception) {
		self.state = JobStateCompletedWithFailure;
		self.error = [self errorWithCode:4 failureReason:exception.reason error:nil];
		completionHandler();
	}
}


- (NSError *)errorWithCode:(NSInteger *)code failureReason:(NSString *)failureReason error:(NSError *)underlyingError
{
	NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObjectsAndKeys:
								 @"Failed to export notebook document", NSLocalizedDescriptionKey,
								 nil];
	if (!failureReason && underlyingError) {
		failureReason = [underlyingError localizedDescription];
	}

	if (failureReason) {
		info[NSLocalizedRecoverySuggestionErrorKey] = failureReason;
	}

	if (underlyingError) {
		info[NSUnderlyingErrorKey] = underlyingError;
	}

	return [NSError errorWithDomain:@"NBConversionErrorDomain" code:code userInfo:info];
}


- (NSTask *)configuredTask
{
	NSTask *task = [[NSTask alloc] init];

	__weak NBConversionJob *weakSelf = self;
	task.terminationHandler = ^(NSTask *task) {
		NSLog(@"task termination");
		NBConversionJob *strongSelf = weakSelf;
		dispatch_async(dispatch_get_main_queue(), ^{
			[strongSelf taskDidTerminate];
		});
	};

	NSFileManager *fm = [NSFileManager defaultManager];

	NSURL *virtualEnvPythonURL = [[NSBundle mainBundle] URLForResource:@"python" withExtension:nil subdirectory:@"virtualenv/bin"];
	NSURL *launchScriptURL = [[NSBundle mainBundle] URLForResource:@"launch-ipython-nbconvert" withExtension:@"py" subdirectory:@"virtualenv/bin"];
	NSAssert(launchScriptURL, NSLocalizedString(@"Unable to determine url to launch-ipython-nbconvert script in resources", nil));
	NSAssert([fm fileExistsAtPath:[launchScriptURL path]], @"Launch path doesn't exist at %@", [launchScriptURL path]);

	task.launchPath = [virtualEnvPythonURL path];
	task.arguments = @[[launchScriptURL path], [self.documentURL path]];

	NSMutableDictionary *environment = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];
	environment[@"PYTHONDONTWRITEBYTECODE"] = @"1";
	task.environment = environment;

	NSError *error = nil;

	NSString *path = [self.destinationURL path];
	if ([fm fileExistsAtPath:path]) {
		if (![fm isWritableFileAtPath:path]) {
			self.error = [self errorWithCode:7 failureReason:@"Unable to write to destination file" error:nil];
			return nil;
		}
	} else {
		[fm createFileAtPath:path contents:[NSData data] attributes:@{}];
	}

	NSFileHandle *outputFileHandle = [NSFileHandle fileHandleForWritingToURL:self.destinationURL error:&error];
	if (!outputFileHandle) {
		self.error = [self errorWithCode:6 failureReason:nil error:error];
		return nil;
	}
	task.standardOutput = outputFileHandle;

	NSPipe *errorPipe = [NSPipe pipe];
	task.standardError = errorPipe;

	return task;
}


- (void)taskDidTerminate
{
	NSAssert(self.state == JobStateRunning, @"Job must be in running state");
	self.conversionTask.terminationHandler = nil;
	NSData *standardErrorData = [[[self.conversionTask standardError] fileHandleForReading] readDataToEndOfFile];
	NSString *standardErrorString = [[NSString alloc] initWithData:standardErrorData encoding:NSUTF8StringEncoding];

	if ([self.conversionTask terminationStatus]) {
		self.state = JobStateCompletedWithFailure;
		self.error = [self errorWithCode:1 failureReason:standardErrorString error:nil];
	} else {
		self.state = JobStateCompletedWithSuccess;
	}

	self.completionHandler();
	self.completionHandler = nil;
}

@end
