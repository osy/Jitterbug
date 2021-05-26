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

struct FileSelectionView: View {
    let urls: [URL]
    @Binding var selectedUrl: URL?
    let title: Text
    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
    
    var body: some View {
        NavigationView {
            List {
                ForEach(urls) { url in
                    Button {
                        presentationMode.wrappedValue.dismiss()
                        selectedUrl = url
                    } label: {
                        Text(url.lastPathComponent)
                            .lineLimit(1)
                    }
                }
            }.navigationTitle(title)
            .navigationViewStyle(StackNavigationViewStyle())
            .listStyle(PlainListStyle())
            .toolbar {
                Button {
                    presentationMode.wrappedValue.dismiss()
                    selectedUrl = nil
                } label: {
                    Text("Cancel")
                }
            }
        }
    }
}

struct FileSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        FileSelectionView(urls: [
                            .init(fileURLWithPath: "/test1"),
                            .init(fileURLWithPath: "/test2"),
                            .init(fileURLWithPath: "/test3")
        ], selectedUrl: .constant(nil), title: Text("Hi"))
    }
}
