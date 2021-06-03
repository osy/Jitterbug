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
    @State private var appToLaunchAfterMount: JBApp?
    
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
                    
                } label: {
                    Label("Export Pairing", systemImage: "square.and.arrow.up")
                }
            }
        }.onAppear {
            if !appsLoaded {
                appsLoaded = true
                refreshAppsList()
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
    
    private func mountImage(_ supportImage: URL, signature supportImageSignature: URL) {
        main.backgroundTask(message: NSLocalizedString("Mounting disk image...", comment: "DeviceDetailsView")) {
            main.saveDiskImage(nil, signature: nil, forHostIdentifier: host.identifier)
            try host.mountImage(for: supportImage, signatureUrl: supportImageSignature)
            main.saveDiskImage(supportImage, signature: supportImageSignature, forHostIdentifier: host.identifier)
        } onComplete: {
            if let app = appToLaunchAfterMount {
                appToLaunchAfterMount = nil
                launchApplication(app)
            }
        }
    }
    
    private func launchApplication(_ app: JBApp) {
        var imageNotMounted = false
        main.backgroundTask(message: NSLocalizedString("Launching...", comment: "DeviceDetailsView")) {
            do {
                try host.launchApplication(app)
            } catch {
                let code = (error as NSError).code
                if code == kJBHostImageNotMounted {
                    imageNotMounted = true
                } else {
                    throw error
                }
            }
        } onComplete: {
            if imageNotMounted {
            }
        }
    }
}

struct DeviceDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceDetailsView(host: JBHostDevice(hostname: "", address: Data()))
    }
}
