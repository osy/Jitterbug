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

fileprivate enum FileType: Int, Identifiable {
    var id: Int {
        self.rawValue
    }
    
    case pairing
    case supportImage
    case supportImageSignature
}

struct DeviceDetailsView: View {
    @EnvironmentObject private var main: Main
    @State private var fileSelectType: FileType?
    @State private var selectedPairing: URL?
    @State private var selectedSupportImage: URL?
    @State private var selectedSupportImageSignature: URL?
    @State private var apps: [JBApp] = []
    
    let host: JBHostDevice
    
    var body: some View {
        Group {
            if host.udid == nil {
                Text("Not paired.")
                    .font(.headline)
            } else if apps.isEmpty {
                Text("No apps found on device.")
            } else {
                List {
                    ForEach(apps) { app in
                        Button {
                            launchApplication(app)
                        } label: {
                            AppItem(app: app, saved: false)
                        }
                    }
                }
            }
        }.navigationTitle(host.name)
        .listStyle(PlainListStyle())
        .sheet(item: $fileSelectType) { type in
            switch type {
            case .pairing:
                FileSelectionView(urls: main.pairings, selectedUrl: $selectedPairing, title: Text("Select Pairing"))
            case .supportImage:
                FileSelectionView(urls: main.supportImages, selectedUrl: $selectedSupportImage, title: Text("Select Developer Image"))
            case .supportImageSignature:
                FileSelectionView(urls: main.supportImages, selectedUrl: $selectedSupportImageSignature, title: Text("Select Developer Image Signature"))
            }
        }.toolbar {
            HStack {
                Button {
                    fileSelectType = .pairing
                } label: {
                    Text("Pair")
                }
                Button {
                    fileSelectType = .supportImage
                } label: {
                    Text("Mount")
                }.disabled(host.udid == nil)
            }
        }.onChange(of: selectedPairing) { url in
            guard let selected = url else {
                return
            }
            main.backgroundTask(message: NSLocalizedString("Loading pairing data...", comment: "DeviceDetailsView")) {
                try host.loadPairingData(for: selected)
            } onComplete: {
                selectedPairing = nil
                refreshAppsList()
            }
        }.onChange(of: selectedSupportImage) { url in
            guard let supportImage = url else {
                return
            }
            let maybeSig = supportImage.appendingPathExtension("signature")
            if FileManager.default.fileExists(atPath: maybeSig.path) {
                selectedSupportImageSignature = maybeSig
            } else {
                fileSelectType = .supportImageSignature
            }
        }.onChange(of :selectedSupportImageSignature) { url in
            guard let supportImage = selectedSupportImage else {
                return
            }
            guard let supportImageSignature = url else {
                return
            }
            main.backgroundTask(message: NSLocalizedString("Mounting disk image...", comment: "DeviceDetailsView")) {
                try host.mountImage(for: supportImage, signatureUrl: supportImageSignature)
            } onComplete: {
                selectedSupportImage = nil
                selectedSupportImageSignature = nil
            }
        }
    }
    
    private func refreshAppsList() {
        main.backgroundTask(message: NSLocalizedString("Querying device...", comment: "DeviceDetailsView")) {
            try host.updateInfo()
            apps = try host.installedApps()
        }
    }
    
    private func launchApplication(_ app: JBApp) {
        main.backgroundTask(message: NSLocalizedString("Launching...", comment: "DeviceDetailsView")) {
            do {
                try host.launchApplication(app)
            } catch {
                let code = (error as NSError).code
                guard code == kJBHostImageNotMounted else {
                    throw error
                }
                DispatchQueue.main.async {
                    self.handleImageNotMounted()
                }
            }
        }
    }
    
    private func handleImageNotMounted() {
        main.alertMessage = NSLocalizedString("Developer image is not mounted. You need DeveloperDiskImage.dmg and DeveloperDiskImage.dmg.signature imported in Support Files.", comment: "DeviceDetailsView")
        fileSelectType = .supportImage
    }
}

struct AppItem: View {
    let app: JBApp
    let saved: Bool
    
    var body: some View {
        HStack {
            Button {
            } label: {
                Label("Save", systemImage: saved ? "star.fill" : "star")
                    .foregroundColor(.accentColor)
            }
            if let icon = UIImage(data: app.icon) {
                Image(uiImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
                    .aspectRatio(contentMode: .fit)
            } else {
                EmptyView()
                    .frame(width: 32, height: 32)
            }
            Text(app.bundleName)
            Spacer()
        }.buttonStyle(PlainButtonStyle())
    }
}

struct DeviceDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceDetailsView(host: JBHostDevice(hostname: "", address: Data()))
    }
}
