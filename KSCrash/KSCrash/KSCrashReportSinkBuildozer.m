//
//  KSCrashReportSinkBuildozer.m
//  KSCrash
//
//  Created by Johan Kool on 10/12/2012.
//  Copyright (c) 2012 Egeniq. All rights reserved.
//

#import "KSCrashReportSinkBuildozer.h"

#import <UIKit/UIKit.h>

#import "ARCSafe_MemMgmt.h"
#import "KSCrashReportFields.h"
#import "KSCrashReportFilterJSON.h"
#import "KSCrashReportFilterGZip.h"
#import "NSData+Base64.h"

static inline NSError* makeNSError(NSString* domain, NSInteger code, NSString* fmt, ...)
{
    va_list args;
    va_start(args, fmt);

    NSString* desc = as_autorelease([[NSString alloc] initWithFormat:fmt
                                                           arguments:args]);
    va_end(args);

    return [NSError errorWithDomain:domain
                               code:code
                           userInfo:[NSDictionary dictionaryWithObject:desc
                                                                forKey:NSLocalizedDescriptionKey]];
}


@interface KSCrashBuildozerProcess : NSObject

@property(nonatomic,readwrite,retain) NSArray* reports;
@property(nonatomic,readwrite,copy) KSCrashReportFilterCompletion onCompletion;

+ (KSCrashBuildozerProcess*) process;

- (void) startWithReports:(NSArray*) reports
            onCompletion:(KSCrashReportFilterCompletion) onCompletion;

@end

@implementation KSCrashBuildozerProcess

@synthesize reports = _reports;
@synthesize onCompletion = _onCompletion;

+ (KSCrashBuildozerProcess*) process
{
    return as_autorelease([[self alloc] init]);
}

- (void) dealloc
{
    as_release(_reports);
    as_release(_onCompletion);
    as_superdealloc();
}

- (void) startWithReports:(NSArray*) reports
            onCompletion:(KSCrashReportFilterCompletion) onCompletion
{
    self.reports = reports;
    self.onCompletion = onCompletion;

    // Concatenate reports
    NSMutableData *crashData = [NSMutableData data];
    NSData *boundaryData = [@"--CRASH+LOG+BOUNDARY--" dataUsingEncoding:NSUTF8StringEncoding];
    for (NSData *report in self.reports) {
        [crashData appendData:report];
        [crashData appendData:boundaryData];
    }

    // Encode as base64
    NSString *crashDataString = [crashData ks_base64EncodedString];
    NSString *crashDataURLString = [NSString stringWithFormat:@"x-buildozer://crashreport/%@", crashDataString];
    NSURL *crashDataURL = [NSURL URLWithString:crashDataURLString];
    BOOL result = [[UIApplication sharedApplication] openURL:crashDataURL];

    if (!result) {
        UIAlertView *errorAlert = as_autorelease([[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Sending Failed", @"") message:NSLocalizedString(@"Could not send crash report.", @"") delegate:self cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil]);
        [errorAlert show];
        self.onCompletion(self.reports, NO, makeNSError([[self class] description],
                                                        0,
                                                        @"Could not send crash report"));
    } else {
        self.onCompletion(self.reports, YES, nil);
    }
}

@end


@interface KSCrashReportSinkBuildozer ()

@end


@implementation KSCrashReportSinkBuildozer

+ (KSCrashReportSinkBuildozer*) sink
{
    return as_autorelease([[self alloc] init]);
}

- (NSArray*) defaultCrashReportFilterSet
{
    return [NSArray arrayWithObjects:
            [KSCrashReportFilterJSONEncode filterWithOptions:KSJSONEncodeOptionSorted],
            [KSCrashReportFilterGZipCompress filterWithCompressionLevel:-1],
            self,
            nil];
}

- (void) filterReports:(NSArray*) reports
          onCompletion:(KSCrashReportFilterCompletion) onCompletion
{
    if(![[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"x-buildozer://"]])
    {
        // Buildozer is not installed
        UIAlertView *alertView = as_autorelease([[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Buildozer Not Found", @"")
                                                                           message:NSLocalizedString(@"Install the Buildozer app to send the crash log in.", @"")
                                                                          delegate:nil
                                                                 cancelButtonTitle:NSLocalizedString(@"OK", @"")
                                                                 otherButtonTitles:nil]);
        [alertView show];

        onCompletion(reports, NO, [NSError errorWithDomain:@"KSCrashReportSinkBuildozer"
                                                      code:0
                                                  userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                            @"Buildozer not installed on device",
                                                            NSLocalizedDescriptionKey,
                                                            nil]]);
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^
                   {
                       __block KSCrashBuildozerProcess* process = [[KSCrashBuildozerProcess alloc] init];
                       [process startWithReports:reports
                                    onCompletion:^(NSArray* filteredReports,
                                                   BOOL completed,
                                                   NSError* error)
                        {
                            onCompletion(filteredReports, completed, error);
                            dispatch_async(dispatch_get_main_queue(), ^
                                           {
                                               as_release(process);
                                               process = nil;
                                           });
                        }];
                   });
}

@end
