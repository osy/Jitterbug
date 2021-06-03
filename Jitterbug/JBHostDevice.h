//
// Copyright © 2021 osy. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import <Foundation/Foundation.h>
#import "JBApp.h"

typedef NS_ENUM(NSInteger, JBHostDeviceType) {
    JBHostDeviceTypeUnknown,
    JBHostDeviceTypeiPhone,
    JBHostDeviceTypeiPad
};

const NSInteger kJBHostImageNotMounted;

NS_ASSUME_NONNULL_BEGIN

@interface JBHostDevice : NSObject<NSSecureCoding>

@property (nonatomic) NSString *name;
@property (nonatomic, readonly) BOOL isUsbDevice;
@property (nonatomic, readonly) NSString *identifier;
@property (nonatomic, readonly) NSString *hostname;
@property (nonatomic, readonly) NSData *address;
@property (nonatomic) JBHostDeviceType hostDeviceType;
@property (nonatomic) BOOL discovered;
@property (nonatomic, nullable, readonly) NSString *udid;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithHostname:(NSString *)hostname address:(NSData *)address NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithUuid:(NSString *)uuid NS_DESIGNATED_INITIALIZER;

- (BOOL)startLockdownWithPairingUrl:(NSURL *)url error:(NSError **)error;
- (BOOL)startLockdownWithError:(NSError **)error;
- (void)stopLockdown;
- (void)updateAddress:(NSData *)address;

- (BOOL)updateDeviceInfoWithError:(NSError **)error;
- (nullable NSArray<JBApp *> *)installedAppsWithError:(NSError **)error;
- (BOOL)mountImageForUrl:(NSURL *)url signatureUrl:(NSURL *)signatureUrl error:(NSError **)error;
- (BOOL)launchApplication:(JBApp *)application error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
