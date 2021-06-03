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

struct AppItemView: View {
    @EnvironmentObject private var main: Main
    
    let app: JBApp
    let saved: Bool
    let hostName: String
    
    var body: some View {
        HStack {
            Button {
                if saved {
                    main.removeFavorite(appId: app.bundleIdentifier, forHostName: hostName)
                } else {
                    main.addFavorite(appId: app.bundleIdentifier, forHostName: hostName)
                }
            } label: {
                Label("Save", systemImage: saved ? "star.fill" : "star")
                    .foregroundColor(.accentColor)
            }
            IconView(data: app.icon)
            Text(app.bundleName)
            Spacer()
        }.buttonStyle(PlainButtonStyle())
    }
}

struct IconView: View {
    let data: Data
    
    var body: some View {
        #if canImport(UIKit)
        if let icon = UIImage(data: data) {
            Image(uiImage: icon)
                .resizable()
                .frame(width: 32, height: 32)
                .aspectRatio(contentMode: .fit)
        } else {
            EmptyView()
                .frame(width: 32, height: 32)
        }
        #elseif canImport(AppKit)
        if let icon = NSImage(data: data) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 32, height: 32)
                .aspectRatio(contentMode: .fit)
        } else {
            EmptyView()
                .frame(width: 32, height: 32)
        }
        #else
        #error("Cannot import UIKit or AppKit")
        #endif
    }
}

struct AppItemView_Previews: PreviewProvider {
    static var previews: some View {
        AppItemView(app: JBApp(), saved: true, hostName: "")
    }
}
