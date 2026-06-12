//
//  ExerciseTemplate+CoreDataProperties.swift
//  Soleus
//

import Foundation
import CoreData


extension ExerciseTemplate {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ExerciseTemplate> {
        return NSFetchRequest<ExerciseTemplate>(entityName: "ExerciseTemplate")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var descriptionText: String?
    @NSManaged public var category: String?
    @NSManaged public var defaultQuantifier: String?
    @NSManaged public var defaultMeasurement: String?
    @NSManaged public var usageCount: Int32
    @NSManaged public var isCustom: Bool

}

extension ExerciseTemplate : Identifiable {

}
