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
import LimeCore
import LimeConfig

internal typealias D = LimeDebug

// MARK: - Provider -

/// The LocalizationProvider object implements string localizations in the application.
/// Unlike the default localizations handling in IOS, this class can change language in runtime.
///
/// The implementation loads the same string tables just like original IOS implementation.
public class LocalizationProvider {
    
    /// A notification fired when the language is changed
    public static let didChangeLanguage = Notification.Name(rawValue: "LocalizationProvider_didChangeLanguage")
    
    /// LocalizationProvider's singleton
    public static let shared = LocalizationProvider(configuration: LimeConfig.shared.localization)
    
    /// Thread synchronization object
    fileprivate let lock = Lock()
    
    /// Current applied language. You can can change current language with change(language:) method.
    /// The nil value means that the default language is used or value is not determined yet.
    public var language: String? {
        return lock.synchronized { return privateLanguage }
    }
    fileprivate var privateLanguage: String?
    
    /// Returns an actual applied language. If there's no applied language (e.g. you have broken tables)
    /// then always returns "en" as safe fallback.
    public var appliedLanguage: String {
        return lock.synchronized {
            guard let lang = privateAppliedLanguage else {
                return "en"
            }
            return lang
        }
    }
    fileprivate var privateAppliedLanguage: String?
    
    /// Returns list of identifiers for all available languages. The value is updated when the configuration
    /// is applied. You can affect order of languages by changing `LocalizationConfiguration.preferredLanguages`.
    public var availableLanguages: [String] {
        return lock.synchronized { return [String](privateAvailableLanguages) }
    }
    
    /// Returns language names for all available languages. The returned array contains tuple with identifier and
    /// language's name. The order of elements in array is equal to languages returned in availableLanguages property.
    public var availableLanguageNames: [(identifier:String, name:String)] {
        return lock.synchronized {
            return privateAvailableLanguages.map { ($0, translateLanguage($0)) }
        }
    }
    
    fileprivate var privateAvailableLanguages = [String]()
    fileprivate var privateSupportedLanguagesSet = Set<String>()
    fileprivate var privateLanguageNameMap = [String:String]()
    
    
    /// Returns current localization configuration
    public var configuration: LocalizationConfiguration {
        return lock.synchronized {
            return self.privateConfiguration
        }
    }
    fileprivate var privateConfiguration: LocalizationConfiguration
    
    /// An internal type for string table (e.g. key => localization dictionary)
    fileprivate typealias StringTable = [String:String]
    
    /// An internal type representing languageId => filePath dictionary
    fileprivate typealias LangPathDict = [String:String]
    
    /// Current localization table
    fileprivate var privateTranslations: StringTable = [:]
    
    /// Array with all string tables and localization files
    fileprivate var privateAllStringTables: [LangPathDict] = []
    
    // MARK: - Initialization
    
    /// Private constructor
    public init(configuration: LocalizationConfiguration) {
        self.privateConfiguration = configuration
        let fireMessage = self.applyConfiguration(config: self.privateConfiguration)
        if fireMessage {
            reportChange()
        }
    }
}

/// A public interface
public extension LocalizationProvider {

    /// Returns localized string for given key.
    /// You can use this method or String extension, which provides additional useful methods.
    public func localizedString(_ key: String) -> String {
        return lock.synchronized { return translate(key) }
    }
    
    /// Returns localized string for given key or nil if localization for that key doesn't exist.
    public func tryLocalizeString(_ key: String) -> String? {
        return lock.synchronized { return tryTranslate(key) }
    }
    
    /// Applies a new configuration to the provider. This may lead to language change,
    /// if applied configuration doesn't support current language
    public func apply(configuration: LocalizationConfiguration) {
        let fireMessage = lock.synchronized { () in
            return applyConfiguration(config: configuration)
        }
        if fireMessage {
            reportChange()
        }
    }
    
    /// Changes a language to new one. If the effective language
    public func change(language: String?) {
        let fireMessage = lock.synchronized { () in
            return applyLanguage(identifier: language)
        }
        if fireMessage {
            reportChange()
        }
    }
    
    /// Returns name for given language identifier. The language identifier should be one from
    /// currently supported identifiers.
    public func languageName(language: String) -> String {
        return lock.synchronized { return translateLanguage(language) }
    }
}


