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
#include <libimobiledevice/installation_proxy.h>
#include <libimobiledevice/lockdown.h>
#include <libimobiledevice/mobile_image_mounter.h>
#include <libimobiledevice/sbservices.h>
#include "common/utils.h"
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

- (void)createError:(NSError **)error withString:(NSString *)string code:(NSInteger)code {
    if (error) {
        *error = [NSError errorWithDomain:kJBErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey: string}];
    }
}

- (void)createError:(NSError **)error withString:(NSString *)string {
    [self createError:error withString:string code:-1];
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

static NSString *plist_dict_get_nsstring(plist_t dict, const char *key) {
    plist_t *value = plist_dict_get_item(dict, key);
    NSString *string = [NSString stringWithUTF8String:plist_get_string_ptr(value, NULL)];
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
    idevice_t device = NULL;
    lockdownd_client_t client = NULL;
    lockdownd_error_t err = LOCKDOWN_E_SUCCESS;
    plist_t node = NULL;
    BOOL ret = NO;
    
    if (!self.udid) {
        [self createError:error withString:NSLocalizedString(@"No valid pairing was found.", @"JBHostDevice")];
        return NO;
    }
    if (idevice_new_with_options(&device, self.udid.UTF8String, IDEVICE_LOOKUP_NETWORK) != IDEVICE_E_SUCCESS) {
        [self createError:error withString:NSLocalizedString(@"Failed to create device.", @"JBHostDevice")];
        [self freePairing];
        goto end;
    }
    
    if ((err = lockdownd_client_new_with_handshake(device, &client, TOOL_NAME)) != LOCKDOWN_E_SUCCESS) {
        [self createError:error withString:NSLocalizedString(@"Failed to query device. Make sure the device is connected and unlocked and that the pairing is valid.", @"JBHostDevice") code:err];
        [self freePairing];
        goto end;
    }
    
    if ((err = lockdownd_get_value(client, NULL, "DeviceName", &node)) != LOCKDOWN_E_SUCCESS) {
        [self createError:error withString:NSLocalizedString(@"Failed to read device name.", @"JBHostDevice") code:err];
        [self freePairing];
        goto end;
    }
    self.name = [NSString stringWithUTF8String:plist_get_string_ptr(node, NULL)];
    plist_free(node);
    
    if ((err = lockdownd_get_value(client, NULL, "DeviceClass", &node)) != LOCKDOWN_E_SUCCESS) {
        [self createError:error withString:NSLocalizedString(@"Failed to read device class.", @"JBHostDevice") code:err];
        [self freePairing];
        goto end;
    }
    if (strcmp(plist_get_string_ptr(node, NULL), "iPhone") == 0) {
        self.hostDeviceType = JBHostDeviceTypeiPhone;
    } else if (strcmp(plist_get_string_ptr(node, NULL), "iPad") == 0) {
        self.hostDeviceType = JBHostDeviceTypeiPad;
    } else {
        self.hostDeviceType = JBHostDeviceTypeUnknown;
    }
    plist_free(node);
    ret = YES;
    
end:
    if (device) {
        idevice_free(device);
    }
    return ret;
}

- (NSArray<JBApp *> *)installedAppsWithError:(NSError **)error {
    idevice_t device = NULL;
    instproxy_client_t instproxy_client = NULL;
    instproxy_error_t err = INSTPROXY_E_SUCCESS;
    plist_t client_opts = NULL;
    plist_t apps = NULL;
    NSArray<JBApp *> *ret = nil;
    
    if (!self.udid) {
        [self createError:error withString:NSLocalizedString(@"No valid pairing was found.", @"JBHostDevice")];
        return nil;
    }
    if (idevice_new_with_options(&device, self.udid.UTF8String, IDEVICE_LOOKUP_NETWORK) != IDEVICE_E_SUCCESS) {
        [self createError:error withString:NSLocalizedString(@"Failed to create device.", @"JBHostDevice")];
        [self freePairing];
        goto end;
    }
    
    if ((err = instproxy_client_start_service(device, &instproxy_client, TOOL_NAME)) != INSTPROXY_E_SUCCESS) {
        [self createError:error withString:NSLocalizedString(@"Failed to start service on device. Make sure the device is connected and unlocked and that the pairing is valid.", @"JBHostDevice") code:err];
        [self freePairing];
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
    if (sbservices_client_start_service(device, &sbs, TOOL_NAME) != SBSERVICES_E_SUCCESS) {
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
    if (device) {
        idevice_free(device);
    }
    return ret;
}

static ssize_t mim_upload_cb(void* buf, size_t size, void* userdata)
{
    return fread(buf, 1, size, (FILE*)userdata);
}

- (BOOL)mountImageForUrl:(NSURL *)url signatureUrl:(NSURL *)signatureUrl error:(NSError **)error {
    idevice_t device = NULL;
    lockdownd_client_t lckd = NULL;
    lockdownd_error_t ldret = LOCKDOWN_E_UNKNOWN_ERROR;
    mobile_image_mounter_client_t mim = NULL;
    lockdownd_service_descriptor_t service = NULL;
    BOOL res = NO;
    const char *image_path = url.path.UTF8String;
    size_t image_size = 0;
    const char *image_sig_path = signatureUrl.path.UTF8String;
    const char *imagetype = "Developer";
    
    if (!self.udid) {
        [self createError:error withString:NSLocalizedString(@"No valid pairing was found.", @"JBHostDevice")];
        return NO;
    }
    if (idevice_new_with_options(&device, self.udid.UTF8String, IDEVICE_LOOKUP_NETWORK) != IDEVICE_E_SUCCESS) {
        [self createError:error withString:NSLocalizedString(@"Failed to create device.", @"JBHostDevice")];
        [self freePairing];
        return NO;
    }

    if (LOCKDOWN_E_SUCCESS != (ldret = lockdownd_client_new_with_handshake(device, &lckd, TOOL_NAME))) {
        [self createError:error withString:NSLocalizedString(@"Could not connect to lockdown.", @"JBHostDevice") code:ldret];
        goto leave;
    }

    lockdownd_start_service(lckd, "com.apple.mobile.mobile_image_mounter", &service);

    if (!service || service->port == 0) {
        [self createError:error withString:NSLocalizedString(@"Could not start mobile_image_mounter service!", @"JBHostDevice")];
        goto leave;
    }

    if (mobile_image_mounter_new(device, service, &mim) != MOBILE_IMAGE_MOUNTER_E_SUCCESS) {
        [self createError:error withString:NSLocalizedString(@"Could not connect to mobile_image_mounter!", @"JBHostDevice")];
        goto leave;
    }

    if (service) {
        lockdownd_service_descriptor_free(service);
        service = NULL;
    }

    struct stat fst;
    if (stat(image_path, &fst) != 0) {
        [self createError:error withString:NSLocalizedString(@"Cannot stat image file!", @"JBHostDevice") code:-errno];
        goto leave;
    }
    image_size = fst.st_size;
    if (stat(image_sig_path, &fst) != 0) {
        [self createError:error withString:NSLocalizedString(@"Cannot stat signature file!", @"JBHostDevice") code:-errno];
        goto leave;
    }

    lockdownd_client_free(lckd);
    lckd = NULL;

    mobile_image_mounter_error_t err = MOBILE_IMAGE_MOUNTER_E_UNKNOWN_ERROR;
    plist_t result = NULL;

    char sig[8192];
    size_t sig_length = 0;
    FILE *f = fopen(image_sig_path, "rb");
    if (!f) {
        [self createError:error withString:NSLocalizedString(@"Error opening signature file.", @"JBHostDevice") code:-errno];
        goto leave;
    }
    sig_length = fread(sig, 1, sizeof(sig), f);
    fclose(f);
    if (sig_length == 0) {
        [self createError:error withString:NSLocalizedString(@"Could not read signature from file.", @"JBHostDevice") code:-errno];
        goto leave;
    }

    f = fopen(image_path, "rb");
    if (!f) {
        [self createError:error withString:NSLocalizedString(@"Error opening image file.", @"JBHostDevice") code:-errno];
        goto leave;
    }

    char *targetname = NULL;
    if (asprintf(&targetname, "%s/%s", PKG_PATH, "staging.dimage") < 0) {
        [self createError:error withString:NSLocalizedString(@"Out of memory!?", @"JBHostDevice")];
        goto leave;
    }
    char *mountname = NULL;
    if (asprintf(&mountname, "%s/%s", PATH_PREFIX, targetname) < 0) {
        [self createError:error withString:NSLocalizedString(@"Out of memory!?", @"JBHostDevice")];
        goto leave;
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

leave:
    if (lckd) {
        lockdownd_client_free(lckd);
    }
    idevice_free(device);

    return res;
}

- (BOOL)launchApplication:(JBApp *)application error:(NSError **)error {
    int res = NO;
    idevice_t device = NULL;
    debugserver_client_t debugserver_client = NULL;
    char* response = NULL;
    debugserver_command_t command = NULL;
    debugserver_error_t dres = DEBUGSERVER_E_UNKNOWN_ERROR;
    
    if (!self.udid) {
        [self createError:error withString:NSLocalizedString(@"No valid pairing was found.", @"JBHostDevice")];
        return NO;
    }
    if (idevice_new_with_options(&device, self.udid.UTF8String, IDEVICE_LOOKUP_NETWORK) != IDEVICE_E_SUCCESS) {
        [self createError:error withString:NSLocalizedString(@"Failed to create device.", @"JBHostDevice")];
        [self freePairing];
        return NO;
    }
    
    /* start and connect to debugserver */
    if (debugserver_client_start_service(device, &debugserver_client, TOOL_NAME) != DEBUGSERVER_E_SUCCESS) {
        [self createError:error withString:NSLocalizedString(@"Failed to start debugserver.", @"JBHostDevice") code:kJBHostImageNotMounted];
        goto cleanup;
    }
    
    /* set maximum packet size */
    DEBUG_PRINT("Setting maximum packet size...");
    char* packet_size[2] = {strdup("1024"), NULL};
    debugserver_command_new("QSetMaxPacketSize:", 1, packet_size, &command);
    free(packet_size[0]);
    dres = debugserver_client_send_command(debugserver_client, command, &response, NULL);
    debugserver_command_free(command);
    command = NULL;
    if (response) {
        if (strncmp(response, "OK", 2)) {
            [self createError:error withString:[NSString stringWithUTF8String:response]];
            goto cleanup;
        }
        free(response);
        response = NULL;
    }
    
    /* set working directory */
    DEBUG_PRINT("Setting working directory...");
    const char *working_dir[2] = {application.container.UTF8String, NULL};
    debugserver_command_new("QSetWorkingDir:", 1, (char **)working_dir, &command);
    dres = debugserver_client_send_command(debugserver_client, command, &response, NULL);
    debugserver_command_free(command);
    command = NULL;
    if (response) {
        if (strncmp(response, "OK", 2)) {
            [self createError:error withString:[NSString stringWithUTF8String:response]];
            goto cleanup;
        }
        free(response);
        response = NULL;
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
            [self createError:error withString:[NSString stringWithUTF8String:response]];
            goto cleanup;
        }
        free(response);
        response = NULL;
    }
    
    DEBUG_PRINT("Detaching from app");
    debugserver_command_new("D", 0, NULL, &command);
    dres = debugserver_client_send_command(debugserver_client, command, &response, NULL);
    debugserver_command_free(command);
    command = NULL;

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

    if (device)
        idevice_free(device);

    return res;
}

@end
