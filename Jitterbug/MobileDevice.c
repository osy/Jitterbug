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

#include <arpa/inet.h>
#include <CoreFoundation/CoreFoundation.h>
#include <string.h>
#include <libimobiledevice/installation_proxy.h>
#include <libimobiledevice/libimobiledevice.h>
#include <libimobiledevice/debugserver.h>
#include "../Libraries/libimobiledevice/src/idevice.h"

#define TOOL_NAME "jitterbug"

#define DEBUG_PRINT(...) do { \
        fprintf(stderr, "[%s:%d] ", __FUNCTION__, __LINE__); \
        fprintf(stderr, __VA_ARGS__); \
        fprintf(stderr, "\n"); \
    } while (0)

static CFDictionaryRef plist_to_cfdictionary(plist_t plist) {
    char *xml;
    uint32_t xml_len;
    CFDataRef data;
    CFPropertyListRef list;
    
    plist_to_xml(plist, &xml, &xml_len);
    data = CFDataCreate(kCFAllocatorDefault, (void *)xml, xml_len);
    if (data == NULL) {
        DEBUG_PRINT("ERROR: CFDataCreate failed");
        free(xml);
        return NULL;
    }
    list = CFPropertyListCreateWithData(kCFAllocatorDefault, data, kCFPropertyListImmutable, NULL, NULL);
    CFRelease(data);
    free(xml);
    if (list == NULL) {
        DEBUG_PRINT("ERROR: CFPropertyListCreateWithData failed");
        return NULL;
    }
    if (CFGetTypeID(list) != CFDictionaryGetTypeID()) {
        DEBUG_PRINT("ERROR: CFGetTypeID(list) != CFDictionaryGetTypeID()");
        CFRelease(list);
        return NULL;
    }
    return (CFDictionaryRef)list;
}

static idevice_t idevice_from_ip(const char *ipaddr) {
    struct sockaddr_in saddr = {0};
    idevice_t device = (idevice_t)malloc(sizeof(struct idevice_private));
    if (!device) {
        DEBUG_PRINT("ERROR: out of memory");
        return NULL;
    }

    saddr.sin_len = sizeof(saddr);
    saddr.sin_family = AF_INET;
    saddr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    inet_aton(ipaddr, &saddr.sin_addr);
    device->udid = strdup("");
    device->mux_id = 0;
    device->version = 0;
    device->conn_type = CONNECTION_NETWORK;
    device->conn_data = malloc(saddr.sin_len);
    memcpy(device->conn_data, &saddr, saddr.sin_len);
    return device;
}

CFDictionaryRef deviceCreateAppList(const char *ipaddr) {
    idevice_t device = NULL;
    instproxy_client_t instproxy_client = NULL;
    plist_t client_opts = NULL;
    plist_t apps = NULL;
    CFDictionaryRef ret = NULL;
    
    device = idevice_from_ip(ipaddr);
    if (device == NULL) {
        return NULL;
    }
    
    if (instproxy_client_start_service(device, &instproxy_client, TOOL_NAME) != INSTPROXY_E_SUCCESS) {
        DEBUG_PRINT("ERROR: instproxy_client_start_service failed");
        goto end;
    }
    
    client_opts = instproxy_client_options_new();
    instproxy_client_options_add(client_opts, "ApplicationType", "User", NULL);
    instproxy_client_options_set_return_attributes(client_opts, "CFBundleName", "CFBundleIdentifier", "CFBundleExecutable", "Container", NULL);
    if (instproxy_lookup(instproxy_client, NULL, client_opts, &apps) != INSTPROXY_E_SUCCESS) {
        DEBUG_PRINT("ERROR: instproxy_lookup failed");
        goto end;
    }
    
    ret = plist_to_cfdictionary(apps);
    
end:
    if (instproxy_client) {
        instproxy_client_free(instproxy_client);
    }
    if (client_opts) {
        instproxy_client_options_free(client_opts);
    }
    if (apps) {
        plist_free(apps);
    }
    if (device) {
        idevice_free(device);
    }
    return ret;
}
