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

#include "CacheStorage.h"
#include "Jitterbug.h"
#include <libimobiledevice-glue/collection.h>

typedef struct {
    char *udid;
    CFDataRef address;
    CFDataRef data;
} pairing_t;

static struct collection g_pairing_cache = {0};

int cachePairingAdd(const char *udid, CFDataRef address, CFDataRef data) {
    pairing_t *pairing = NULL;
    
    if (g_pairing_cache.capacity == 0) {
        collection_init(&g_pairing_cache);
    }
    pairing = calloc(sizeof(pairing_t), 1);
    pairing->udid = strdup(udid);
    pairing->address = CFRetain(address);
    pairing->data = CFRetain(data);
    collection_add(&g_pairing_cache, pairing);
    return 1;
}

int cachePairingUpdateAddress(const char *udid, CFDataRef address) {
    FOREACH(pairing_t *pairing, &g_pairing_cache) {
        if (pairing && strcmp(pairing->udid, udid) == 0) {
            CFRelease(pairing->address);
            pairing->address = CFRetain(address);
            return 1;
        }
    } ENDFOREACH
    return 0;
}

int cachePairingUpdateData(const char *udid, CFDataRef data) {
    FOREACH(pairing_t *pairing, &g_pairing_cache) {
        if (pairing && strcmp(pairing->udid, udid) == 0) {
            CFRelease(pairing->data);
            pairing->data = CFRetain(data);
            return 1;
        }
    } ENDFOREACH
    return 0;
}

int cachePairingRemove(const char *udid) {
    int ret = 0;
    FOREACH(pairing_t *pairing, &g_pairing_cache) {
        if (pairing && strcmp(pairing->udid, udid) == 0) {
            collection_remove(&g_pairing_cache, pairing);
            free(pairing->udid);
            CFRelease(pairing->address);
            CFRelease(pairing->data);
            free(pairing);
            ret = 1;
        }
    } ENDFOREACH
    return ret;
}

int cachePairingGetAddress(const char *udid, char address[static 200]) {
    FOREACH(pairing_t *pairing, &g_pairing_cache) {
        if (pairing && strcmp(pairing->udid, udid) == 0) {
            CFIndex len = CFDataGetLength(pairing->address);
            CFDataGetBytes(pairing->address, CFRangeMake(0, len > 200 ? 200 : len), (void *)address);
            return 1;
        }
    } ENDFOREACH
    return 0;
}

int cachePairingGetData(const char *udid, void **data, size_t *len) {
    FOREACH(pairing_t *pairing, &g_pairing_cache) {
        if (pairing && strcmp(pairing->udid, udid) == 0) {
            *len = CFDataGetLength(pairing->data);
            *data = malloc(*len);
            CFDataGetBytes(pairing->data, CFRangeMake(0, *len), *data);
            return 1;
        }
    } ENDFOREACH
    return 0;
}
