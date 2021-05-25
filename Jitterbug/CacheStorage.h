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

#ifndef CacheStorage_h
#define CacheStorage_h

#include <plist/plist.h>
#include <stdio.h>

int cachePairingAddFromFile(const char *path);
int cachePairingRemoveForFile(const char *path);
plist_t cachePairingGetForUdid(const char *udid);
int cacheHostAddIpaddr(const char *ipaddr, const char *path);
int cacheHostRemoveIpaddr(const char *ipaddr);
const char *cacheHostGetForUdid(const char *udid);

#endif /* CacheStorage_h */
