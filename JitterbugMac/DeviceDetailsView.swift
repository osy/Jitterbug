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

struct DeviceDetailsView: View {
    @EnvironmentObject private var main: Main
    @State private var appsLoaded: Bool = false
    @State private var apps: [JBApp] = []
    @State private var fileImporterPresented: Bool = false
    @State private var shareFilePresented: Bool = false
    @State private var shareFileUrl: URL?
    
    let host: JBHostDevice
    
    private var favoriteApps: [JBApp] {
        let favorites = main.getFavorites(forHostIdentifier: host.identifier)
        return apps.filter { app in
            favorites.contains { favorite in
                app.bundleIdentifier == favorite
            }
        }
    }
    
    private var notFavoriteApps: [JBApp] {
        let favorites = main.getFavorites(forHostIdentifier: host.identifier)
        return apps.filter { app in
            !favorites.contains { favorite in
                app.bundleIdentifier == favorite
            }
        }
    }
    
    var body: some View {
        Group {
            if !host.isConnected {
                Text("Not paired.")
                    .font(.headline)
            } else if apps.isEmpty {
                Text("No apps found on device.")
                    .font(.headline)
            } else {
                List {
                    if !main.getFavorites(forHostIdentifier: host.identifier).isEmpty {
                        Section(header: Text("Favorites")) {
                            ForEach(favoriteApps) { app in
                                HStack {
                                    AppItemView(app: app, saved: true, hostIdentifier: host.identifier)
                                    Spacer()
                                    Button {
                                        launchApplication(app)
                                    } label: {
                                        Text("Launch")
                                    }
                                }
                            }
                        }
                    }
                    Section(header: Text("Installed")) {
                        ForEach(notFavoriteApps) { app in
                            HStack {
                                AppItemView(app: app, saved: false, hostIdentifier: host.identifier)
                                Spacer()
                                Button {
                                    launchApplication(app)
                                } label: {
                                    Text("Launch")
                                }
                            }
                        }
                    }
                }
            }
        }.navigationTitle(host.name)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    refreshAppsList()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                Button {
                    fileImporterPresented.toggle()
                } label: {
                    Label("Mount Image", systemImage: "externaldrive.badge.plus")
                }.disabled(!host.isConnected)
                ZStack {
                    Button {
                        exportPairing()
                    } label: {
                        Label("Export Pairing", systemImage: "square.and.arrow.up")
                    }.disabled(!host.isConnected)
                    SharingsPicker(isPresented: $shareFilePresented, sharingItems: [shareFileUrl as Any])
                }
            }
        }.onAppear {
            if !appsLoaded {
                appsLoaded = true
                refreshAppsList()
            }
        }.fileImporter(isPresented: $fileImporterPresented, allowedContentTypes: [.dmg]) { result in
            if let url = try? result.get() {
                mountImage(url)
            }
        }
    }
    
    private func refreshAppsList() {
        main.backgroundTask(message: NSLocalizedString("Querying installed apps...", comment: "DeviceDetailsView")) {
            try host.startLockdown()
            try host.updateInfo()
            apps = try host.installedApps()
            main.archiveSavedHosts()
        }
    }
    
    private func mountImage(_ supportImage: URL) {
        main.backgroundTask(message: NSLocalizedString("Mounting disk image...", comment: "DeviceDetailsView")) {
            let supportImageSignature = supportImage.appendingPathExtension("signature")
            main.saveDiskImage(nil, signature: nil, forHostIdentifier: host.identifier)
            try host.mountImage(for: supportImage, signatureUrl: supportImageSignature)
            main.saveDiskImage(supportImage, signature: supportImageSignature, forHostIdentifier: host.identifier)
        }
    }
    
    private func launchApplication(_ app: JBApp) {
        main.backgroundTask(message: NSLocalizedString("Launching...", comment: "DeviceDetailsView")) {
            try host.launchApplication(app)
        }
    }
    
    private func exportPairing() {
        main.backgroundTask(message: NSLocalizedString("Exporting...", comment: "DeviceDetailsView")) {
            let data = try host.exportPairing()
            let path = FileManager.default.temporaryDirectory.appendingPathComponent("\(host.udid).mobiledevicepairing")
            try data.write(to: path)
            DispatchQueue.main.async {
                shareFileUrl = path
                shareFilePresented.toggle()
            }
        }
    }
}

struct DeviceDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceDetailsView(host: JBHostDevice(hostname: "", address: Data()))
    }
}
