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
#include <libimobiledevice/debugserver.h>
#include <libimobiledevice/heartbeat.h>
#include <libimobiledevice/installation_proxy.h>
#include <libimobiledevice/lockdown.h>
#include <libimobiledevice/mobile_image_mounter.h>
#include <libimobiledevice/sbservices.h>
#include <libimobiledevice/service.h>
#include <libimobiledevice-glue/utils.h>
#include "common/userpref.h"
#import "JBApp.h"
#import "JBHostDevice.h"
#import "Jitterbug.h"
#import "Jitterbug-Swift.h"
#import "CacheStorage.h"

#define TOOL_NAME "jitterbug"
NSString *const kJBErrorDomain = @"com.osy86.Jitterbug";
const NSInteger kJBHostImageNotMounted = -666;
static const char PKG_PATH[] = "PublicStaging";
static const char PATH_PREFIX[] = "/private/var/mobile/Media";

@interface JBHostDevice ()

@property (nonatomic, readwrite) BOOL isUsbDevice;
@property (nonatomic, readwrite) NSString *hostname;
@property (nonatomic, readwrite) NSData *address;
@property (nonatomic, nullable, readwrite) NSString *udid;
@property (nonatomic) idevice_t device;
@property (nonatomic) lockdownd_client_t lockdown;
@property (nonatomic, nonnull) dispatch_queue_t timerQueue;
@property (nonatomic, nonnull) dispatch_semaphore_t timerCancelEvent;
@property (nonatomic, nullable) dispatch_source_t heartbeat;

@end

@implementation JBHostDevice

#pragma mark - Properties and initializers

+ (BOOL)supportsSecureCoding {
    return YES;
}

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

- (void)setDiscovered:(BOOL)discovered {
    if (_discovered != discovered) {
        [self propertyWillChange];
        _discovered = discovered;
    }
}

- (void)setLockdown:(lockdownd_client_t)lockdown {
    if (_lockdown != lockdown) {
        [self propertyWillChange];
        _lockdown = lockdown;
    }
}

- (NSString *)identifier {
    if (self.isUsbDevice) {
        return self.udid;
    } else {
        return self.hostname;
    }
}

- (BOOL)isConnected {
    return self.lockdown != nil;
}

- (void)setupDispatchQueue {
    self.timerQueue = dispatch_queue_create("heartbeatQueue", DISPATCH_QUEUE_SERIAL);
    self.timerCancelEvent = dispatch_semaphore_create(0);
}

- (instancetype)initWithHostname:(NSString *)hostname address:(NSData *)address {
    if (self = [super init]) {
        self.isUsbDevice = NO;
        self.hostname = hostname;
        self.udid = @"";
        self.address = address;
        self.name = hostname;
        self.hostDeviceType = JBHostDeviceTypeUnknown;
        [self setupDispatchQueue];
    }
    return self;
}

- (instancetype)initWithUdid:(NSString *)udid address:(NSData *)address {
    if (self = [super init]) {
        self.isUsbDevice = YES;
        self.hostname = @"";
        self.udid = udid;
        self.address = address ? address : [NSData data];
        self.name = udid;
        self.hostDeviceType = JBHostDeviceTypeUnknown;
        [self setupDispatchQueue];
    }
    return self;
}

- (void)dealloc {
    [self stopLockdown];
}

