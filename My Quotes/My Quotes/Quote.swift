//
//  Quote.swift
//  My Quotes
//
//  Created by Jordan Morgan on 3/28/24.
//

import Foundation
import CloudKit
// Fix edits and text not showing
@Observable
class Quote: NSObject, NSSecureCoding, Identifiable {
    static var supportsSecureCoding: Bool = true
    
    // MARK: CloudKit Properties
    static let zoneName = "Quotes"
    static let recordType: CKRecord.RecordType = "Quote"
    private var zoneID: CKRecordZone.ID?
    private var recordID: CKRecord.ID?
    private(set) var syncRecord: CKRecord?
    private var syncRecordData: NSData?
    
    private(set) var text: String
    var isNewQuote: Bool {
        return id.isEmpty
    }
    let id: String
    
    // MARK: Initializers
    
    init(text: String) {
        self.text = text
        self.id = ProcessInfo.processInfo.globallyUniqueString
        
        // CloudKit
        let zoneID = CKRecordZone.ID(zoneName: Quote.zoneName)
        let recordID = CKRecord.ID(recordName: id, zoneID: zoneID)
        let record = CKRecord.init(recordType: Quote.recordType, recordID: recordID)
        record["QuoteText"] = text as CKRecordValue
        print("☁️ Record quote set to \(record["QuoteText"] as? String ?? "")")
        
        self.syncRecordData = nil
        self.syncRecord = record
        self.zoneID = zoneID
        self.recordID = recordID
    }
    
    init(text: String, id: String) {
        self.text = text
        self.id = id
    }
    
    init(record: CKRecord) {
        self.text = record["QuoteText"] as? String ?? ""
        self.id = record.recordID.recordName

        syncRecord = record
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: archiver)
        syncRecordData = archiver.encodedData as NSData
    }
    
    // MARK: Updates
    
    func update(text: String) {
        self.text = text
        
        guard let record = syncRecord else {
            fatalError("☁️ We should have a record here.")
        }
        
        record["QuoteText"] = text
        print("☁️ Record quote updated to \(record["QuoteText"] as? String ?? "")")
    }
    
    // MARK: NSCoding
    
    func encode(with coder: NSCoder) {
        coder.encode(text, forKey: "text")
        coder.encode(id, forKey: "id")
        
        if let record = syncRecord {
            let archiver = NSKeyedArchiver(requiringSecureCoding: true)
            record.encodeSystemFields(with: archiver)
            syncRecordData = archiver.encodedData as NSData
            coder.encode(syncRecordData, forKey: "syncRecordData")
        }
    }
    
    required init?(coder: NSCoder) {
        guard let text = coder.decodeObject(of: NSString.self, forKey: "text") as String?,
              let id = coder.decodeObject(of: NSString.self, forKey: "id") as String? else {
            return nil
        }
    
        self.text = text
        self.id = id
        
        // CloudKit
        let zoneID = CKRecordZone.ID(zoneName: Quote.zoneName)
        let recordID = CKRecord.ID(recordName: id, zoneID: zoneID)
        let syncRecordData = coder.decodeObject(of: NSData.self, forKey: "syncRecordData") as NSData?
        
        self.zoneID = zoneID
        self.recordID = recordID
        self.syncRecordData = syncRecordData
        if let data = syncRecordData as? Data {
            do {
                let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
                unarchiver.requiresSecureCoding = true
                self.syncRecord = .init(coder: unarchiver)
            } catch {
                print(error.localizedDescription)
            }
        }
    }

}

extension Quote {
    static var empty: Quote {
        return .init(text: "", id: "")
    }
}

// MARK: CloudKit Interfacing

extension Quote {
    func updateWith(record: CKRecord) {
        print("☁️ Updating Quote with a record...")
        
        // Update the text
        if let updateText = record["QuoteText"] as? String {
            print("☁️ Updating text from \(text) to \(updateText)")
            text = updateText as String
        }
        
        // And save off the updated record
        syncRecord = record
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: archiver)
        syncRecordData = archiver.encodedData as NSData
    }
}
