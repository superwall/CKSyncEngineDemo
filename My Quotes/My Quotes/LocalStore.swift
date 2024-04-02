//
//  LocalStore.swift
//  My Quotes
//
//  Created by Jordan Morgan on 3/28/24.
//

import Foundation
import Observation
import Combine
import CloudKit

@Observable
class LocalStore {
    static let quotesKey: String = "AllQuotes"
    private(set) var quotes: [Quote] = []
    private let defaults: UserDefaults = .standard
    private var subs: [AnyCancellable] = []
    
    // MARK: CloudKit Syncing
    let cloudSync: SyncEngine = .init()
    
    init() {
        fetchQuotes()
        
        Task {
            // The sync engine is lazyily initialized, so this
            // Just fires it up. We want this done early as we can.
            let _ = await cloudSync.engine.description
        }
        
        // Simplified for a demo app. There is a design choice to make in how closely, or loosely, coupled
        // Your sync engine and local store are. The sync engine has to know a lot about local data. For this app
        // They are loosely coupled, so this just lets us know to remove local data when CloudKit has signified
        // We should remove all data.
        NotificationCenter.default
            .publisher(for: .removePublishedQuotes)
            .sink { [weak self] _ in
                self?.quotes.removeAll()
            }
            .store(in: &subs)
        
        NotificationCenter.default
            .publisher(for: .cloudSyncChangesFinished)
            .sink { [weak self] _ in
                self?.fetchQuotes()
            }
            .store(in: &subs)
        
        print("Store has \(self.quotes.count) quotes")
    }
    
    func save(quote: Quote) {
        // New save or edit?
        if quotes.firstIndex(of: quote) == nil {
            quotes.append(quote)
        }
        
        saveQuotes()
    }
    
    func remove(quote: Quote) {
        guard let quoteIndex = quotes.firstIndex(of: quote) else {
            return
        }
        
        let quoteToRemove: Quote = quotes[quoteIndex]
        quotes.remove(at: quoteIndex)
        
        Task {
            await cloudSync.queueQuoteDeletions([quoteToRemove])
        }
        
        saveQuotes(queueChanges: false)
    }
    
    private func fetchQuotes() {
        self.quotes = LocalStore.lastCachedQuotes()
    }
    
    private func saveQuotes(queueChanges: Bool = true) {
        LocalStore.save(quotes)
        
        if queueChanges {
            Task {
                await cloudSync.queueQuotesToCloudKit(quotes)
            }
        }
    }
}

extension LocalStore {
    static func lastCachedQuotes() -> [Quote] {
        let defaults = UserDefaults.standard
        guard let quotesData  = defaults.data(forKey: LocalStore.quotesKey) else {
            return []
        }

        do {
            let decodedQuotes = try NSKeyedUnarchiver.unarchivedArrayOfObjects(ofClass: Quote.self, from: quotesData)
            return decodedQuotes ?? []
        } catch {
            print(error.localizedDescription)
            return []
        }
    }
    
    static func removeAllCachedQuotes() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: LocalStore.quotesKey)
        NotificationCenter.default.post(name: .removePublishedQuotes, object: nil)
    }
    
    static func save(_ quotes: [Quote]) {
        do {
            let defaults = UserDefaults.standard
            let encodedData: Data = try NSKeyedArchiver.archivedData(withRootObject: quotes, requiringSecureCoding: true)
            defaults.set(encodedData, forKey: LocalStore.quotesKey)
        } catch {
            print(error.localizedDescription)
        }
    }
}

extension NSNotification.Name {
    static let removePublishedQuotes: NSNotification.Name = .init(rawValue: "removePublishedQuotes")
    static let cloudSyncChangesFinished: NSNotification.Name = .init(rawValue: "cloudSyncChangesFinished")
}

