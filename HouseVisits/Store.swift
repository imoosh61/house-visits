import Foundation
import UIKit

struct PendingItem: Identifiable {
    let house: House
    let visit: Visit
    var id: UUID { house.id }
}

struct TodayVisit: Identifiable {
    let house: House
    let visit: Visit
    var id: UUID { visit.id }
}

final class Store: ObservableObject {
    @Published var houses: [House] = []

    private let cache = NSCache<NSString, UIImage>()
    private let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    private var dataURL: URL { docs.appendingPathComponent("data.json") }
    private var photosDir: URL { docs.appendingPathComponent("photos", isDirectory: true) }

    init() {
        try? FileManager.default.createDirectory(
            at: photosDir,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )
        load()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: dataURL) else { return }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        if let list = try? dec.decode([House].self, from: data) {
            houses = list
        } else {
            // keep a copy so nothing is lost if the file can't be read
            let broken = docs.appendingPathComponent("data-unreadable.json")
            try? FileManager.default.removeItem(at: broken)
            try? FileManager.default.copyItem(at: dataURL, to: broken)
        }
    }

    private func save() {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        if let data = try? enc.encode(houses) {
            try? data.write(to: dataURL, options: [.atomic, .completeFileProtection])
        }
    }

    // MARK: - Queries

    func house(_ id: UUID) -> House? {
        houses.first { $0.id == id }
    }

    func visit(houseID: UUID, visitID: UUID) -> Visit? {
        house(houseID)?.visits.first { $0.id == visitID }
    }

    var pending: [PendingItem] {
        houses.compactMap { h -> PendingItem? in
            guard let v = h.lastVisit, v.status == .followUp else { return nil }
            return PendingItem(house: h, visit: v)
        }
        .sorted { ($0.visit.followUpDate ?? .distantFuture) < ($1.visit.followUpDate ?? .distantFuture) }
    }

    var doneToday: [TodayVisit] {
        var out: [TodayVisit] = []
        for h in houses {
            for v in h.visits where Calendar.current.isDateInToday(v.date) {
                out.append(TodayVisit(house: h, visit: v))
            }
        }
        return out.sorted { $0.visit.date > $1.visit.date }
    }

    // MARK: - Houses

    func addHouse(owner: String, number: String, district: String) {
        houses.append(House(ownerName: owner.trimmed,
                            houseNumber: number.trimmed.normalizedDigits,
                            district: district.trimmed))
        save()
    }

    func updateHouse(id: UUID, owner: String, number: String, district: String) {
        guard let i = houses.firstIndex(where: { $0.id == id }) else { return }
        houses[i].ownerName = owner.trimmed
        houses[i].houseNumber = number.trimmed.normalizedDigits
        houses[i].district = district.trimmed
        save()
    }

    func deleteHouse(_ id: UUID) {
        guard let i = houses.firstIndex(where: { $0.id == id }) else { return }
        for v in houses[i].visits { v.photos.forEach(deletePhotoFile) }
        houses.remove(at: i)
        save()
    }

    // MARK: - Visits

    func addVisit(houseID: UUID, visit: Visit) {
        guard let i = houses.firstIndex(where: { $0.id == houseID }) else { return }
        houses[i].visits.append(visit)
        save()
    }

    func updateVisit(houseID: UUID, visit: Visit) {
        guard let i = houses.firstIndex(where: { $0.id == houseID }),
              let j = houses[i].visits.firstIndex(where: { $0.id == visit.id }) else { return }
        let removed = houses[i].visits[j].photos.filter { !visit.photos.contains($0) }
        removed.forEach(deletePhotoFile)
        houses[i].visits[j] = visit
        save()
    }

    func deleteVisit(houseID: UUID, visitID: UUID) {
        guard let i = houses.firstIndex(where: { $0.id == houseID }),
              let j = houses[i].visits.firstIndex(where: { $0.id == visitID }) else { return }
        houses[i].visits[j].photos.forEach(deletePhotoFile)
        houses[i].visits.remove(at: j)
        save()
    }

    // MARK: - Photos

    func savePhoto(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let name = UUID().uuidString + ".jpg"
        do {
            try data.write(to: photosDir.appendingPathComponent(name),
                           options: [.atomic, .completeFileProtection])
            return name
        } catch {
            return nil
        }
    }

    func image(_ name: String) -> UIImage? {
        if let c = cache.object(forKey: name as NSString) { return c }
        let path = photosDir.appendingPathComponent(name).path
        guard let img = UIImage(contentsOfFile: path) else { return nil }
        cache.setObject(img, forKey: name as NSString)
        return img
    }

    private func deletePhotoFile(_ name: String) {
        cache.removeObject(forKey: name as NSString)
        try? FileManager.default.removeItem(at: photosDir.appendingPathComponent(name))
    }
}