/// This extension hides implementation details and contains only private methods.
fileprivate extension LocalizationProvider {
    
    static let tableInfoKey = "###"
    
    /// Translates key into localized string.
    func translate(_ key: String) -> String {
        if let value = privateTranslations[key] {
            return value
        }
        // Fallback to "prefix " + key, to highlight missing translation
        return privateConfiguration.missingLocalizationPrefix + key
    }

    /// Translates key into localized string.
    func tryTranslate(_ key: String) -> String? {
        if let value = privateTranslations[key] {
            return value
        }
        return nil
    }
    
    /// Loads string table for one exact language into the StringTable dictionary.
    func mergeLanguage(identifier: String, langPathDict: LangPathDict, table: inout StringTable) -> Bool {
        
        guard let tablePath = langPathDict[identifier] else {
            return false
        }
        guard let tableName = langPathDict[LocalizationProvider.tableInfoKey] else {
            return false
        }
        let tableId = "'\(tableName) @ \(identifier)'"
        D.print("LocalizationProvider: Loading string table \(tableId) from file: \(tablePath)")
        
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: tablePath)) else {
            D.print("LocalizationProvider: Unable to load string table \(tableId) from file: \(tablePath)")
            return false
        }
        guard let objects = try? PropertyListSerialization.propertyList(from: data, format: nil) else {
            D.print("LocalizationProvider: Unable to deserialize property list for table \(tableId) from file: \(tablePath)")
            return false
        }
        guard let dictionary = objects as? NSDictionary else {
            return false
        }
        dictionary.forEach({ (key: Any, value: Any) in
            if let keyString = key as? String, let valueString = value as? String {
                #if DEBUG
                    if table[keyString] != nil {
                        D.print("     * replacing \"\(keyString)\"  ==> \"\(valueString)\"")
                    }
                #endif
                table[keyString] = valueString
            }
        })
        return true;
    }
    
    /// The method implements language change. If the identifier is nil, then the default language is applied.
    /// Returns true if the language has been changed and this change must be reported via the notification.
    func applyLanguage(identifier: String?) -> Bool {
        
        let effective = suggestLanguage(identifier)
        
        var translations: StringTable = [:]
        var success = true
        var reportChange = false

        // Merge all string tables to one translation dictionary
        privateAllStringTables.forEach { (langPathDict) in
            if !mergeLanguage(identifier: effective, langPathDict: langPathDict, table: &translations) {
                success = false
            }
        }
        
        // Commit change if succeeeded
        if success {
            reportChange = self.privateAppliedLanguage != effective
            self.privateAppliedLanguage = effective
            self.privateLanguage = identifier
            self.privateTranslations = translations
            // Store change to user defaults
            let settings = UserDefaults.standard
            if identifier != nil {
                settings.set(effective, forKey: privateConfiguration.settingsKey)
            } else {
                settings.removeObject(forKey: privateConfiguration.settingsKey)
            }
            settings.set([effective], forKey: "AppleLanguages")
            settings.synchronize()
        } else {
            D.print("LocalizationProvider: The language was not changed, due to loading error.")
        }
        return reportChange
    }
    
    /// Applies a new configuration to the LocalizationProvider.
    /// Returns true, if the language has been changed and this change must be reported via the notification.
    func applyConfiguration(config: LocalizationConfiguration) -> Bool {
        // at first, try to load all tables and build a set with supported languages
        let allTables				= loadAllTables(tables: config.stringTables, defaultLanguage: config.defaultLanguage)
        let availableLanguages		= buildAvailableLanguagesSet(availableTables: allTables)
        let sortedLanguages			= buildAvailableLanguagesList(languagesSet: availableLanguages, prefered: config.preferedLanguages)
        
        // Commit runtime data
        
        self.privateAllStringTables			= allTables
        self.privateSupportedLanguagesSet	= availableLanguages
        self.privateAvailableLanguages		= sortedLanguages
        self.privateConfiguration			= config
        // Wipe out cached data
        self.privateLanguageNameMap.removeAll()
        
        // Try to load config from user defaults, or when nil, then use last set language (in case that you're changing config in runtime)
        // Both fallbacks may lead to nil
        let nextLanguage = UserDefaults.standard.string(forKey: config.settingsKey) ?? self.privateLanguage
        let _ = self.applyLanguage(identifier: nextLanguage)
        // This is simplification, we always returns true, because there's a high chance that
        // changing the configuration may have a big impact on
        return true
    }
    
    /// Returns array with dictionaries, containing lang => table-path map.
    /// The result represents all configured string tables and its localized files.
    func loadAllTables(tables: [LocalizationTable], defaultLanguage: String) -> [LangPathDict] {
        var allTables = [LangPathDict]()
        tables.forEach { (table) in
            let stringTables = scanForAllStringTables(table: table, defaultLanguage: defaultLanguage)
            allTables.append(stringTables)
        }
        return allTables
    }

    
    /// The method looks for all localization files belonging to given LocalizationTable.
    /// The defaultLanguage parameter is an identifier used for "Base" language table.
    /// Returns dictionary with all detected language identifiers and paths to string table files.
    func scanForAllStringTables(table: LocalizationTable, defaultLanguage: String) -> LangPathDict {
        let bundlePath = table.bundle.bundlePath
        let fm = FileManager.default
        let content = try? fm.contentsOfDirectory(atPath: bundlePath)
        var result: LangPathDict = [:]
        content?.forEach({ (item) in
            if item.hasSuffix(".lproj") {
                let tablePath = "\(bundlePath)/\(item)/\(table.name).strings"
                if fm.fileExists(atPath: tablePath) {
                    var languageIdentifier = (item as NSString).deletingPathExtension
                    if languageIdentifier == "Base" {
                        languageIdentifier = defaultLanguage
                    }
                    result[languageIdentifier] = tablePath
                }
            }
        })
        #if DEBUG
            if !result.isEmpty {
                D.print("LocalizationProvider: Table '\(table.name)' has localizations:")
                result.forEach({ (lang, path) in
                    let humanReadablePath = (path as NSString).substring(from: (bundlePath as NSString).length)
                    D.print("     - \(lang)  :  \(humanReadablePath)")
                })
            } else {
                let bundleId = table.bundle.bundleIdentifier ?? table.bundle.bundlePath
                D.print("LocalizationProvider: No localized files found in table '\(table.name)', bundle: \(bundleId)")
            }
        #endif
        // For debug purposes, we should keep a small info about loaded table also in the returned dictionary.
        result[LocalizationProvider.tableInfoKey] = table.name
        return result
    }

    /// Fires a notification about the language change from "main" queue.
    func reportChange() {
        // Post notification about language change to the main thread
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: LocalizationProvider.didChangeLanguage, object: nil)
        }
    }
    
    /// Returns set with all available languages. Note that if you have a multiple string tables, then all of tables
    /// must support the same languages, oterwise the common subset of identifiers is returned.
    func buildAvailableLanguagesSet(availableTables: [LangPathDict]) -> Set<String> {
        var set = Set<String>()
        var arrayOfSets = [Set<String>]()
        // 1. Colllect available languages and merge identifiers into 'set'
        availableTables.forEach { (tableDictionary) in
            let setOfKeys: Set<String> = Set<String>(tableDictionary.keys)
            arrayOfSets.append(setOfKeys)
            set.formUnion(setOfKeys)
        }
        // 2. remove key which is used for debug purposes
        set.remove(LocalizationProvider.tableInfoKey)
        // 3. make intersection with all languages from tables
        arrayOfSets.forEach { (oneTable) in
            set.formIntersection(oneTable)
        }
        return set;
    }
    
    /// Returns sorted list of available languages
    func buildAvailableLanguagesList(languagesSet: Set<String>, prefered: [String]?) -> [String] {
        // Let's sort that set with applying order from preferred languages
        var mutableSet = Set<String>(languagesSet)
        var result = [String]()
        prefered?.forEach({ (preferedLanguage) in
            if mutableSet.contains(preferedLanguage) {
                result.append(preferedLanguage)
                mutableSet.remove(preferedLanguage)
            }
        })
        result.append(contentsOf: mutableSet.sorted())
        return result
    }
    
    /// The method tries suggest an alternative language for given language.
    /// If you provide a nil as a parameter, then it will try to determine default
    /// language. The method always returns "en" as fallback.
    func suggestLanguage(_ languageIdentifier: String?) -> String {
        var identifier = languageIdentifier
        if self.privateSupportedLanguagesSet.isEmpty {
            D.print("LocalizationProvider: Your localization configuration appears to be broken. Defaulting to 'en'")
            return "en"
        }
        // Try validate & map identifier directly
        if let lang = tryMapIdentifier(identifier) {
            return lang
        }
        // Try system language
        identifier = UserDefaults.standard.stringArray(forKey: "AppleLanguages")?.first
        if let lang = tryMapIdentifier(identifier) {
            return lang
        }
        // Try default language from config
        identifier = privateConfiguration.defaultLanguage
        if let lang = tryMapIdentifier(identifier) {
            return lang
        }
        // Try native development region
        identifier = Bundle.main.developmentLocalization
        if let lang = tryMapIdentifier(identifier) {
            return lang
        }
        // ...well, this is not good. We are out of options, so return a first language
        //    from available list
        return self.privateAvailableLanguages.first ?? "en"
    }
    
    /// This method validates whether the identifier is supported or mappable to another
    /// language. If yes, then returns identifier or mapped identifier for language,
    /// If no such translation is possible, then returns nil
    func tryMapIdentifier(_ identifier: String?) -> String? {
        if let lang = identifier {
            if privateSupportedLanguagesSet.contains(lang) {
                return lang
            }
            if let mapped = privateConfiguration.languageMappings?[lang] {
                if privateSupportedLanguagesSet.contains(mapped) {
                    return mapped
                }
            }
        }
        return nil
    }
    
    /// Returns name for language identifier. This is high level method which caches an already translated
    /// strings into internal dictionary. You still have to guarantee an exclusive access
    func translateLanguage(_ identifier: String) -> String {
        if let name = privateLanguageNameMap[identifier] {
            return name
        }
        let name = fetchLanguageName(identifier)
        privateLanguageNameMap[identifier] = name
        return name
    }
    
    /// Returns name for language indentifier. This is actual translation lookup, which works in following order:
    ///   1. at first, method is looking for localized key "language.identifier"
    ///   2. for second attempt, it will try to use Locale object for translation
    ///   3. as fallback, returns "### language.ID"
    func fetchLanguageName(_ identifier: String) -> String {
        // look for translation at first
        let localizationKey = privateConfiguration.prefixForLocalizedLanguageNames + identifier
        if let name = privateTranslations[localizationKey] {
            return name
        }
        // try to use Locale for translation
        if let name = (Locale(identifier: identifier) as NSLocale).displayName(forKey: .identifier, value: identifier)?.capitalized {
            return name
        }
        // Fallback... just display missing localization prefix
        return privateConfiguration.missingLocalizationPrefix + localizationKey
    }
}
