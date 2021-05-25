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

NS_ASSUME_NONNULL_BEGIN

@interface JBHostDevice : NSObject<NSSecureCoding>

@property (nonatomic) NSString *name;
@property (nonatomic, readonly) NSString *ipAddress;
@property (nonatomic) JBHostDeviceType hostDeviceType;
@property (nonatomic) NSString *hostVersion;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithIpaddress:(NSString *)ipAddress NS_DESIGNATED_INITIALIZER;

- (BOOL)loadPairingDataForUrl:(NSURL *)url error:(NSError **)error;

- (nullable NSArray<JBApp *> *)installedAppsWithError:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
