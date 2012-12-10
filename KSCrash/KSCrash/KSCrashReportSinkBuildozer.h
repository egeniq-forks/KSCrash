//
//  KSCrashReportSinkBuildozer.h
//  KSCrash
//
//  Created by Johan Kool on 10/12/2012.
//  Copyright (c) 2012 Egeniq. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "KSCrashReportFilter.h"

@interface KSCrashReportSinkBuildozer : NSObject <KSCrashReportFilter, KSCrashReportDefaultFilterSet>

/** Constructor.
 *
 */
+ (KSCrashReportSinkBuildozer*) sink;

@end
