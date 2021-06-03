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

#import "JBHostFinder.h"
#import "Jitterbug.h"
#include <libimobiledevice/libimobiledevice.h>

#define TOOL_NAME "jitterbugmac"

@implementation JBHostFinder

static void new_device(const idevice_event_t *event, void *user_data) {
    JBHostFinder *self = (__bridge JBHostFinder *)user_data;
    NSString *udidString = [NSString stringWithUTF8String:event->udid];
    if (event->event == IDEVICE_DEVICE_ADD) {
        if (event->conn_type == CONNECTION_NETWORK) {
            idevice_info_t *devices;
            int i, count;
            idevice_get_device_list_extended(&devices, &count);
            for (i = 0; i < count; i++) {
                idevice_info_t device = devices[i];
                if (device->conn_type == CONNECTION_NETWORK && strcmp(device->udid, event->udid) == 0) {
                    size_t len = ((uint8_t*)device->conn_data)[0];
                    NSData *address = [NSData dataWithBytes:device->conn_data length:len];
                    [self.delegate hostFinderNewUdid:udidString address:address];
                    break;
                }
            }
            if (i == count) {
                DEBUG_PRINT("Failed to find wireless device %s", event->udid);
                [self.delegate hostFinderError:[NSString stringWithFormat:NSLocalizedString(@"Failed to get address for wireless device %@", @"JBLocalHostFinder"), udidString]];
            }
            idevice_device_list_extended_free(devices);
        } else {
            [self.delegate hostFinderNewUdid:udidString address:nil];
        }
    } else if (event->event == IDEVICE_DEVICE_REMOVE) {
        [self.delegate hostFinderRemoveUdid:udidString];
    }
}

- (void)startSearch {
    [self.delegate hostFinderWillStart];
    idevice_event_subscribe(new_device, (__bridge void *)self);
}

- (void)stopSearch {
    idevice_event_unsubscribe();
    [self.delegate hostFinderDidStop];
}

@end