#pragma mark - NSCoding

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder {
    if (self = [self init]) {
        self.isUsbDevice = [coder decodeBoolForKey:@"isUsbDevice"];
        self.name = [coder decodeObjectForKey:@"name"];
        if (!self.name) {
            return nil;
        }
        self.hostname = [coder decodeObjectForKey:@"hostname"];
        if (!self.hostname) {
            return nil;
        }
        self.udid = [coder decodeObjectForKey:@"udid"];
        if (!self.udid) {
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
        [self setupDispatchQueue];
    }
    return self;
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder {
    [coder encodeBool:self.isUsbDevice forKey:@"isUsbDevice"];
    [coder encodeObject:self.name forKey:@"name"];
    [coder encodeObject:self.hostname forKey:@"hostname"];
    [coder encodeObject:self.udid forKey:@"udid"];
    [coder encodeObject:self.address forKey:@"address"];
    [coder encodeInteger:self.hostDeviceType forKey:@"hostDeviceType"];
}

#pragma mark - Methods

static service_error_t service_client_factory_start_service_with_lockdown(lockdownd_client_t lckd, idevice_t device, const char* service_name, void **client, const char* label, int32_t (*constructor_func)(idevice_t, lockdownd_service_descriptor_t, void**), int32_t *error_code)
{
    *client = NULL;

    lockdownd_service_descriptor_t service = NULL;
    lockdownd_start_service(lckd, service_name, &service);

    if (!service || service->port == 0) {
        DEBUG_PRINT("Could not start service %s!", service_name);
        return SERVICE_E_START_SERVICE_ERROR;
    }

    int32_t ec;
    if (constructor_func) {
        ec = (int32_t)constructor_func(device, service, client);
    } else {
        ec = service_client_new(device, service, (service_client_t*)client);
    }
    if (error_code) {
        *error_code = ec;
    }

    if (ec != SERVICE_E_SUCCESS) {
        DEBUG_PRINT("Could not connect to service %s! Port: %i, error: %i", service_name, service->port, ec);
    }

    lockdownd_service_descriptor_free(service);
    service = NULL;

    return (ec == SERVICE_E_SUCCESS) ? SERVICE_E_SUCCESS : SERVICE_E_START_SERVICE_ERROR;
}

- (void)createError:(NSError **)error withString:(NSString *)string code:(NSInteger)code {
    if (error) {
        *error = [NSError errorWithDomain:kJBErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey: string}];
    }
}

- (void)createError:(NSError **)error withString:(NSString *)string {
    [self createError:error withString:string code:-1];
}

- (void)stopLockdown {
    [self stopHeartbeat];
    if (self.lockdown) {
        lockdownd_client_free(self.lockdown);
        self.lockdown = NULL;
    }
    if (self.device) {
        idevice_free(self.device);
        self.device = NULL;
    }
    if (self.udid.length > 0) {
        cachePairingRemove(self.udid.UTF8String);
    }
}

- (BOOL)startLockdownWithPairingUrl:(NSURL *)url error:(NSError **)error {
    idevice_error_t derr = IDEVICE_E_SUCCESS;
    lockdownd_error_t lerr = LOCKDOWN_E_SUCCESS;
    
    assert(!self.isUsbDevice);
    [self stopLockdown];
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
    
    if ((derr = idevice_new_with_options(&_device, udid.UTF8String, IDEVICE_LOOKUP_NETWORK)) != IDEVICE_E_SUCCESS) {
        [self createError:error withString:NSLocalizedString(@"Failed to create device.", @"JBHostDevice") code:derr];
        goto error;
    }
    
    if ((lerr = lockdownd_client_new_with_handshake(self.device, &_lockdown, TOOL_NAME)) != LOCKDOWN_E_SUCCESS) {
        [self createError:error withString:NSLocalizedString(@"Failed to communicate with device. Make sure the device is connected and unlocked and that the pairing is valid.", @"JBHostDevice") code:lerr];
        goto error;
    }
    
    /**
     * We need a unique heartbeat service for each hostID or lockdownd immediately kills the service.
     */
    if (![self startHeartbeatWithError:error]) {
        goto error;
    }
    
    self.udid = udid;
    return YES;
    
error:
    [self stopLockdown];
    return NO;
}

- (BOOL)startLockdownWithError:(NSError **)error {
    idevice_error_t derr = IDEVICE_E_SUCCESS;
    lockdownd_error_t lerr = LOCKDOWN_E_SUCCESS;
    
    assert(self.udid);
    [self stopLockdown];
    
    if ((derr = idevice_new_with_options(&_device, self.udid.UTF8String, IDEVICE_LOOKUP_NETWORK | IDEVICE_LOOKUP_USBMUX)) != IDEVICE_E_SUCCESS) {
        [self createError:error withString:NSLocalizedString(@"Failed to create device.", @"JBHostDevice") code:derr];
        goto error;
    }
    
    if ((lerr = lockdownd_client_new_with_handshake(self.device, &_lockdown, TOOL_NAME)) != LOCKDOWN_E_SUCCESS) {
        [self createError:error withString:NSLocalizedString(@"Failed to communicate with device. Make sure the device is connected, unlocked, and paired.", @"JBHostDevice") code:lerr];
        goto error;
    }
    
    /**
     * We need a unique heartbeat service for each hostID or lockdownd immediately kills the service.
     */
    if (![self startHeartbeatWithError:error]) {
        goto error;
    }
    
    return YES;
    
error:
    [self stopLockdown];
    return NO;
}

- (BOOL)startHeartbeatWithError:(NSError **)error {
    heartbeat_client_t client;
    heartbeat_error_t err = HEARTBEAT_E_UNKNOWN_ERROR;
    
    [self stopHeartbeat];
    service_client_factory_start_service_with_lockdown(self.lockdown, self.device, HEARTBEAT_SERVICE_NAME, (void **)&client, TOOL_NAME, SERVICE_CONSTRUCTOR(heartbeat_client_new), &err);
    if (err != HEARTBEAT_E_SUCCESS) {
        [self createError:error withString:NSLocalizedString(@"Failed to create heartbeat service.", @"JBHostDevice") code:err];
        return NO;
    }
    self.heartbeat = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.timerQueue);
    dispatch_source_set_timer(self.heartbeat, DISPATCH_TIME_NOW, 0, 5LL * NSEC_PER_SEC);
    dispatch_source_set_event_handler(self.heartbeat, ^{
        plist_t ping;
        uint64_t interval = 15;
        DEBUG_PRINT("Timer run!");
        if (heartbeat_receive_with_timeout(client, &ping, (uint32_t)interval * 1000) != HEARTBEAT_E_SUCCESS) {
            DEBUG_PRINT("Did not recieve ping, canceling timer!");
            dispatch_source_cancel(self.heartbeat);
            return;
        }
        plist_get_uint_val(plist_dict_get_item(ping, "Interval"), &interval);
        DEBUG_PRINT("Set new timer interval: %llu!", interval);
        dispatch_source_set_timer(self.heartbeat, dispatch_time(DISPATCH_TIME_NOW, interval * NSEC_PER_SEC), 0, 5LL * NSEC_PER_SEC);
        DEBUG_PRINT("Sending heartbeat.");
        heartbeat_send(client, ping);
        plist_free(ping);
    });
    dispatch_source_set_cancel_handler(self.heartbeat, ^{
        DEBUG_PRINT("Timer cancel called!");
        heartbeat_client_free(client);
        self.heartbeat = nil;
        dispatch_semaphore_signal(self.timerCancelEvent);
    });
    dispatch_resume(self.heartbeat);
    return YES;
}

