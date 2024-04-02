//
//  SyncEngine.swift
//  My Quotes
//
//  Created by Jordan Morgan on 3/29/24.
//

import Foundation
import CloudKit

fileprivate typealias ChangeToken = CKSyncEngine.State.Serialization

final actor SyncEngine {
    private let container: CKContainer = CKContainer(identifier: "iCloud.dws.quoteSample")
    private let defaults: UserDefaults = .standard
    private let syncTokenKey: String = "syncToken"
    private(set) lazy var engine: CKSyncEngine = {
        print("☁️ Initializing sync engine.")
        let token: ChangeToken? = fetchCachedSyncToken()
        let syncConfig = CKSyncEngine.Configuration(database: container.privateCloudDatabase,
                                                    stateSerialization: token,
                                                    delegate: self)
        return .init(syncConfig)
    }()
    
    // MARK: Sync Token Persistency
    
    private func cacheSyncToken(_ token: ChangeToken) {
        do {
            let tokenData = try JSONEncoder().encode(token)
            defaults.set(tokenData, forKey: syncTokenKey)
        } catch {
            print("\(#function) - \(error.localizedDescription)")
        }
    }
    
    private func fetchCachedSyncToken() -> ChangeToken? {
        guard let tokenData: Data = defaults.data(forKey: syncTokenKey) else {
            return nil
        }
        
        do {
            let token = try JSONDecoder().decode(ChangeToken.self, from: tokenData)
            return token
        } catch {
            print("\(#function) - \(error.localizedDescription)")
            return nil
        }
    }
}

extension SyncEngine: CKSyncEngineDelegate {
    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        print("☁️ sync engine event came in, processing...")
        switch event {
        case .stateUpdate(let stateUpdate):
            print("☁️ Caching sync token.")
            let recentToken = stateUpdate.stateSerialization
            cacheSyncToken(recentToken)
        case .accountChange(let accountChange):
            print("☁️ Handling account change.")
            processAccountChange(accountChange)
        case .fetchedDatabaseChanges(let fetchedDatabaseChanges):
            print("☁️ Processing database changes.")
            processFetchedDatabaseChanges(fetchedDatabaseChanges)
        case .fetchedRecordZoneChanges(let fetchedRecordZoneChanges):
            print("☁️ Processing record zone changes.")
            processFetchedRecordZoneChanges(fetchedRecordZoneChanges)
        case .sentRecordZoneChanges(let sentRecordZoneChanges):
            print("☁️ Processing sent record zone changes.")
            processSentRecordZoneChanges(sentRecordZoneChanges)
        case .sentDatabaseChanges, .willFetchChanges, .willFetchRecordZoneChanges, .didFetchRecordZoneChanges, .didFetchChanges, .willSendChanges, .didSendChanges:
            // We don't use any of these for our simple example. In the #RealWorld, you might use these to fire
            // Any local logic or data depending on the event.
            print("☁️ Purposely unhandled event came in - \(event)")
            break
        @unknown default:
            print("☁️ Processed unknown CKSyncEngine event: \(event)")
        }
        
        // Simplified approach for demo app. Tell the LocalStore to fetch cached changes to reflect
        // All sync edits/updates/etc.
        NotificationCenter.default.post(name: .cloudSyncChangesFinished, object: nil)
    }
    
    // Delegate callback signifying CloudKit is ready for our changes, so we send the ones we marked earlier
    func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        
        let scope = context.options.scope
        let changes = syncEngine.state.pendingRecordZoneChanges.filter { scope.contains($0) }
        let quotes = LocalStore.lastCachedQuotes()
        
        let batch = await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: changes) { recordID in
            guard let matchedQuote = quotes.first(where: { quote in
                return quote.id == recordID.recordName
            }) else {
                // These are pending changes that were deleted in our store.
                // In that case, remove them from any sync operations.
                syncEngine.state.remove(pendingRecordZoneChanges: [ .saveRecord(recordID) ])
                return nil
            }
            
            matchedQuote.update(text: matchedQuote.text)
            print("😅 sending record with text as \(matchedQuote.syncRecord?["QuoteText"] as? String ?? "N/A")")
            return matchedQuote.syncRecord
        }
        
        print("☁️ Sending changes via nextRecordZoneChangeBatch with \(batch?.recordsToSave.count ?? 0) saves/edits and \(batch?.recordIDsToDelete.count ?? 0) removals.")
        
        return batch
    }
}

// MARK: Handling CKSyncEngine Events

extension SyncEngine {
    func processAccountChange(_ event: CKSyncEngine.Event.AccountChange) {
        switch event.changeType {
        case .signIn:
            print("☁️ Uploading everything due to account sign in...")
            reuploadEverything()
        case .switchAccounts, .signOut:
            print("☁️ Removing all local data due to account changes.")
            LocalStore.removeAllCachedQuotes()
        @unknown default:
            print("Unhandled account change event: \(event)")
        }
    }
    
