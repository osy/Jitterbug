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

import UniformTypeIdentifiers

extension URL: Identifiable {
    public var id: URL {
        self
    }
}

extension String: Identifiable {
    public var id: String {
        self
    }
}

extension String: LocalizedError {
    public var errorDescription: String? {
        self
    }
}

extension UTType {
    public static let mobileDevicePairing = UTType(filenameExtension: "mobiledevicepairing", conformingTo: .data)!
    public static let dmg = UTType(filenameExtension: "dmg", conformingTo: .data)!
    public static let signature = UTType(filenameExtension: "signature", conformingTo: .data)!
}