- (void)stopHeartbeat {
    if (self.heartbeat) {
        DEBUG_PRINT("Stopping heartbeat");
        dispatch_source_cancel(self.heartbeat);
        dispatch_semaphore_wait(self.timerCancelEvent, DISPATCH_TIME_FOREVER);
        DEBUG_PRINT("Heartbeat should be null now!");
        assert(self.heartbeat == nil);
    }
}

- (void)updateAddress:(NSData *)address {
    self.address = address;
    if (self.udid.length > 0) {
        cachePairingUpdateAddress(self.udid.UTF8String, (__bridge CFDataRef)(address));
    }
}

static NSString *plist_dict_get_nsstring(plist_t dict, const char *key) {
    plist_t *value = plist_dict_get_item(dict, key);
    const char* cString = plist_get_string_ptr(value, NULL);
    if (cString == NULL) {
        return @"";
    }
    NSString *string = [NSString stringWithUTF8String:cString];
    return string;
}

- (NSArray<JBApp *> *)parseLookupResult:(plist_t)plist {
    plist_dict_iter iter = NULL;
    uint32_t len = plist_dict_get_size(plist);
    NSMutableArray<JBApp *> *ret = [NSMutableArray arrayWithCapacity:len];
    plist_dict_new_iter(plist, &iter);
    for (uint32_t i = 0; i < len; i++) {
        plist_t item = NULL;
        plist_dict_next_item(plist, iter, NULL, &item);
        JBApp *app = [JBApp new];
        app.bundleName = plist_dict_get_nsstring(item, "CFBundleName");
        app.bundleIdentifier = plist_dict_get_nsstring(item, "CFBundleIdentifier");
        app.bundleExecutable = plist_dict_get_nsstring(item, "CFBundleExecutable");
        app.container = plist_dict_get_nsstring(item, "Container");
        app.path = plist_dict_get_nsstring(item, "Path");
        [ret addObject:app];
    }
    free(iter);
    return ret;
}

