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

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <libimobiledevice-glue/utils.h>
#include "common/userpref.h"

#include <libimobiledevice/libimobiledevice.h>
#include <libimobiledevice/lockdown.h>

#define TOOL_NAME "jitterbugpair"

static void print_error_message(lockdownd_error_t err, const char *udid)
{
    switch (err) {
        case LOCKDOWN_E_PASSWORD_PROTECTED:
            fprintf(stderr, "ERROR: Could not validate with device %s because a passcode is set. Please enter the passcode on the device and retry.\n", udid);
            break;
        case LOCKDOWN_E_INVALID_CONF:
        case LOCKDOWN_E_INVALID_HOST_ID:
            fprintf(stderr, "ERROR: Device %s is not paired with this host\n", udid);
            break;
        case LOCKDOWN_E_PAIRING_DIALOG_RESPONSE_PENDING:
            fprintf(stderr, "ERROR: Please accept the trust dialog on the screen of device %s, then attempt to pair again.\n", udid);
            break;
        case LOCKDOWN_E_USER_DENIED_PAIRING:
            fprintf(stderr, "ERROR: Device %s said that the user denied the trust dialog.\n", udid);
            break;
        default:
            fprintf(stderr, "ERROR: Device %s returned unhandled error code %d\n", udid, err);
            break;
    }
}

int print_udids(void) {
    unsigned int i;
    char **udids = NULL;
    unsigned int count = 0;
    userpref_get_paired_udids(&udids, &count);
    for (i = 0; i < count; i++) {
        printf("%s\n", udids[i]);
        free(udids[i]);
    }
    free(udids);
    return EXIT_SUCCESS;
}

int print_help(void) {
    fprintf(stderr, "usage: jitterbugpair [OPTIONS]\n");
    fprintf(stderr, "\n");
    fprintf(stderr, "dumps the pairing for the first connected device (unless -u specified)\n");
    fprintf(stderr, "\n");
    fprintf(stderr, "options:\n");
    fprintf(stderr, "  -h       show this help message\n");
    fprintf(stderr, "  -l       list UDIDs of all connected devices\n");
    fprintf(stderr, "  -u UDID  dump connected device with UDID (first device if unspecified)\n");
    fprintf(stderr, "  -c       dump to stdout instead of file\n");
    fprintf(stderr, "\n");
    return EXIT_FAILURE;
}

int main(int argc, const char * argv[]) {
    int c = 0;
    char *path = NULL;
    char *udid = NULL;
    lockdownd_client_t client = NULL;
    idevice_t device = NULL;
    idevice_error_t ret = IDEVICE_E_UNKNOWN_ERROR;
    lockdownd_error_t lerr;
    int result;
    char *type = NULL;
    plist_t pair_record = NULL;
    char *host_id = NULL;
    char *session_id = NULL;
    
    while ((c = getopt(argc, argv, "lu:c")) != -1) {
        switch (c) {
            case 'l': {
                return print_udids();
            }
            case 'u': {
                udid = strdup(optarg);
                break;
            }
            case 'c': {
                path = strdup("/dev/stdout");
                break;
            }
            case '?':
            default: {
                return print_help();
            }
        }
    }
    
    ret = idevice_new(&device, udid);
    if (ret != IDEVICE_E_SUCCESS) {
        if (udid) {
            fprintf(stderr, "No device found with udid %s.\n", udid);
        } else {
            fprintf(stderr, "No device found.\n");
        }
        result = EXIT_FAILURE;
        goto leave;
    }
    if (!udid) {
        ret = idevice_get_udid(device, &udid);
        if (ret != IDEVICE_E_SUCCESS) {
            fprintf(stderr, "ERROR: Could not get device udid, error code %d\n", ret);
            result = EXIT_FAILURE;
            goto leave;
        }
    }
    if (!path) {
        asprintf(&path, "%s.mobiledevicepairing", udid);
    }
    
    lerr = lockdownd_client_new(device, &client, TOOL_NAME);
    if (lerr != LOCKDOWN_E_SUCCESS) {
        fprintf(stderr, "ERROR: Could not connect to lockdownd, error code %d\n", lerr);
        result = EXIT_FAILURE;
        goto leave;
    }
    
    result = EXIT_SUCCESS;

    lerr = lockdownd_query_type(client, &type);
    if (lerr != LOCKDOWN_E_SUCCESS) {
        fprintf(stderr, "QueryType failed, error code %d\n", lerr);
        result = EXIT_FAILURE;
        goto leave;
    } else {
        if (strcmp("com.apple.mobile.lockdown", type)) {
            fprintf(stderr, "WARNING: QueryType request returned '%s'\n", type);
        }
        free(type);
    }
    
    lerr = lockdownd_pair(client, NULL);
    if (lerr != LOCKDOWN_E_SUCCESS) {
        result = EXIT_FAILURE;
        print_error_message(lerr, udid);
        goto leave;
    }
    
    userpref_read_pair_record(udid, &pair_record);
    plist_dict_set_item(pair_record, "UDID", plist_new_string(udid));
    pair_record_get_host_id(pair_record, &host_id);
    
    lerr = lockdownd_start_session(client, host_id, &session_id, NULL);
    if (lerr != LOCKDOWN_E_SUCCESS) {
        result = EXIT_FAILURE;
        print_error_message(lerr, udid);
        goto leave;
    }
    
    lerr = lockdownd_set_value(client, "com.apple.mobile.wireless_lockdown", "EnableWifiDebugging", plist_new_bool(1));
    if (lerr != LOCKDOWN_E_SUCCESS) {
        result = EXIT_FAILURE;
        if (lerr == LOCKDOWN_E_UNKNOWN_ERROR) {
            fprintf(stderr, "ERROR: You must set up a passcode to enable wireless pairing.\n");
        } else {
            print_error_message(lerr, udid);
        }
        goto leave;
    }
    
    if (!plist_write_to_filename(pair_record, path, PLIST_FORMAT_XML)) {
        result = EXIT_FAILURE;
        goto leave;
    }
    plist_free(pair_record);
    if (strcmp(path, "/dev/stdout") != 0) {
        fprintf(stderr, "SUCCESS: wrote to %s\n", path);
    }
    
leave:
    if (session_id) {
        lockdownd_stop_session(client, session_id);
        free(session_id);
    }
    if (host_id) {
        free(host_id);
    }
    lockdownd_client_free(client);
    idevice_free(device);
    free(udid);
    free(path);

    return result;
}
