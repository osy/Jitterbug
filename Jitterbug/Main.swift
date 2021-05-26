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

import Combine

class Main: ObservableObject {
    @Published var alertMessage: String?
    @Published var busy: Bool = false
    @Published var busyMessage: String?
    
    @Published var scanning: Bool = false
    @Published var savedHosts: [JBHostDevice] = []
    @Published var foundHosts: [JBHostDevice] = []
    
    @Published var pairings: [URL] = []
    @Published var supportImages: [URL] = []
    
    private let hostFinder = HostFinder()
    
    private var fileManager: FileManager {
        FileManager.default
    }
    
    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var pairingsURL: URL {
        documentsURL.appendingPathComponent("Pairings", isDirectory: true)
    }
    
    private var supportImagesURL: URL {
        documentsURL.appendingPathComponent("SupportImages", isDirectory: true)
    }
    
    init() {
        hostFinder.delegate = self
        refreshPairings()
        refreshSupportImages()
    }
    
    func backgroundTask(message: String?, task: @escaping () throws -> Void, onComplete: @escaping () -> Void = {}) {
        DispatchQueue.main.async {
            self.busy = true
            self.busyMessage = message
        }
        DispatchQueue.global(qos: .userInitiated).async {
            defer {
                DispatchQueue.main.async {
                    self.busy = false
                    self.busyMessage = nil
                    onComplete()
                }
            }
            do {
                try task()
            } catch {
                DispatchQueue.main.async {
                    self.alertMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - File management
    
    private func importFile(_ file: URL, toDirectory: URL, onComplete: @escaping () -> Void) throws {
        _ = file.startAccessingSecurityScopedResource()
        defer {
            file.stopAccessingSecurityScopedResource()
        }
        let name = file.lastPathComponent
        let dest = toDirectory.appendingPathComponent(name)
        backgroundTask(message: NSLocalizedString("Importing file...", comment: "Settings")) {
            if !self.fileManager.fileExists(atPath: toDirectory.path) {
                try self.fileManager.createDirectory(at: toDirectory, withIntermediateDirectories: false)
            }
            if self.fileManager.fileExists(atPath: dest.path) {
                try self.fileManager.removeItem(at: dest)
            }
            try self.fileManager.copyItem(at: file, to: dest)
        } onComplete: {
            onComplete()
        }
    }
    
    func importPairing(_ pairing: URL) throws {
        try importFile(pairing, toDirectory: pairingsURL) {
            self.refreshPairings()
        }
    }
    
    func importSupportImage(_ support: URL) throws {
        try importFile(support, toDirectory: supportImagesURL) {
            self.refreshSupportImages()
        }
    }
    
    private func refresh(directory: URL, list: inout [URL]) {
        guard let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return
        }
        let filtered = contents.filter { newFile in
            !list.contains(newFile)
        }
        if !filtered.isEmpty {
            list = contents
        }
    }
    
    func refreshPairings() {
        refresh(directory: pairingsURL, list: &pairings)
    }
    
    func refreshSupportImages() {
        refresh(directory: supportImagesURL, list: &supportImages)
    }
    
    func deletePairing(_ pairing: URL) throws {
        try self.fileManager.removeItem(at: pairing)
    }
    
    func deleteSupportImage(_ supportImage: URL) throws {
        try self.fileManager.removeItem(at: supportImage)
    }
    
    // MARK: - Devices
    func startScanning() {
        hostFinder.startSearch()
    }
    
    func stopScanning() {
        hostFinder.stopSearch()
    }
    
    func saveHost(_ host: JBHostDevice) {
        savedHosts.append(host)
        foundHosts.removeAll { found in
            found.hostname == host.hostname
        }
    }
    
    func removeSavedHost(_ host: JBHostDevice) {
        savedHosts.removeAll { saved in
            saved.hostname == host.hostname
        }
        foundHosts.append(host)
    }
}

extension Main: HostFinderDelegate {
    func hostFinderWillStart() {
        DispatchQueue.main.async {
            self.scanning = true
        }
    }
    
    func hostFinderDidStop() {
        DispatchQueue.main.async {
            self.scanning = false
        }
    }
    
    func hostFinderError(_ error: String) {
        DispatchQueue.main.async {
            self.alertMessage = error
        }
    }
    
    func hostFinderNewHost(_ host: String, name: String?, address: Data) {
        DispatchQueue.main.async {
            for hostDevice in self.savedHosts {
                if hostDevice.hostname == host {
                    hostDevice.updateAddress(address)
                    if hostDevice.name == host, let newName = name {
                        hostDevice.name = newName
                    }
                    hostDevice.discovered = true
                    self.objectWillChange.send()
                    return
                }
            }
            for hostDevice in self.foundHosts {
                if hostDevice.hostname == host {
                    hostDevice.updateAddress(address)
                    hostDevice.name = name ?? host
                    hostDevice.discovered = true
                    self.objectWillChange.send()
                    return
                }
            }
            let newHost = JBHostDevice(hostname: host, address: address)
            if let newName = name {
                newHost.name = newName
            }
            newHost.discovered = true
            self.foundHosts.append(newHost)
        }
    }
    
    func hostFinderRemoveHost(_ host: String) {
        DispatchQueue.main.async {
            for hostDevice in self.savedHosts {
                if hostDevice.hostname == host {
                    hostDevice.discovered = false
                    self.objectWillChange.send()
                }
            }
            self.foundHosts.removeAll { hostDevice in
                hostDevice.hostname == host
            }
        }
    }
}