- (BOOL)updateDeviceInfoWithError:(NSError **)error {
    lockdownd_error_t err = LOCKDOWN_E_SUCCESS;
    plist_t node = NULL;
    
    if ((err = lockdownd_get_value(self.lockdown, NULL, "DeviceName", &node)) != LOCKDOWN_E_SUCCESS) {
        [self createError:error withString:NSLocalizedString(@"Failed to read device name.", @"JBHostDevice") code:err];
        return NO;
    }
    self.name = [NSString stringWithUTF8String:plist_get_string_ptr(node, NULL)];
    plist_free(node);
    
    if ((err = lockdownd_get_value(self.lockdown, NULL, "DeviceClass", &node)) != LOCKDOWN_E_SUCCESS) {
        [self createError:error withString:NSLocalizedString(@"Failed to read device class.", @"JBHostDevice") code:err];
        return NO;
    }
    if (strcmp(plist_get_string_ptr(node, NULL), "iPhone") == 0) {
        self.hostDeviceType = JBHostDeviceTypeiPhone;
    } else if (strcmp(plist_get_string_ptr(node, NULL), "iPad") == 0) {
        self.hostDeviceType = JBHostDeviceTypeiPad;
    } else {
        self.hostDeviceType = JBHostDeviceTypeUnknown;
    }
    plist_free(node);
    
    return YES;
}

- (NSArray<JBApp *> *)installedAppsWithError:(NSError **)error {
    instproxy_client_t instproxy_client = NULL;
    instproxy_error_t err = INSTPROXY_E_SUCCESS;
    plist_t client_opts = NULL;
    plist_t apps = NULL;
    NSArray<JBApp *> *ret = nil;
    
    service_client_factory_start_service_with_lockdown(self.lockdown, self.device, INSTPROXY_SERVICE_NAME, (void**)&instproxy_client, TOOL_NAME, SERVICE_CONSTRUCTOR(instproxy_client_new), &err);
    if (err != INSTPROXY_E_SUCCESS) {
        [self createError:error withString:NSLocalizedString(@"Failed to start service on device. Make sure the device is connected to the network and unlocked and that the pairing is valid.", @"JBHostDevice") code:err];
        goto end;
    }
    
    client_opts = instproxy_client_options_new();
    instproxy_client_options_add(client_opts, "ApplicationType", "User", NULL);
    instproxy_client_options_set_return_attributes(client_opts, "CFBundleName", "CFBundleIdentifier", "CFBundleExecutable", "Path", "Container", "iTunesArtwork", NULL);
    if ((err = instproxy_lookup(instproxy_client, NULL, client_opts, &apps)) != INSTPROXY_E_SUCCESS) {
        [self createError:error withString:NSLocalizedString(@"Failed to lookup installed apps.", @"JBHostDevice") code:err];
        goto end;
    }
    
    ret = [self parseLookupResult:apps];
    plist_free(apps);
    if (ret == nil) {
        goto end;
    }
    
    sbservices_client_t sbs = NULL;
    sbservices_error_t serr = SBSERVICES_E_SUCCESS;
    service_client_factory_start_service_with_lockdown(self.lockdown, self.device, SBSERVICES_SERVICE_NAME, (void**)&sbs, TOOL_NAME, SERVICE_CONSTRUCTOR(sbservices_client_new), &err);
    if (serr != SBSERVICES_E_SUCCESS) {
        DEBUG_PRINT("ignoring sbservices error, no icons generated");
        goto end;
    }
    
    for (JBApp *app in ret) {
        char *pngdata = NULL;
        uint64_t pngsize = 0;
        if (sbservices_get_icon_pngdata(sbs, app.bundleIdentifier.UTF8String, &pngdata, &pngsize) != SBSERVICES_E_SUCCESS) {
            DEBUG_PRINT("failed to get icon for '%s'", app.bundleIdentifier.UTF8String);
            continue;
        }
        NSData *data = [NSData dataWithBytes:pngdata length:pngsize];
        app.icon = data;
        free(pngdata);
    }
    
    sbservices_client_free(sbs);
    
end:
    if (instproxy_client) {
        instproxy_client_free(instproxy_client);
    }
    if (client_opts) {
        instproxy_client_options_free(client_opts);
    }
    return ret;
}

