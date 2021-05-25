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

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif
#include <stdint.h>
#include <stdlib.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <arpa/inet.h>

#define USBMUXD_API __attribute__((visibility("default")))

// usbmuxd public interface
#include "usbmuxd.h"
// usbmuxd protocol
#include "usbmuxd-proto.h"
// custom functions
#include "common/userpref.h"
#include "CacheStorage.h"
#include "Jitterbug.h"

#pragma mark - Device listing

USBMUXD_API int usbmuxd_get_device_by_udid(const char *udid, usbmuxd_device_info_t *device)
{
    char *ipaddr = NULL;
    struct sockaddr_in saddr = {0};
    
    if (!udid) {
        DEBUG_PRINT("udid cannot be null!");
        return -EINVAL;
    }
    if (!device) {
        DEBUG_PRINT("device cannot be null!");
        return -EINVAL;
    }
    if (!cachePairingGetIpaddr(udid, &ipaddr)) {
        DEBUG_PRINT("no cache entry for %s", udid);
        return -ENOENT;
    }
    strcpy(device->udid, udid);
    device->conn_type = CONNECTION_TYPE_NETWORK;
    saddr.sin_len = sizeof(saddr);
    saddr.sin_family = AF_INET;
    saddr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    inet_aton(ipaddr, &saddr.sin_addr);
    free(ipaddr);
    memcpy(device->conn_data, &saddr, saddr.sin_len);
    return 1;
}

USBMUXD_API int usbmuxd_get_device(const char *udid, usbmuxd_device_info_t *device, enum usbmux_lookup_options options)
{
    if ((options & DEVICE_LOOKUP_USBMUX) != 0) {
        DEBUG_PRINT("DEVICE_LOOKUP_USBMUX not supported!");
        return -EINVAL;
    } else {
        return usbmuxd_get_device_by_udid(udid, device);
    }
}

#pragma mark - Device pairing

static char *last_seen_buid = NULL;

USBMUXD_API int usbmuxd_read_buid(char **buid)
{
    if (!last_seen_buid) {
        DEBUG_PRINT("usbmuxd_read_pair_record must be called first!");
        return -EINVAL;
    }
    if (!buid) {
        return -EINVAL;
    }
    *buid = strdup(last_seen_buid);
    return 0;
}

USBMUXD_API int usbmuxd_read_pair_record(const char* record_id, char **record_data, uint32_t *record_size)
{
    void *data;
    size_t len;
    if (!cachePairingGetData(record_id, &data, &len)) {
        DEBUG_PRINT("no cache entry for %s", record_id);
        return -ENOENT;
    }
    *record_data = data;
    *record_size = (uint32_t)len;
    return 1;
}

#pragma mark - Unimplemented functions

USBMUXD_API int usbmuxd_events_subscribe(usbmuxd_subscription_context_t *context, usbmuxd_event_cb_t callback, void *user_data)
{
    abort();
}

USBMUXD_API int usbmuxd_events_unsubscribe(usbmuxd_subscription_context_t context)
{
    abort();
}

USBMUXD_API int usbmuxd_get_device_list(usbmuxd_device_info_t **device_list)
{
    abort();
}

USBMUXD_API int usbmuxd_device_list_free(usbmuxd_device_info_t **device_list)
{
    abort();
}

USBMUXD_API int usbmuxd_subscribe(usbmuxd_event_cb_t callback, void *user_data)
{
    abort();
}

USBMUXD_API int usbmuxd_unsubscribe(void)
{
    abort();
}

USBMUXD_API int usbmuxd_connect(const uint32_t handle, const unsigned short port)
{
    abort();
}

USBMUXD_API int usbmuxd_disconnect(int sfd)
{
    abort();
}

USBMUXD_API int usbmuxd_send(int sfd, const char *data, uint32_t len, uint32_t *sent_bytes)
{
    abort();
}

USBMUXD_API int usbmuxd_recv_timeout(int sfd, char *data, uint32_t len, uint32_t *recv_bytes, unsigned int timeout)
{
    abort();
}

USBMUXD_API int usbmuxd_recv(int sfd, char *data, uint32_t len, uint32_t *recv_bytes)
{
    abort();
}

USBMUXD_API int usbmuxd_save_pair_record_with_device_id(const char* record_id, uint32_t device_id, const char *record_data, uint32_t record_size)
{
    abort();
}

USBMUXD_API int usbmuxd_save_pair_record(const char* record_id, const char *record_data, uint32_t record_size)
{
    abort();
}

USBMUXD_API int usbmuxd_delete_pair_record(const char* record_id)
{
    abort();
}

USBMUXD_API void libusbmuxd_set_use_inotify(int set)
{
    abort();
}

USBMUXD_API void libusbmuxd_set_debug_level(int level)
{
    abort();
}
