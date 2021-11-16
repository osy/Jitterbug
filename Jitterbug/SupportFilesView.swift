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

struct SupportFilesView: View {
    @EnvironmentObject private var main: Main
    @State private var isImporterPresented: Bool = false
    
    var body: some View {
        NavigationView {
            Group {
                if main.supportImages.isEmpty {
                    VStack {
                        Text("No support files found.")
                            .font(.headline)
                        
                        Button {
                            isImporterPresented.toggle()
                        } label: {
                            Text("Import Support Files")
                                .padding()
                                .foregroundColor(.white)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                    }
                    
                } else {
                    Form {
                        ForEach(main.supportImages) { pairing in
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
            .navigationTitle("Support Files")
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
            .fileImporter(isPresented: $isImporterPresented, allowedContentTypes: [.dmg, .signature], allowsMultipleSelection: true, onCompletion: importFiles)
        }.navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func deleteAll(indicies: IndexSet) {
        var toDelete: [URL] = []
        for i in indicies {
            toDelete.append(main.supportImages[i])
        }
        main.backgroundTask(message: NSLocalizedString("Deleting support file...", comment: "PairingsView")) {
            for url in toDelete {
                try main.deleteSupportImage(url)
            }
        } onComplete: {
            main.supportImages.remove(atOffsets: indicies)
        }
    }
    
    private func importFiles(result: Result<[URL], Error>) {
        main.backgroundTask(message: NSLocalizedString("Importing support file...", comment: "PairingsView")) {
            let urls = try result.get()
            for url in urls {
                try main.importSupportImage(url)
            }
            Thread.sleep(forTimeInterval: 1)
        }
    }
}

struct SupportFilesView_Previews: PreviewProvider {
    static var previews: some View {
        SupportFilesView()
    }
}
