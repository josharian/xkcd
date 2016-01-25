//
//  CoreDataStack.swift
//  xkcd
//
//  Created by Paul Rehkugler on 1/24/16.
//
//

import UIKit

final class CoreDataStack: NSObject {

    var applicationsDocumentsDirectory: String

    var managedObjectContext: NSManagedObjectContext

    private var managedObjectModel: NSManagedObjectModel
    private var persistentStoreCoordinator: NSPersistentStoreCoordinator

    private static var sharedCoreDataStackStorage: CoreDataStack?

    class func sharedCoreDataStack() -> CoreDataStack {
        if let coreDataStack = CoreDataStack.sharedCoreDataStackStorage {
            return coreDataStack
        }
        else {
            let coreDataStack = CoreDataStack()
            CoreDataStack.sharedCoreDataStackStorage = coreDataStack
            return coreDataStack
        }
    }

    override init() {
        let fileManager = NSFileManager.defaultManager()
        guard let applicationsDocumentsDirectory = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, [.UserDomainMask], true).first else {
            fatalError("Unable to get the applications documents directory.")
        }

        guard let managedObjectModel = NSManagedObjectModel.mergedModelFromBundles(nil) else {
            fatalError("Unable to create a managed object model.")
        }

        // Clean up the old file from pervious versions
        let oldStorePath = (applicationsDocumentsDirectory as NSString).stringByAppendingPathComponent("xkcd.sqlite")
        if fileManager.fileExistsAtPath(oldStorePath) {
            do {
                try fileManager.removeItemAtPath(oldStorePath)
            }
            catch let error as NSError {
                print("Error removing old SQLite file at \(oldStorePath): \(error.description)")
            }
        }

        let storePath = (applicationsDocumentsDirectory as NSString).stringByAppendingPathComponent("comics.sqlite")
        if !fileManager.fileExistsAtPath(storePath) {
            if let bundledPath = NSBundle.mainBundle().pathForResource("comics", ofType: "sqlite") {
                if fileManager.fileExistsAtPath(bundledPath) {
                    do {
                        try fileManager.copyItemAtPath(bundledPath, toPath: storePath)
                    }
                    catch let error as NSError {
                        print("The SQLite database does not exist, and the sample one in the bundle is not able to be copied: \(error.description)")
                    }
                }
            }
        }

        let storeURL = NSURL.fileURLWithPath(storePath)
        let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
        do {
            try persistentStoreCoordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: storeURL, options: nil)
            managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
            managedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator
        }
        catch let error as NSError {
            fatalError("Unable to add the SQLite store to the persistent store coordinator: \(error.description)")
        }

        self.persistentStoreCoordinator = persistentStoreCoordinator
        self.applicationsDocumentsDirectory = applicationsDocumentsDirectory
        self.managedObjectModel = managedObjectModel

        super.init()

        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("applicationWillTerminate:"), name: UIApplicationWillTerminateNotification, object: nil)
    }

    // MARK: - Saving

    func save() {
        assert(NSThread.isMainThread(), "This Core Data stack only supports main thread concurrency.")

        if managedObjectContext.hasChanges {
            do {
                try managedObjectContext.save()
            }
            catch let error as NSError {
                print("Could not save CoreData changes: \(error.description)")
            }
        }
    }

    // MARK: - Notifications

    @objc func applicationWillTerminate(notification: NSNotification) {
        if managedObjectContext.hasChanges {
            do {
                try managedObjectContext.save()
            }
            catch let error as NSError {
                print("Could not save CoreData changes: \(error.description)")
                exit(EXIT_FAILURE)
            }
        }
    }
}