static ssize_t mim_upload_cb(void* buf, size_t size, void* userdata)
{
    return fread(buf, 1, size, (FILE*)userdata);
}

- (BOOL)mountImageForUrl:(NSURL *)url signatureUrl:(NSURL *)signatureUrl error:(NSError **)error {
    mobile_image_mounter_error_t merr = MOBILE_IMAGE_MOUNTER_E_SUCCESS;
    mobile_image_mounter_client_t mim = NULL;
    BOOL res = NO;
    const char *image_path = url.path.UTF8String;
    size_t image_size = 0;
    const char *image_sig_path = signatureUrl.path.UTF8String;
    const char *imagetype = "Developer";

    service_client_factory_start_service_with_lockdown(self.lockdown, self.device, MOBILE_IMAGE_MOUNTER_SERVICE_NAME, (void**)&mim, TOOL_NAME, SERVICE_CONSTRUCTOR(mobile_image_mounter_new), &merr);
    if (merr != MOBILE_IMAGE_MOUNTER_E_SUCCESS) {
        [self createError:error withString:NSLocalizedString(@"Could not connect to mobile_image_mounter!", @"JBHostDevice") code:merr];
        return NO;
    }
    
    // Check if image is already mounted
    plist_t result = NULL;
    BOOL needsMount = YES;
    
    merr = mobile_image_mounter_lookup_image(mim, imagetype, &result);
    if (merr == MOBILE_IMAGE_MOUNTER_E_SUCCESS && result) {
        plist_t node = plist_dict_get_item(result, "ImageSignature");
        if (node && plist_array_get_size(node) > 0) {
            DEBUG_PRINT("Device already has DDI mounted\n");
            needsMount = NO;
        }
        
        plist_free(result);
    }
    
    if (!needsMount) {
        // Bail out here if there's already a DDI mounted
        res = YES;
        goto error_out;
    }

    struct stat fst;
    if (stat(image_path, &fst) != 0) {
        [self createError:error withString:NSLocalizedString(@"Cannot stat image file!", @"JBHostDevice") code:-errno];
        goto error_out;
    }
    image_size = fst.st_size;
    if (stat(image_sig_path, &fst) != 0) {
        [self createError:error withString:NSLocalizedString(@"Cannot stat signature file!", @"JBHostDevice") code:-errno];
        goto error_out;
    }

    mobile_image_mounter_error_t err = MOBILE_IMAGE_MOUNTER_E_UNKNOWN_ERROR;
    result = NULL;

    char sig[8192];
    size_t sig_length = 0;
    FILE *f = fopen(image_sig_path, "rb");
    if (!f) {
        [self createError:error withString:NSLocalizedString(@"Error opening signature file.", @"JBHostDevice") code:-errno];
        goto error_out;
    }
    sig_length = fread(sig, 1, sizeof(sig), f);
    fclose(f);
    if (sig_length == 0) {
        [self createError:error withString:NSLocalizedString(@"Could not read signature from file.", @"JBHostDevice") code:-errno];
        goto error_out;
    }

    f = fopen(image_path, "rb");
    if (!f) {
        [self createError:error withString:NSLocalizedString(@"Error opening image file.", @"JBHostDevice") code:-errno];
        goto error_out;
    }

    char *targetname = NULL;
    if (asprintf(&targetname, "%s/%s", PKG_PATH, "staging.dimage") < 0) {
        [self createError:error withString:NSLocalizedString(@"Out of memory!?", @"JBHostDevice")];
        goto error_out;
    }
    char *mountname = NULL;
    if (asprintf(&mountname, "%s/%s", PATH_PREFIX, targetname) < 0) {
        [self createError:error withString:NSLocalizedString(@"Out of memory!?", @"JBHostDevice")];
        goto error_out;
    }

    DEBUG_PRINT("Uploading %s\n", image_path);
    err = mobile_image_mounter_upload_image(mim, imagetype, image_size, sig, sig_length, mim_upload_cb, f);

    fclose(f);

    if (err != MOBILE_IMAGE_MOUNTER_E_SUCCESS) {
        if (err == MOBILE_IMAGE_MOUNTER_E_DEVICE_LOCKED) {
            [self createError:error withString:NSLocalizedString(@"Device is locked, can't mount. Unlock device and try again.", @"JBHostDevice") code:err];
        } else {
            [self createError:error withString:NSLocalizedString(@"Unknown error occurred, can't mount.", @"JBHostDevice") code:err];
        }
        goto error_out;
    }
    DEBUG_PRINT("done.\n");

    DEBUG_PRINT("Mounting...\n");
    err = mobile_image_mounter_mount_image(mim, mountname, sig, sig_length, imagetype, &result);
    if (err == MOBILE_IMAGE_MOUNTER_E_SUCCESS) {
        if (result) {
            plist_t node = plist_dict_get_item(result, "Status");
            if (node) {
                char *status = NULL;
                plist_get_string_val(node, &status);
                if (status) {
                    if (!strcmp(status, "Complete")) {
                        DEBUG_PRINT("Done.\n");
                        res = YES;
                    } else {
                        DEBUG_PRINT("unexpected status value:\n");
                        plist_print_to_stream(result, stderr);
                    }
                    free(status);
                } else {
                    DEBUG_PRINT("unexpected result:\n");
                    plist_print_to_stream(result, stderr);
                }
            }
            node = plist_dict_get_item(result, "Error");
            if (node) {
                char *errstr = NULL;
                plist_get_string_val(node, &errstr);
                if (error) {
                    DEBUG_PRINT("Error: %s\n", errstr);
                    [self createError:error withString:[NSString stringWithUTF8String:errstr]];
                    free(errstr);
                } else {
                    DEBUG_PRINT("unexpected result:\n");
                    plist_print_to_stream(result, stderr);
                }

            } else {
                plist_print_to_stream(result, stderr);
            }
        }
    } else {
        [self createError:error withString:NSLocalizedString(@"Mount image failed.", @"JBHostDevice") code:err];
    }

    if (result) {
        plist_free(result);
    }

error_out:
    /* perform hangup command */
    mobile_image_mounter_hangup(mim);
    /* free client */
    mobile_image_mounter_free(mim);

    return res;
}

