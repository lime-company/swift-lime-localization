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
import LimeConfig

/// A LocalizationConfiguration protocol defines immutable configuration
/// which affects functionality of `LocalizationProvider`.
public protocol LocalizationConfiguration: ImmutableConfig {
    /// Defines default language when current system language is not supported in your
    /// string tables. LocalizationProvider uses following resolving rules if
    /// initial language is not set:
    ///
    ///    1. if system language is supported in string tables, then will use system language.
    ///    2. if it's possible to map system language to some supported language, then will use language mapping.
    ///    3. if defaultLanguage is set and supported in string tables, then will use defaultLanguage
    ///    4. if 'Localization native development region' is supported in string tables, then will use this language
    ///    5. otherwise will use first available language in string table.
    ///
    /// If you're using "Base" localization, you should set defaultLanguage to language identifier, which represents
    /// your primary language.
    var defaultLanguage: String { get }
    
    /// Defines mapping from one language to another, supported in string tables.
    /// This is useful when your string tables covers only few languages but these
    /// are understandable in another target countries.
    ///
    /// A typical example is Czechs versus Slovakians. If you have localization for czech
    /// language then you can define mapping from "sk" to "cz" because people in
    /// these countries would understand each other. Then the people using Slovak system
    /// language will see your application in Czech localization.
    var languageMappings: [String:String]? { get }
    
    /// Affects order of language identifiers
    var preferedLanguages: [String]? { get }
    
    /// A list of string tables which will needs to be loaded during the language change.
    /// You can define multiple string tables from different bundles, but the order of tables
    /// affects how the final translation table is constructed. The LocalizationProvider is loading
    /// tables in this predefined order and therefore the keys from later loaded tables overrides
    /// previously defined localizations.
    var stringTables: [LocalizationTable] { get }
    
    /// A prefix used when the localization for key is not localized. For exampe, if "My Key" has
    /// no translation in current language, then the "### My Key" is returned as localized string.
    /// This allows you to easily look for missing localizations in your application.
    var missingLocalizationPrefix: String { get }
    
    /// A ked to UserDefaults storage, where the actual user's prefered language configuration is stored.
    var settingsKey: String { get }
    
    /// You can define prefix for string table keys, used for language names localization. The value
    /// affects strings produced in LocalizationProvider.localizedAvailableLanguages property.
    /// Your string tables must define all these localizations. For exaple, you have to define
    /// following localization strings for default confing:
    ///    "language.en" = "English";
    ///    "language.cs" = "Čeština";
    ///    "language.es" = "Español";
    var prefixForLocalizedLanguageNames: String { get }
}

/// The `MutableLocalizationConfiguration` object implements `LocalizationConfiguration` protocol
/// and also conforms to `LimeConfig.MutableConfig` protocol.
public class MutableLocalizationConfiguration: MutableConfig, LocalizationConfiguration {
    
    public var defaultLanguage: String              = "en"
    public var languageMappings: [String:String]?
    public var preferedLanguages: [String]?
    public var stringTables: [LocalizationTable]    = [ LocalizationTable.defaultTable() ]
    public var missingLocalizationPrefix: String    = "### "
    public var settingsKey: String                  = "LimeLocalization.SelectedLanguage"
    public var prefixForLocalizedLanguageNames      = "language."
    
    /// Public constructor
    public init() {
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
    
    public func makeImmutable() -> ImmutableConfig {
        return MutableLocalizationConfiguration(copyFrom: self) as LocalizationConfiguration
    }
}


public extension LimeConfig {
    
    /// Returns configuration for `LocalizationProvider`.
    public var localization: LocalizationConfiguration {
        if let cfg: MutableLocalizationConfiguration = self.config(for: LimeConfig.domainForLocalization) {
            return cfg
        }
        return LimeConfig.fallbackLocalizationConfig
    }
    
    /// Registers `MutableLocalizationConfiguration` to `LimeConfig` facility. You can call this method only
    /// once per LimeConfig instance, during the config's domain registration phase.
    public var registerLocalization: MutableLocalizationConfiguration? {
        return self.register(MutableLocalizationConfiguration(), for: LimeConfig.domainForLocalization)
    }
    
    /// Domain for config registration
    private static let domainForLocalization = "lime.localization"
    
    /// Fallback object returned when localization domain has not been properly registered.
    private static let fallbackLocalizationConfig = MutableLocalizationConfiguration()
}



