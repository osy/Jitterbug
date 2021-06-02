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

private var shortcutHostName: String?

@main
struct JitterbugApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject var main = Main()
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(main)
        }
        .onChange(of: scenePhase) { newScenePhase in
            if newScenePhase == .active {
                main.selectedHostName = shortcutHostName
                shortcutHostName = nil
            } else {
                main.archiveSavedHosts()
                #if os(iOS)
                self.updateQuickActions()
                #endif
            }
        }
    }
    
    #if os(iOS)
    private func updateQuickActions() {
        let application = UIApplication.shared
        application.shortcutItems = main.savedHosts.map({ device -> UIApplicationShortcutItem in
            var icon: UIApplicationShortcutIcon?
            switch device.hostDeviceType {
            case .typeiPhone:
                icon = UIApplicationShortcutIcon(systemImageName: "iphone")
            case .typeiPad:
                icon = UIApplicationShortcutIcon(systemImageName: "ipad")
            default:
                icon = nil
            }
            let userInfo: [String: NSSecureCoding] = [
                "hostname": device.hostname as NSSecureCoding,
            ]
            return UIApplicationShortcutItem(type: "connectHost", localizedTitle: device.name, localizedSubtitle: nil, icon: icon, userInfo: userInfo)
        })
    }
    
    class AppDelegate: NSObject, UIApplicationDelegate {
        func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
            let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
            config.delegateClass = SceneDelegate.self
            return config
        }
    }
    
    class SceneDelegate: NSObject, UIWindowSceneDelegate {
        func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
            if let shortcutItem = connectionOptions.shortcutItem {
                shortcutHostName = shortcutItem.userInfo?["hostname"] as? String
            }
        }
        
        func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
            shortcutHostName = shortcutItem.userInfo?["hostname"] as? String
        }
    }
    #endif
}