    func processFetchedDatabaseChanges(_ changes: CKSyncEngine.Event.FetchedDatabaseChanges) {
        // A zone deletion means we should delete local data.
        for deletion in changes.deletions {
            switch deletion.zoneID.zoneName {
            case Quote.zoneName:
                print("☁️ The Quote zone was deleted, removing all local data.")
                LocalStore.removeAllCachedQuotes()
            default:
                print("☁️ Received deletion for an unknown zone: \(deletion.zoneID)")
            }
        }
    }
    
    func processFetchedRecordZoneChanges(_ changes: CKSyncEngine.Event.FetchedRecordZoneChanges) {
        var quotes: [Quote] = LocalStore.lastCachedQuotes()
        
        // These are new, or edited/updated, Quotes...
        for modification in changes.modifications {
            let record = modification.record
            
            // If we have it locally, it'll match here.
            let isEdit = quotes.contains { quote in
                return quote.id == record.recordID.recordName
            }
            
            // If it's an edit, update the quote's text and assign it the new record
            if isEdit {
                print("☁️ Editing an existing record.")
                guard let editIndex = quotes.firstIndex(where: { quote in
                    return quote.id == record.recordID.recordName
                }) else {
                    fatalError("☁️ We received a record to edit that should exist locally.")
                }
                
                quotes[editIndex].updateWith(record: record)
            } else {
                print("☁️ Adding a new record.")
                // New Quote added from another device, so save it
                let quote = Quote(record: record)
                quotes.append(quote)
            }
        }
        
        // Quotes that were on one or more devices, so remove it locally if we've got it.
        for deletion in changes.deletions {
            let recordID = deletion.recordID.recordName
            
            if let removalIndex = quotes.firstIndex(where: { quote in
                return quote.id == recordID
            }) {
                print("☁️ Deleting a quote with ID \(deletion.recordID)")
                quotes.remove(at: removalIndex)
            } else {
                print("☁️ Deletion request for quote with ID \(deletion.recordID) - but we don't have it locally.")
            }
        }
        
        // Set cache with these changes...
        LocalStore.save(quotes)
    }
    
    func processSentRecordZoneChanges(_ changes: CKSyncEngine.Event.SentRecordZoneChanges) {
        // Handle any failed record saves.
        changes.failedRecordSaves.forEach {
            print("☁️ failed save error code: \($0.error.code)")
        }
    }
}

// MARK: Interfacing with your Local Data Models

extension SyncEngine {
    // Tells CloudKit to add these changes to its scheduler
    func queueQuotesToCloudKit(_ quotes: [Quote]) {
        print("☁️ Queuing changes to the sync state.")
        let recordIDs = quotes.compactMap { $0.syncRecord?.recordID }
        let changes: [CKSyncEngine.PendingRecordZoneChange] = recordIDs.map{ .saveRecord($0) }
        engine.state.add(pendingRecordZoneChanges: changes)
    }
    
    func queueQuoteDeletions(_ quotes: [Quote]) {
        print("☁️ Queues a deletion to the sync state.")
        let recordIDs = quotes.compactMap { $0.syncRecord?.recordID }
        let deletions: [CKSyncEngine.PendingRecordZoneChange] = recordIDs.map{ .deleteRecord($0) }
        engine.state.add(pendingRecordZoneChanges: deletions)
    }
    
    func reuploadEverything() {
        print("☁️ Uploading all data and creating zone.")
        let quotes = LocalStore.lastCachedQuotes()
        let recordIDs = quotes.compactMap { $0.syncRecord?.recordID }
        let changes: [CKSyncEngine.PendingRecordZoneChange] = recordIDs.map{ .saveRecord($0) }
        engine.state.add(pendingDatabaseChanges: [ .saveZone(CKRecordZone(zoneName: Quote.zoneName)) ])
        engine.state.add(pendingRecordZoneChanges: changes)
    }
    
    func removeAllData() {
        print("☁️ Removing all data locally and on the server.")
        let quotes: [Quote] = LocalStore.lastCachedQuotes()
        LocalStore.removeAllCachedQuotes()
        
        let allRecordIDs: [CKRecord.ID] = quotes.compactMap{
            $0.syncRecord?.recordID
        }
        let recordRemovals: [CKSyncEngine.PendingRecordZoneChange] = allRecordIDs.map {
            .deleteRecord($0)
        }
        
        engine.state.add(pendingRecordZoneChanges: recordRemovals)
        
        let quotesZoneID = CKRecordZone.ID(zoneName: Quote.zoneName)
        engine.state.add(pendingDatabaseChanges: [ .deleteZone(quotesZoneID) ])
    }
    
    func pushLatestChanges() {
        Task {
            do {
                print("☁️ Force pushing latest changes...")
                try await engine.sendChanges()
            } catch {
                print("☁️ Error pushing latest changes: \(error.localizedDescription)")
            }
        }
    }
    
    func pullLatestChanges() {
        Task {
            do {
                print("☁️ Force pulling latest changes...")
                try await engine.fetchChanges()
            } catch {
                print("☁️ Error pulilng latest changes: \(error.localizedDescription)")
            }
        }
    }
}
