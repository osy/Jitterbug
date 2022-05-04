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

struct PairingsView: View {
    @EnvironmentObject private var main: Main
    @State private var isImporterPresented: Bool = false
    
    var body: some View {
        NavigationView {
            Group {
                if main.pairings.isEmpty {
                    VStack {
                        Text("No pairings found.")
                            .font(.headline)
                        Button {
                            isImporterPresented.toggle()
                        } label: {
                            Text("Import Pairings")
                                .padding()
                                .foregroundColor(.white)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                    }
                } else {
                    Form {
                        ForEach(main.pairings) { pairing in
                            Text(pairing.lastPathComponent)
                                .lineLimit(1)
                        }.onDelete { indexSet in
                            deleteAll(indicies: indexSet)
                        }
                        Section {
                            Button("Import More...") {
                                isImporterPresented.toggle()
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Pairings")
            .toolbar {
                HStack {
                    Button(action: { isImporterPresented.toggle() }, label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                            .labelStyle(IconOnlyLabelStyle())
                    })
                    if !main.pairings.isEmpty {
                        EditButton()
                    }
                }
            }
            .fileImporter(isPresented: $isImporterPresented, allowedContentTypes: [.mobileDevicePairing], onCompletion: importFile)
        }.navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func deleteAll(indicies: IndexSet) {
        var toDelete: [URL] = []
        for i in indicies {
            toDelete.append(main.pairings[i])
        }
        main.backgroundTask(message: NSLocalizedString("Deleting pairing...", comment: "PairingsView")) {
            for url in toDelete {
                try main.deletePairing(url)
            }
        } onComplete: {
            main.pairings.remove(atOffsets: indicies)
        }
    }
    
    private func importFile(result: Result<URL, Error>) {
        main.backgroundTask(message: NSLocalizedString("Importing pairing...", comment: "PairingsView")) {
            let url = try result.get()
            try main.importPairing(url)
            Thread.sleep(forTimeInterval: 1)
        }
    }
}

struct PairingsView_Previews: PreviewProvider {
    static var previews: some View {
        PairingsView()
    }
}
