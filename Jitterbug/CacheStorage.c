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

#include <plist/plist.h>
#include <string.h>
#include <stdlib.h>
#include "CacheStorage.h"
#include "Jitterbug.h"
#include "collection.h"
#include "common/utils.h"

typedef struct {
    char *file;
    char *udid;
    plist_t plist;
} pairing_t;

typedef struct {
    char *file;
    char *ipaddr;
} host_t;

static struct collection g_pairing_cache = {0};
static struct collection g_host_cache = {0};

static const char *keyFromPath(const char *path) {
    const char *res = strrchr(path, '/');
    if (res) {
        return res+1;
    } else {
        return path;
    }
}

int cachePairingAddFromFile(const char *path) {
    pairing_t *pairing = NULL;
    plist_t plist = NULL;
    plist_t udid = NULL;
    
    if (g_pairing_cache.capacity == 0) {
        collection_init(&g_pairing_cache);
    }
    if (!plist_read_from_filename(&plist, path)) {
        DEBUG_PRINT("failed to read plist from %s", path);
        return 0;
    }
    pairing = calloc(sizeof(pairing_t), 1);
    pairing->file = strdup(keyFromPath(path));
    udid = plist_dict_get_item(plist, "UDID");
    if (udid) {
        plist_get_string_val(udid, &pairing->udid);
    } else {
        DEBUG_PRINT("cannot find UDID in pairing plist");
        goto error;
    }
    
    pairing->plist = plist;
    collection_add(&g_pairing_cache, pairing);
    
error:
    if (plist) {
        plist_free(plist);
    }
    if (pairing) {
        if (pairing->file) {
            free(pairing->file);
        }
        if (pairing->udid) {
            free(pairing->udid);
        }
        plist_free(pairing);
    }
    return -1;
}

static void freePairing(pairing_t *pairing) {
    plist_free(pairing->plist);
    free(pairing->file);
    free(pairing->udid);
    free(pairing);
}

int cachePairingRemoveForFile(const char *path) {
    const char *key = keyFromPath(path);
    int ret = -1;
    FOREACH(pairing_t *pairing, &g_pairing_cache) {
        if (pairing && strcmp(pairing->file, key) == 0) {
            collection_remove(&g_pairing_cache, pairing);
            freePairing(pairing);
            ret = 0;
        }
    } ENDFOREACH
    return ret;
}

plist_t cachePairingGetForUdid(const char *udid) {
    FOREACH(pairing_t *pairing, &g_pairing_cache) {
        if (pairing && strcmp(pairing->udid, udid) == 0) {
            return pairing->plist;
        }
    } ENDFOREACH
    return NULL;
}

int cacheHostAddIpaddr(const char *ipaddr, const char *path) {
    host_t *host = NULL;
    
    if (g_host_cache.capacity == 0) {
        collection_init(&g_host_cache);
    }
    host = calloc(sizeof(host_t), 1);
    host->file = strdup(keyFromPath(path));
    host->ipaddr = strdup(ipaddr);
    collection_add(&g_host_cache, host);
    return 0;
}

int cacheHostRemoveIpaddr(const char *ipaddr) {
    int ret = -1;
    FOREACH(host_t *host, &g_host_cache) {
        if (host && strcmp(host->ipaddr, ipaddr) == 0) {
            collection_remove(&g_host_cache, host);
            free(host->file);
            free(host->ipaddr);
            free(host);
            ret = 0;
        }
    } ENDFOREACH
    return ret;
}


static const char *cacheHostGetForKey(const char *key) {
    FOREACH(host_t *host, &g_host_cache) {
        if (host && strcmp(host->file, key) == 0) {
            return host->ipaddr;
        }
    } ENDFOREACH
    return NULL;
}

const char *cacheHostGetForUdid(const char *udid) {
    FOREACH(pairing_t *pairing, &g_pairing_cache) {
        if (pairing && strcmp(pairing->udid, udid) == 0) {
            return cacheHostGetForKey(pairing->file);
        }
    } ENDFOREACH
    return NULL;
}
