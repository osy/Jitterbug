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
}

struct DeviceDetailsView: View {
    @EnvironmentObject private var main: Main
    @State private var fileSelectType: FileType?
    @State private var selectedPairing: URL?
    @State private var selectedSupportImage: URL?
    
    let host: JBHostDevice
    
    var body: some View {
        List {
            Text("Hello World")
        }.navigationTitle(host.name)
        .listStyle(PlainListStyle())
        .popover(item: $fileSelectType) { type in
            switch type {
            case .pairing:
                FileSelectionView(urls: main.pairings, selectedUrl: $selectedPairing)
            case .supportImage:
                FileSelectionView(urls: main.supportImages, selectedUrl: $selectedSupportImage)
            }
        }.toolbar {
            HStack {
                Button {
                    fileSelectType = .pairing
                } label: {
                    Text("Pair")
                }
                Button {
                    
                } label: {
                    Text("Mount")
                }
            }
        }.onChange(of: selectedPairing) { url in
            guard let selected = url else {
                return
            }
            main.backgroundTask(message: NSLocalizedString("Loading pairing data...", comment: "DeviceDetailsView")) {
                try host.loadPairingData(for: selected)
            }
        }
    }
}

struct DeviceDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceDetailsView(host: JBHostDevice(hostname: "", address: Data()))
    }
}
