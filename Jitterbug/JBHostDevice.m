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

#include <libimobiledevice/libimobiledevice.h>
#include <libimobiledevice/installation_proxy.h>
#import "JBHostDevice.h"
#import "Jitterbug-Swift.h"
#import "CacheStorage.h"

#define TOOL_NAME "jitterbug"
NSString *const kJBErrorDomain = @"com.utmapp.Jitterbug";

@interface JBHostDevice ()

@property (nonatomic, readwrite) NSString *hostname;
@property (nonatomic, readwrite) NSData *address;
@property (nonatomic, nullable, readwrite) NSString *udid;

@end

@implementation JBHostDevice

#pragma mark - Properties and initializers

- (void)setName:(NSString * _Nonnull)name {
    if (_name != name) {
        [self propertyWillChange];
        _name = name;
    }
}

- (void)setHostDeviceType:(JBHostDeviceType)hostDeviceType {
    if (_hostDeviceType != hostDeviceType) {
        [self propertyWillChange];
        _hostDeviceType = hostDeviceType;
    }
}

- (void)setHostVersion:(NSString *)hostVersion {
    if (_hostVersion != hostVersion) {
        [self propertyWillChange];
        _hostVersion = hostVersion;
    }
}

- (void)setDiscovered:(BOOL)discovered {
    if (_discovered != discovered) {
        [self propertyWillChange];
        _discovered = discovered;
    }
}

- (instancetype)initWithHostname:(NSString *)hostname address:(NSData *)address {
    if (self = [super init]) {
        self.hostname = hostname;
        self.address = address;
        self.name = hostname;
        self.hostDeviceType = JBHostDeviceTypeUnknown;
        self.hostVersion = @"";
    }
    return self;
}

- (void)dealloc {
    if (self.udid) {
        [self freePairing];
    }
}

#pragma mark - NSCoding

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder {
    if (self = [self init]) {
        self.name = [coder decodeObjectForKey:@"name"];
        if (!self.name) {
            return nil;
        }
        self.hostname = [coder decodeObjectForKey:@"hostname"];
        if (!self.hostname) {
            return nil;
        }
        self.address = [coder decodeObjectForKey:@"address"];
        if (!self.address) {
            return nil;
        }
        self.hostDeviceType = [coder decodeIntegerForKey:@"hostDeviceType"];
        if (!self.hostDeviceType) {
            return nil;
        }
        self.hostVersion = [coder decodeObjectForKey:@"hostVersion"];
        if (!self.hostVersion) {
            return nil;
        }
    }
    return self;
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder {
    [coder encodeObject:self.name forKey:@"name"];
    [coder encodeObject:self.hostname forKey:@"hostname"];
    [coder encodeObject:self.address forKey:@"address"];
    [coder encodeInteger:self.hostDeviceType forKey:@"hostDeviceType"];
    [coder encodeObject:self.hostVersion forKey:@"hostVersion"];
}

#pragma mark - Methods

- (void)createError:(NSError **)error withString:(NSString *)string {
    if (error) {
        *error = [NSError errorWithDomain:kJBErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: string}];
    }
}

- (void)freePairing {
    NSString *udid = self.udid;
    if (udid) {
        cachePairingRemove(udid.UTF8String);
    }
    self.udid = nil;
}

- (BOOL)loadPairingDataForUrl:(NSURL *)url error:(NSError **)error {
    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:error];
    if (!data) {
        return NO;
    }
    NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:nil error:error];
    if (!plist) {
        return NO;
    }
    NSString *udid = plist[@"UDID"];
    if (!udid) {
        [self createError:error withString:NSLocalizedString(@"Pairing data missing key 'UDID'", @"JBHostDevice")];
    }
    if (!cachePairingUpdateData(udid.UTF8String, (__bridge CFDataRef)(data))) {
        if (!cachePairingAdd(udid.UTF8String, (__bridge CFDataRef)(self.address), (__bridge CFDataRef)(data))) {
            [self createError:error withString:NSLocalizedString(@"Failed cache pairing data.", @"JBHostDevice")];
            return NO;
        }
    }
    self.udid = udid;
    return YES;
}

- (void)updateAddress:(NSData *)address {
    self.address = address;
    if (self.udid) {
        cachePairingUpdateAddress(self.udid.UTF8String, (__bridge CFDataRef)(address));
    }
}

- (NSArray<JBApp *> *)parseLookupResult:(plist_t)plist {
    NSMutableArray<JBApp *> *ret = [NSMutableArray array];
    // TODO: implement this
    return ret;
}

- (NSArray<JBApp *> *)installedAppsWithError:(NSError **)error {
    idevice_t device = NULL;
    instproxy_client_t instproxy_client = NULL;
    plist_t client_opts = NULL;
    plist_t apps = NULL;
    NSArray<JBApp *> *ret = nil;
    
    if (!self.udid) {
        [self createError:error withString:NSLocalizedString(@"No valid pairing was found.", @"JBHostDevice")];
        return nil;
    }
    if (idevice_new_with_options(&device, self.udid.UTF8String, IDEVICE_LOOKUP_NETWORK) != IDEVICE_E_SUCCESS) {
        [self createError:error withString:NSLocalizedString(@"Failed to create device.", @"JBHostDevice")];
        goto end;
    }
    
    if (instproxy_client_start_service(device, &instproxy_client, TOOL_NAME) != INSTPROXY_E_SUCCESS) {
        [self createError:error withString:NSLocalizedString(@"Failed to start service on device. Make sure the device is connected and unlocked and that the pairing is valid.", @"JBHostDevice")];
        goto end;
    }
    
    client_opts = instproxy_client_options_new();
    instproxy_client_options_add(client_opts, "ApplicationType", "User", NULL);
    instproxy_client_options_set_return_attributes(client_opts, "CFBundleName", "CFBundleIdentifier", "CFBundleExecutable", "Container", "iTunesArtwork", NULL);
    if (instproxy_lookup(instproxy_client, NULL, client_opts, &apps) != INSTPROXY_E_SUCCESS) {
        [self createError:error withString:NSLocalizedString(@"Failed to lookup installed apps.", @"JBHostDevice")];
        goto end;
    }
    
    ret = [self parseLookupResult:apps];
    plist_free(apps);
    
end:
    if (instproxy_client) {
        instproxy_client_free(instproxy_client);
    }
    if (client_opts) {
        instproxy_client_options_free(client_opts);
    }
    if (device) {
        idevice_free(device);
    }
    return ret;
}

@end
