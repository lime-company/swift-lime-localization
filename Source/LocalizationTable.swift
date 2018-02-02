//
// Copyright 2018 Lime - HighTech Solutions s.r.o.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions
// and limitations under the License.
//

import Foundation

/// The LocalizationTable describes one localization string table (for any language) stored in
/// one specific bundle.
public class LocalizationTable {
	
	/// A table name. Typically, this is file name without a ".strings" extension. For example "Localizable"
	public let name: String
	
	/// A bundle where the localization file is stored
	public let bundle: Bundle
	
	/// Constructor for creation table entry with exact table name and (optional) bundle.
	public init(_ name: String, _ bundle: Bundle = Bundle.main) {
		self.name = name
		self.bundle = bundle
	}
	
	/// Returns object representing default string table in main bundle.
	public static func defaultTable() -> LocalizationTable {
		return LocalizationTable("Localizable")
	}
}
