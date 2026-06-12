//
//  TemporaryWorkoutDetail+CoreDataProperties.swift
//  Soleus
//
//  Created by Damien Sprinkle on 11/9/24.
//
//

import Foundation
import CoreData


extension TemporaryWorkoutDetail {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<TemporaryWorkoutDetail> {
        return NSFetchRequest<TemporaryWorkoutDetail>(entityName: "TemporaryWorkoutDetail")
    }

    @NSManaged public var exerciseId: UUID?
    @NSManaged public var exerciseName: String?
    @NSManaged public var exerciseQuantifier: String?
    @NSManaged public var id: UUID?
    @NSManaged public var orderIndex: Int32
    @NSManaged public var restDuration: Int32
    @NSManaged public var exerciseMeasurement: String?
    @NSManaged public var notes: String?
    @NSManaged public var history: WorkoutHistory?
    @NSManaged public var sessions: WorkoutSession?
    @NSManaged public var sets: NSSet?
    @NSManaged public var workoutR: Workouts?

}

// MARK: Generated accessors for sets
extension TemporaryWorkoutDetail {

    @objc(addSetsObject:)
    @NSManaged public func addToSets(_ value: WorkoutSet)

    @objc(removeSetsObject:)
    @NSManaged public func removeFromSets(_ value: WorkoutSet)

    @objc(addSets:)
    @NSManaged public func addToSets(_ values: NSSet)

    @objc(removeSets:)
    @NSManaged public func removeFromSets(_ values: NSSet)

}

extension TemporaryWorkoutDetail : Identifiable {

}
