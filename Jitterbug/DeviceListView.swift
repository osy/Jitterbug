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

import SwiftUI

struct DeviceListView: View {
    @EnvironmentObject private var main: Main
    @State private var showIpAlert: Bool = false
    
    var body: some View {
        List {
            if !main.savedHosts.isEmpty {
                Section(header: Text("Saved")) {
                    ForEach(main.savedHosts) { host in
                        NavigationLink(destination: DeviceDetailsView(host: host)) {
                            HostView(host: host, saved: true)
                                .foregroundColor(host.discovered ? .primary : .secondary)
                        }
                    }
                }
            }
            Section(header: Text("Discovered")) {
                ForEach(main.foundHosts) { host in
                    NavigationLink(destination: DeviceDetailsView(host: host)) {
                        HostView(host: host, saved: false)
                    }
                }
            }
        }.navigationTitle("Devices")
        .toolbar {
            Button(action: { showIpAlert.toggle() }, label: {
                Label("Add", systemImage: "plus")
            })
        }
        .listStyle(PlainListStyle())
        .labelStyle(IconOnlyLabelStyle())
        .onAppear {
            main.startScanning()
        }
        .onDisappear {
            main.stopScanning()
        }
    }
}

struct HostView: View {
    @EnvironmentObject private var main: Main
    
    let host: JBHostDevice
    let saved: Bool
    
    var body: some View {
        HStack {
            Button {
                if saved {
                    main.removeSavedHost(host)
                } else {
                    main.saveHost(host)
                }
            } label: {
                Label("Save", systemImage: saved ? "star.fill" : "star")
                    .foregroundColor(.accentColor)
            }
            switch (host.hostDeviceType) {
            case .typeUnknown:
                Label("Unknown", systemImage: "questionmark")
            case .typeiPhone:
                Label("iPhone", systemImage: "apps.iphone")
            case .typeiPad:
                Label("iPhone", systemImage: "apps.ipad")
            @unknown default:
                Label("Unknown", systemImage: "questionmark")
            }
            Text(host.name)
            Spacer()
        }.labelStyle(IconOnlyLabelStyle())
        .buttonStyle(PlainButtonStyle())
    }
}

struct DeviceListView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceListView()
    }
}
