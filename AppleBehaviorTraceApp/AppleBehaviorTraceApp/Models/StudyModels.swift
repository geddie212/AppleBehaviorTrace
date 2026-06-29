//
//  StudyModels.swift
//  AppleBehaviorTraceApp
//

import Foundation

struct DraftStudyLabel: Identifiable {
    let id = UUID()
    var name = ""
    var notificationTitle = ""
    var intervalMinutes = 15

    var trimmed: DraftStudyLabel {
        var copy = self
        copy.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.notificationTitle = notificationTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return copy
    }
}

struct EditableStudyLabel: Identifiable {
    let id: UUID
    let databaseID: Int?
    let formID: Int
    var labelName: String
    var notificationTitle: String
    var intervalMinutes: Int

    init(_ label: StudyLabelRecord, formID: Int? = nil) {
        id = UUID()
        databaseID = label.id
        self.formID = formID ?? 0
        labelName = label.labelName
        notificationTitle = label.promptText ?? label.labelName
        intervalMinutes = max(1, label.promptIntervalSeconds / 60)
    }

    init(formID: Int) {
        id = UUID()
        databaseID = nil
        self.formID = formID
        labelName = ""
        notificationTitle = ""
        intervalMinutes = 15
    }

    var trimmed: EditableStudyLabel {
        var copy = self
        copy.labelName = labelName.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.notificationTitle = notificationTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return copy
    }
}

struct StudyFormRecord: Decodable, Identifiable {
    let id: Int
    let title: String
    let description: String?
    let studyCode: String
    let labels: [StudyLabelRecord]
}

struct StudyPublicRecord: Decodable, Identifiable {
    let id: Int
    let title: String
    let description: String?
    let studyCode: String
}

struct StudyLabelRecord: Decodable, Identifiable {
    let id: Int
    let labelName: String
    let promptText: String?
    let promptIntervalSeconds: Int
    let active: Bool?
}
