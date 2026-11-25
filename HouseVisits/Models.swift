import Foundation
import UIKit

enum VisitStatus: String, Codable, CaseIterable {
    case done
    case followUp

    var title: String { self == .done ? "تم" : "يحتاج متابعة" }
}

enum WorkTypes {
    static let all = ["سباكة", "كهرباء", "تكييف", "دهان", "نجارة", "سيراميك", "أبواب ونوافذ", "أخرى"]
}

struct Visit: Codable, Identifiable, Hashable {
    var id = UUID()
    var date = Date()
    var workers = ""
    var workTypes: [String] = []
    var notes = ""
    var status: VisitStatus = .done
    var followUpDate: Date? = nil
    var photos: [String] = []
}

struct House: Codable, Identifiable, Hashable {
    var id = UUID()
    var ownerName: String
    var houseNumber: String
    var district: String
    var visits: [Visit] = []

    var sortedVisits: [Visit] { visits.sorted { $0.date > $1.date } }
    var lastVisit: Visit? { sortedVisits.first }
    var needsFollowUp: Bool { lastVisit?.status == .followUp }
}

struct VisitRoute: Hashable {
    let houseID: UUID
    let visitID: UUID
}

enum Fmt {
    static let locale = Locale(identifier: "ar@numbers=latn")

    private static func make(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = format
        return f
    }

    private static let shortF = make("d MMMM yyyy")
    private static let fullF = make("EEEE d MMMM yyyy")

    static func short(_ d: Date) -> String { shortF.string(from: d) }
    static func full(_ d: Date) -> String { fullF.string(from: d) }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }

    var normalizedDigits: String {
        let digitMap: [Character: Character] = [
            "٠": "0", "١": "1", "٢": "2", "٣": "3", "٤": "4",
            "٥": "5", "٦": "6", "٧": "7", "٨": "8", "٩": "9",
            "۰": "0", "۱": "1", "۲": "2", "۳": "3", "۴": "4",
            "۵": "5", "۶": "6", "۷": "7", "۸": "8", "۹": "9"
        ]
        return String(self.map { digitMap[$0] ?? $0 })
    }
}

extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > 0 else { return self }
        let scale = min(1, maxDimension / longest)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
