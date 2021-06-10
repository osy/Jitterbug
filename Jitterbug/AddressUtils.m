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

#include "AddressUtils.h"
#include <arpa/inet.h>

BOOL addressIsLoopback(NSData * _Nonnull data) {
    struct sockaddr_storage address = {0};
    struct sockaddr_in *ipv4_addr = (struct sockaddr_in *)&address;
    struct sockaddr_in6 *ipv6_addr = (struct sockaddr_in6 *)&address;
    
    [data getBytes:&address length:(data.length > sizeof(address) ? sizeof(address) : data.length)];
    if (address.ss_family == PF_INET) {
        return ipv4_addr->sin_addr.s_addr == htonl(INADDR_LOOPBACK);
    } else if (address.ss_family == PF_INET6) {
        return IN6_IS_ADDR_LOOPBACK(&ipv6_addr->sin6_addr);
    } else {
        return NO;
    }
}

NSData * _Nonnull addressIPv4StringToData(NSString * _Nonnull ascii) {
    struct sockaddr_in addr = {0};
    addr.sin_len = sizeof(addr);
    addr.sin_family = AF_INET;
    inet_aton(ascii.UTF8String, &addr.sin_addr);
    return [NSData dataWithBytes:&addr length:sizeof(addr)];
}

NSData * _Nonnull packetReplaceIp(NSData * _Nonnull data, NSString * _Nonnull sourceSearch, NSString * _Nonnull sourceReplace, NSString * _Nonnull destSearch, NSString * _Nonnull destReplace) {
    struct in_addr sourceSearchIp = {0};
    struct in_addr sourceReplaceIp = {0};
    struct in_addr sourcePacketIp = {0};
    struct in_addr destSearchIp = {0};
    struct in_addr destReplaceIp = {0};
    struct in_addr destPacketIp = {0};
    
    inet_aton(sourceSearch.UTF8String, &sourceSearchIp);
    inet_aton(sourceReplace.UTF8String, &sourceReplaceIp);
    inet_aton(destSearch.UTF8String, &destSearchIp);
    inet_aton(destReplace.UTF8String, &destReplaceIp);
    if (data.length < 20) {
        return data;
    }
    [data getBytes:&sourcePacketIp range:NSMakeRange(12, 4)];
    [data getBytes:&destPacketIp range:NSMakeRange(16, 4)];
    if (sourceSearchIp.s_addr != sourcePacketIp.s_addr && destSearchIp.s_addr != destPacketIp.s_addr) {
        return data;
    }
    NSMutableData *copy = [data mutableCopy];
    if (sourceSearchIp.s_addr == sourcePacketIp.s_addr) {
        [copy replaceBytesInRange:NSMakeRange(12, 4) withBytes:&sourceReplaceIp];
    }
    if (destSearchIp.s_addr == destPacketIp.s_addr) {
        [copy replaceBytesInRange:NSMakeRange(16, 4) withBytes:&destReplaceIp];
    }
    return copy;
}
