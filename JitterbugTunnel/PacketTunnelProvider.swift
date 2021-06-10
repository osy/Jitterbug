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

import NetworkExtension

class PacketTunnelProvider: NEPacketTunnelProvider {
    var tunnelDeviceIp: String = "10.8.0.1"
    var tunnelFakeIp: String = "10.8.0.2"
    var tunnelSubnetMask: String = "255.255.255.0"
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        if let deviceIp = options?["TunnelDeviceIP"] as? String {
            tunnelDeviceIp = deviceIp
        }
        if let fakeIp = options?["TunnelFakeIP"] as? String {
            tunnelFakeIp = fakeIp
        }
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: tunnelDeviceIp)
        let ipv4 = NEIPv4Settings(addresses: [tunnelDeviceIp], subnetMasks: [tunnelSubnetMask])
        ipv4.includedRoutes = [NEIPv4Route(destinationAddress: tunnelDeviceIp, subnetMask: tunnelSubnetMask)]
        ipv4.excludedRoutes = [.default()]
        settings.ipv4Settings = ipv4
        setTunnelNetworkSettings(settings) { error in
            if error == nil {
                self.readPackets()
            }
            completionHandler(error)
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Add code here to start the process of stopping the tunnel.
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Add code here to handle the message.
        if let handler = completionHandler {
            handler(messageData)
        }
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        // Add code here to get ready to sleep.
        completionHandler()
    }
    
    override func wake() {
        // Add code here to wake up.
    }
    
    private func readPackets() {
        packetFlow.readPackets { packets, protocols in
            var output: [Data] = []
            for (i, packet) in packets.enumerated() {
                let replace: Data
                if protocols[i].int32Value == AF_INET {
                    replace = packetReplaceIp(packet, self.tunnelDeviceIp, self.tunnelFakeIp, self.tunnelFakeIp, self.tunnelDeviceIp)
                } else {
                    replace = packet
                }
                output.append(replace)
            }
            self.packetFlow.writePackets(output, withProtocols: protocols)
            self.readPackets()
        }
    }
}
