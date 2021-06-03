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

class Main: NSObject, ObservableObject {
    @Published var alertMessage: String?
    @Published var busy: Bool = false
    @Published var busyMessage: String?
    
    @Published var scanning: Bool = false
    @Published var savedHosts: [JBHostDevice] = []
    @Published var foundHosts: [JBHostDevice] = []
    @Published var selectedHostName: String?
    
    @Published var pairings: [URL] = []
    @Published var supportImages: [URL] = []
    
    private let hostFinder = HostFinder()
    
    private var storage: UserDefaults {
        UserDefaults.standard
    }
    
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
    
    override init() {
        super.init()
        hostFinder.delegate = self
        refreshPairings()
        refreshSupportImages()
        unarchiveSavedHosts()
    }
    
    func backgroundTask(message: String?, task: @escaping () throws -> Void, onComplete: @escaping () -> Void = {}) {
        DispatchQueue.main.async {
            self.busy = true
            self.busyMessage = message
            DispatchQueue.global(qos: .background).async {
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
    }
    
    // MARK: - File management
    
    private func importFile(_ file: URL, toDirectory: URL, onComplete: @escaping () -> Void) throws {
        let name = file.lastPathComponent
        let dest = toDirectory.appendingPathComponent(name)
        _ = file.startAccessingSecurityScopedResource()
        defer {
            file.stopAccessingSecurityScopedResource()
        }
        if !self.fileManager.fileExists(atPath: toDirectory.path) {
            try self.fileManager.createDirectory(at: toDirectory, withIntermediateDirectories: false)
        }
        if self.fileManager.fileExists(atPath: dest.path) {
            try self.fileManager.removeItem(at: dest)
        }
        try self.fileManager.copyItem(at: file, to: dest)
        onComplete()
    }
    
    func importPairing(_ pairing: URL) throws {
        try importFile(pairing, toDirectory: pairingsURL) {
            DispatchQueue.main.async {
                self.refreshPairings()
            }
        }
    }
    
    func importSupportImage(_ support: URL) throws {
        try importFile(support, toDirectory: supportImagesURL) {
            DispatchQueue.main.async {
                self.refreshSupportImages()
            }
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
    
    // MARK: - Save and restore
    func archiveSavedHosts() {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: savedHosts, requiringSecureCoding: false) else {
            NSLog("Error archiving hosts")
            return
        }
        storage.set(data, forKey: "SavedHosts")
    }
    
    func unarchiveSavedHosts() {
        guard let data = storage.data(forKey: "SavedHosts") else {
            return
        }
        guard let hosts = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [JBHostDevice] else {
            NSLog("Error unarchiving hosts")
            return
        }
        savedHosts = hosts
    }
    
    private func saveValue(_ value: Any, forKey key: String, forHostName hostName: String) {
        var database = storage.dictionary(forKey: "Hosts") ?? [:]
        var hostEntry: [String : Any] = database[hostName] as? [String : Any] ?? [:]
        hostEntry[key] = value
        database[hostName] = hostEntry
        storage.set(database, forKey: "Hosts")
    }
    
    private func loadValue(forKey key: String, forHostName hostName: String) -> Any? {
        guard let database = storage.dictionary(forKey: "Hosts") else {
            return nil
        }
        guard let hostEntry = database[hostName] as? [String : Any] else {
            return nil
        }
        return hostEntry[key]
    }
    
    func savePairing(_ pairing: URL?, forHostName hostName: String) {
        let file = pairing?.lastPathComponent ?? ""
        saveValue(file, forKey: "Pairing", forHostName: hostName)
    }
    
    func loadPairing(forHostName hostName: String) -> URL? {
        guard let file = loadValue(forKey: "Pairing", forHostName: hostName) as? String else {
            return nil
        }
        guard file.count > 0 else {
            return nil
        }
        return pairingsURL.appendingPathComponent(file)
    }
    
    func saveDiskImage(_ diskImage: URL?, signature: URL?, forHostName hostName: String) {
        let diskImageFile = diskImage?.lastPathComponent ?? ""
        let diskImageSignatureFile = signature?.lastPathComponent ?? ""
        saveValue(diskImageFile, forKey: "DiskImage", forHostName: hostName)
        saveValue(diskImageSignatureFile, forKey: "DiskImageSignature", forHostName: hostName)
    }
    
    func loadDiskImage(forHostName hostName: String) -> URL? {
        guard let diskImageFile = loadValue(forKey: "DiskImage", forHostName: hostName) as? String else {
            return nil
        }
        guard diskImageFile.count > 0 else {
            return nil
        }
        return supportImagesURL.appendingPathComponent(diskImageFile)
    }
    
    func loadDiskImageSignature(forHostName hostName: String) -> URL? {
        guard let diskImageSignatureFile = loadValue(forKey: "DiskImageSignature", forHostName: hostName) as? String else {
            return nil
        }
        guard diskImageSignatureFile.count > 0 else {
            return nil
        }
        return supportImagesURL.appendingPathComponent(diskImageSignatureFile)
    }
    
    func addFavorite(appId: String, forHostName hostName: String) {
        var favorites = loadValue(forKey: "Favorites", forHostName: hostName) as? [String] ?? []
        if !favorites.contains(where: { favorite in
            favorite == appId
        }) {
            favorites.append(appId)
        }
        saveValue(favorites, forKey: "Favorites", forHostName: hostName)
        self.objectWillChange.send()
    }
    
    func removeFavorite(appId: String, forHostName hostName: String) {
        var favorites = loadValue(forKey: "Favorites", forHostName: hostName) as? [String] ?? []
        favorites.removeAll { favorite in
            favorite == appId
        }
        saveValue(favorites, forKey: "Favorites", forHostName: hostName)
        self.objectWillChange.send()
    }
    
    func getFavorites(forHostName hostName: String) -> [String] {
        return loadValue(forKey: "Favorites", forHostName: hostName) as? [String] ?? []
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

extension Main {
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
    
    private func hostFinderNewHost(identifier: String, name: String?, onFound: (JBHostDevice) -> Void) -> Bool {
        for hostDevice in self.savedHosts {
            if hostDevice.identifier == identifier {
                onFound(hostDevice)
                if hostDevice.name == identifier, let newName = name {
                    hostDevice.name = newName
                }
                hostDevice.discovered = true
                self.objectWillChange.send()
                return true
            }
        }
        for hostDevice in self.foundHosts {
            if hostDevice.identifier == identifier {
                onFound(hostDevice)
                hostDevice.name = name ?? identifier
                hostDevice.discovered = true
                self.objectWillChange.send()
                return true
            }
        }
        return false
    }
    
    func hostFinderRemove(identifier: String) {
        for hostDevice in self.savedHosts {
            if hostDevice.identifier == identifier {
                hostDevice.discovered = false
                self.objectWillChange.send()
            }
        }
        self.foundHosts.removeAll { hostDevice in
            hostDevice.identifier == identifier
        }
    }
}

#if os(macOS)
@objc extension Main: HostFinderDelegate {
    func hostFinderNewUdid(_ udid: String, address: Data?) {
        DispatchQueue.main.async {
            if !self.hostFinderNewHost(identifier: udid, name: nil, onFound: { hostDevice in
                if let addr = address {
                    hostDevice.updateAddress(addr)
                }
            }) {
                let newHost = JBHostDevice(uuid: udid)
                newHost.discovered = true
                self.foundHosts.append(newHost)
            }
        }
    }
    
    func hostFinderRemoveUdid(_ udid: String) {
        DispatchQueue.main.async {
            self.hostFinderRemove(identifier: udid)
        }
    }
}
#else
extension Main: HostFinderDelegate {
    func hostFinderNewHost(_ host: String, name: String?, address: Data) {
        DispatchQueue.main.async {
            if !self.hostFinderNewHost(identifier: host, name: name, onFound: { hostDevice in
                hostDevice.updateAddress(address)
            }) {
                let newHost = JBHostDevice(hostname: host, address: address)
                if let newName = name {
                    newHost.name = newName
                }
                newHost.discovered = true
                self.foundHosts.append(newHost)
            }
        }
    }
    
    func hostFinderRemoveHost(_ host: String) {
        DispatchQueue.main.async {
            self.hostFinderRemove(identifier: host)
        }
    }
}
#endif
