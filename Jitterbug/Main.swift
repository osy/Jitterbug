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

struct AlertMessage: Identifiable {
    var message: String
    public var id: String {
        message
    }
    
    init(_ message: String) {
        self.message = message
    }
}

class Main: ObservableObject {
    @Published var alertMessage: AlertMessage?
    @Published var busy: Bool = false
    @Published var busyMessage: String?
    
    @Published var pairings: [URL] = []
    @Published var supportImages: [URL] = []
    
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
        refreshPairings()
        refreshSupportImages()
    }
    
    func backgroundTask(message: String?, task: @escaping () throws -> Void) {
        DispatchQueue.main.async {
            self.busy = true
            self.busyMessage = message
        }
        DispatchQueue.global(qos: .userInitiated).async {
            defer {
                DispatchQueue.main.async {
                    self.busy = false
                    self.busyMessage = nil
                }
            }
            do {
                try task()
            } catch {
                DispatchQueue.main.async {
                    self.alertMessage = AlertMessage(error.localizedDescription)
                }
            }
        }
    }
    
    private func importFile(_ file: URL, toDirectory: URL) {
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
            DispatchQueue.main.async {
                self.refreshPairings()
                self.refreshSupportImages()
            }
        }
    }
    
    func importPairing(_ pairing: URL) {
        importFile(pairing, toDirectory: pairingsURL)
    }
    
    func importSupportImage(_ support: URL) {
        importFile(support, toDirectory: supportImagesURL)
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
    
    private func delete(_ file: URL, list: inout [URL]) {
        backgroundTask(message: NSLocalizedString("Deleting file...", comment: "Settings")) {
            try self.fileManager.removeItem(at: file)
        }
        list.removeAll { url in
            url.lastPathComponent == file.lastPathComponent
        }
    }
    
    func deletePairing(_ pairing: URL) {
        delete(pairing, list: &pairings)
    }
    
    func deleteSupportImage(_ supportImage: URL) {
        delete(supportImage, list: &supportImages)
    }
}