- (BOOL)launchApplication:(JBApp *)application error:(NSError **)error {
    int res = NO;
    debugserver_client_t debugserver_client = NULL;
    char* response = NULL;
    debugserver_command_t command = NULL;
    debugserver_error_t dres = DEBUGSERVER_E_UNKNOWN_ERROR;
    
    /* start and connect to debugserver */
    service_client_factory_start_service_with_lockdown(self.lockdown, self.device, DEBUGSERVER_SECURE_SERVICE_NAME, (void**)&debugserver_client, TOOL_NAME, SERVICE_CONSTRUCTOR(debugserver_client_new), &dres);
    if (dres != DEBUGSERVER_E_SUCCESS) {
        [self createError:error withString:NSLocalizedString(@"Failed to start debugserver. Make sure DeveloperDiskImage.dmg is mounted.", @"JBHostDevice") code:kJBHostImageNotMounted];
        goto cleanup;
    }
    
    /* set arguments and run app */
    DEBUG_PRINT("Setting argv...");
    int app_argc = 1;
    const char *app_argv[] = { application.executablePath.UTF8String, NULL };
    DEBUG_PRINT("app_argv[%d] = %s", 0, app_argv[0]);
    debugserver_client_set_argv(debugserver_client, app_argc, (char **)app_argv, NULL);
    
    /* check if launch succeeded */
    DEBUG_PRINT("Checking if launch succeeded...");
    debugserver_command_new("qLaunchSuccess", 0, NULL, &command);
    dres = debugserver_client_send_command(debugserver_client, command, &response, NULL);
    debugserver_command_free(command);
    command = NULL;
    if (response) {
        if (strncmp(response, "OK", 2)) {
            [self createError:error withString:[NSString stringWithUTF8String:&response[1]]];
            goto cleanup;
        }
        free(response);
        response = NULL;
    }

    /* continue running process */
    DEBUG_PRINT("Continue running process...");
    debugserver_command_new("c", 0, NULL, &command);
    dres = debugserver_client_send_command(debugserver_client, command, NULL, NULL);
    debugserver_command_free(command);
    
    DEBUG_PRINT("Getting threads info...");
    char three = 3;
    debugserver_client_send(debugserver_client, &three, sizeof(three), NULL);
    debugserver_command_new("jThreadsInfo", 0, NULL, &command);
    dres = debugserver_client_send_command(debugserver_client, command, NULL, NULL);
    debugserver_command_free(command);
    
    DEBUG_PRINT("Detaching from app...");
    debugserver_command_new("D", 0, NULL, &command);
    dres = debugserver_client_send_command(debugserver_client, command, NULL, NULL);
    debugserver_command_free(command);

    res = (dres == DEBUGSERVER_E_SUCCESS) ? YES : NO;
    if (!res) {
        [self createError:error withString:NSLocalizedString(@"Failed to start application.", @"JBHostDevice") code:dres];
    }
    
cleanup:
    /* cleanup the house */

    if (response)
        free(response);

    if (debugserver_client)
        debugserver_client_free(debugserver_client);

    return res;
}

