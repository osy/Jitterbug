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

struct ContentView: View {
    @EnvironmentObject private var main: Main
    
    var body: some View {
        ZStack {
            NavigationView {
                DeviceListView()
                    .listStyle(SidebarListStyle())
                    .frame(minWidth: 200, idealWidth: 200)
                Text("Connect an iOS device via USB to start pairing.")
            }.labelStyle(IconOnlyLabelStyle())
            if main.busy {
                BusyView(message: main.busyMessage)
            }
        }.frame(minWidth: 800, idealWidth: 800, minHeight: 400, idealHeight: 400)
        .alert(item: $main.alertMessage) { message in
            Alert(title: Text(message))
        }.onOpenURL { url in
            main.backgroundTask(message: NSLocalizedString("Importing pairing...", comment: "ContentView")) {
                try main.importPairing(url)
                Thread.sleep(forTimeInterval: 1)
            }
        }.disabled(main.busy)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
