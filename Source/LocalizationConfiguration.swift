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

/// A LocalizationConfiguration object contains various runtime parameters
/// which affects functionality of LocalizationProvider.
public class LocalizationConfiguration: NSObject {
	
	/// Defines default language when current system language is not supported in your
	/// string tables. LocalizationProvider uses following resolving rules if
	/// initial language is not set:
	///
	///	1. if system language is supported in string tables, then will use system language.
	///	2. if it's possible to map system language to some supported language, then will use language mapping.
	///	3. if defaultLanguage is set and supported in string tables, then will use defaultLanguage
	///	4. if 'Localization native development region' is supported in string tables, then will use this language
	///	5. otherwise will use first available language in string table.
	///
	/// If you're using "Base" localization, you should set defaultLanguage to language identifier, which represents
	/// your primary language.
	public var defaultLanguage: String
	
	/// Defines mapping from one language to another, supported in string tables.
	/// This is useful when your string tables covers only few languages but these
	/// are understandable in another target countries.
	///
	/// A typical example is Czechs versus Slovakians. If you have localization for czech
	/// language then you can define mapping from "sk" to "cz" because people in
	/// these countries would understand each other. Then the people using Slovak system
	/// language will see your application in Czech localization.
	public var languageMappings: [String:String]?
	
	/// Affects order of language identifiers
	public var preferedLanguages: [String]?
	
	/// A list of string tables which will needs to be loaded during the language change.
	/// You can define multiple string tables from different bundles, but the order of tables
	/// affects how the final translation table is constructed. The LocalizationProvider is loading
	/// tables in this predefined order and therefore the keys from later loaded tables overrides
	/// previously defined localizations.
	public var stringTables: [LocalizationTable]
	
	/// A prefix used when the localization for key is not localized. For exampe, if "My Key" has
	/// no translation in current language, then the "### My Key" is returned as localized string.
	/// This allows you to easily look for missing localizations in your application.
	public var missingLocalizationPrefix: String
	
	/// A ked to UserDefaults storage, where the actual user's prefered language configuration is stored.
	public var settingsKey: String
	
	/// You can define prefix for string table keys, used for language names localization. The value
	/// affects strings produced in LocalizationProvider.localizedAvailableLanguages property.
	/// Your string tables must define all these localizations. For exaple, you have to define
	/// following localization strings for default confing:
	///    "language.en" = "English";
	///    "language.cs" = "Čeština";
	///    "language.es" = "Español";
	public var prefixForLocalizedLanguageNames: String
	
	
	/// Default constructor
	public override init() {
		self.defaultLanguage = "en"
		self.stringTables = [ LocalizationTable.defaultTable() ]
		self.missingLocalizationPrefix = "### "
		self.settingsKey = "LimeLocalization.UserLanguage"
		self.prefixForLocalizedLanguageNames = "language."
	}
	
	/// Private copy constructor
	internal init(copyFrom: LocalizationConfiguration) {
		self.defaultLanguage = copyFrom.defaultLanguage
		self.languageMappings = copyFrom.languageMappings
		self.preferedLanguages = copyFrom.preferedLanguages
		self.stringTables = copyFrom.stringTables
		self.missingLocalizationPrefix = copyFrom.missingLocalizationPrefix
		self.settingsKey = copyFrom.settingsKey
		self.prefixForLocalizedLanguageNames = copyFrom.prefixForLocalizedLanguageNames
	}
	
	/// Static method returns default configuration, which is typically used for the LocalizationProvider.shared
	/// instance initialization. If the default configuration is not suitable for your purposes, then you can
	/// extend `LocalizationConfiguration` class with `LocalizationSharedConfiguration` protocol.
	public static func sharedConfiguration() -> LocalizationConfiguration {
		// Try to access class selector +configurationForSharedInstance
		if (self as AnyClass).responds(to: NSSelectorFromString("configurationForSharedInstance")) {
			// This is fun. Normally, #selector(configurationForSharedInstance) swift syntax doesn't work,
			// because the compiler is not able to resolve selector which is not implemented in the code yet.
			// This may be implemented in your extension, but we don't know this information in the time of compilation.
			// So, the interesting part is, that it is still "safe" to call `configurationForSharedInstance` with
			// no warning or error :)
			return (self as AnyClass).configurationForSharedInstance()
		}
		// Otherwise return default configuration
		D.print("LocalizationConfiguration: Warning: There's no implementation providing shared configuration.")
		return LocalizationConfiguration()
	}
}


/// The LocalizationSharedConfiguration protocol defines class method which provides
/// configuration for shared instance of LocalizationProvider. You can extend
/// the LocalizationConfiguration and implement this protocol, to provide config just
/// before the shared instance is used.
///
/// Example:
///```
/// extension LocalizationConfiguration: LocalizationSharedConfiguration {
///		@objc public static func configurationForSharedInstance() -> LocalizationConfiguration {
///			let config = LocalizationConfiguration()
///			config.defaultLanguage = "es"
///			// Add other config here
///			return config
///		}
/// }
/// ```
@objc public protocol LocalizationSharedConfiguration {
	/// The method must return a valid configuration, which will be used for
	/// LocalizationProvider.shared instance setup.
	@objc static func configurationForSharedInstance() -> LocalizationConfiguration
}