- (BOOL)resetPairingWithError:(NSError **)error {
    lockdownd_error_t lerr = LOCKDOWN_E_SUCCESS;
    
    assert(self.lockdown);
    lerr = lockdownd_unpair(self.lockdown, NULL);
    if (lerr != LOCKDOWN_E_SUCCESS) {
        [self createError:error withString:NSLocalizedString(@"Failed to reset pairing.", @"JBHostDevice") code:lerr];
        return NO;
    }
    
    [self stopLockdown];
    return YES;
}

- (NSData *)exportPairingWithError:(NSError **)error {
    lockdownd_error_t lerr = LOCKDOWN_E_SUCCESS;
    userpref_error_t err = USERPREF_E_SUCCESS;
    plist_t pair_record = NULL;
    char *plist_xml = NULL;
    uint32_t length;
    NSData *data = NULL;
    
    assert(self.udid);
    assert(self.lockdown);
    
    if (self.isUsbDevice) {
        lerr = lockdownd_set_value(self.lockdown, "com.apple.mobile.wireless_lockdown", "EnableWifiDebugging", plist_new_bool(1));
        if (lerr != LOCKDOWN_E_SUCCESS) {
            if (lerr == LOCKDOWN_E_UNKNOWN_ERROR) {
                [self createError:error withString:NSLocalizedString(@"You must set up a passcode to enable wireless pairing.", @"JBHostDevice")];
            } else {
                [self createError:error withString:NSLocalizedString(@"Error setting up Wifi debugging.", @"JBHostDevice") code:lerr];
            }
            return nil;
        }
    }
    
    err = userpref_read_pair_record(self.udid.UTF8String, &pair_record);
    if (err != USERPREF_E_SUCCESS) {
        [self createError:error withString:NSLocalizedString(@"Failed to find pairing record.", @"JBHostDevice") code:err];
        return nil;
    }
    plist_dict_set_item(pair_record, "UDID", plist_new_string(self.udid.UTF8String));
    plist_to_xml(pair_record, &plist_xml, &length);
    data = [NSData dataWithBytes:plist_xml length:length];
    free(plist_xml);
    plist_free(pair_record);
    return data;
}

@end
