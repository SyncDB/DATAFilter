import Foundation
import CoreData
import DATAObjectIDs

public class DATAFilter: NSObject {
    public struct Operation : OptionSetType {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let Insert = Operation(rawValue: 1 << 0)
        public static let Update = Operation(rawValue: 1 << 1)
        public static let Delete = Operation(rawValue: 1 << 2)
        public static let All: Operation = [.Insert, .Update, .Delete]
    }

    public class func changes(changes: [[String : AnyObject]],
                              inEntityNamed entityName: String,
                                            localPrimaryKey: String,
                                            remotePrimaryKey: String,
                                            context: NSManagedObjectContext,
                                            inserted: (objectJSON: [String: AnyObject]) -> Void,
                                            updated: (objectJSON: [String: AnyObject], updatedObject: NSManagedObject) -> Void){
        self.changes(changes, inEntityNamed: entityName, predicate: nil, operations: .All, localPrimaryKey: localPrimaryKey, remotePrimaryKey: remotePrimaryKey, context: context, inserted: inserted, updated: updated)
    }

    public class func changes(changes: [[String : AnyObject]],
                              inEntityNamed entityName: String,
                                            predicate: NSPredicate?,
                                            operations: Operation,
                                            localPrimaryKey: String,
                                            remotePrimaryKey: String,
                                            context: NSManagedObjectContext,
                                            inserted: (objectJSON: [String: AnyObject]) -> Void,
                                            updated: (objectJSON: [String: AnyObject], updatedObject: NSManagedObject) -> Void) {
        let dictionaryIDAndObjectID = DATAObjectIDs.objectIDsInEntityNamed(entityName, withAttributesNamed: localPrimaryKey, context: context, predicate: predicate)
        let fetchedObjectIDs: [AnyObject] = Array(dictionaryIDAndObjectID.keys)
        let remoteObjectIDsOpt = changes.map({$0[remotePrimaryKey]})
        let remoteObjectIDs = remoteObjectIDsOpt.filter({$0 != nil}) as! [AnyObject!]

        let remoteIDAndChange = NSDictionary(objects: changes as [AnyObject], forKeys: remoteObjectIDs as NSArray as! [NSCopying])
        let intersection = NSMutableSet(array: remoteObjectIDs as [AnyObject])
        intersection.intersectSet(NSSet(array: fetchedObjectIDs) as Set<NSObject>)
        let updatedObjectIDs = intersection.allObjects

        let deletedObjectIDs = NSMutableArray(array: fetchedObjectIDs)
        deletedObjectIDs.removeObjectsInArray(remoteObjectIDs as [AnyObject])

        var insertedObjectIDs = remoteObjectIDs
        insertedObjectIDs = insertedObjectIDs.filter {value in
            !fetchedObjectIDs.contains({$0.isEqual(value)})
        }

        if operations.contains(.Delete) {
            for fetchedID in deletedObjectIDs {
                let objectID = dictionaryIDAndObjectID[fetchedID as! NSObject] as! NSManagedObjectID
                let object = context.objectWithID(objectID)
                context.deleteObject(object)
            }
        }

        if operations.contains(.Insert) {
            for fetchedID in insertedObjectIDs as NSArray as! [NSCopying] {
                let objectDictionary = remoteIDAndChange[fetchedID] as! [String: AnyObject]
                inserted(objectJSON: objectDictionary)
            }
        }

        if operations.contains(.Update) {
            for fetchedID in updatedObjectIDs as! [NSCopying] {
                let objectDictionary = remoteIDAndChange[fetchedID] as! [String: AnyObject]
                let objectID = dictionaryIDAndObjectID[fetchedID as! NSObject] as! NSManagedObjectID
                let object = context.objectWithID(objectID)
                updated(objectJSON: objectDictionary, updatedObject: object)
            }
        }
    }
}
