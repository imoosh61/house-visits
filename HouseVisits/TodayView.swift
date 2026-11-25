import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        let cal = Calendar.current
        let startToday = cal.startOfDay(for: Date())
        let endToday = cal.date(byAdding: .day, value: 1, to: startToday) ?? startToday
        let pending = store.pending
        let overdue = pending.filter { ($0.visit.followUpDate ?? startToday) < startToday }
        let today = pending.filter {
            let f = $0.visit.followUpDate ?? startToday
            return f >= startToday && f < endToday
        }
        let upcoming = pending.filter { ($0.visit.followUpDate ?? startToday) >= endToday }
        let done = store.doneToday

        NavigationStack {
            List {
                if pending.isEmpty && done.isEmpty {
                    Text("ما فيه متابعات ولا زيارات اليوم")
                        .foregroundColor(.secondary)
                }
                if !overdue.isEmpty {
                    Section("متأخرة") {
                        ForEach(overdue) { item in pendingRow(item, color: .red) }
                    }
                }
                if !today.isEmpty {
                    Section("متابعات اليوم") {
                        ForEach(today) { item in pendingRow(item, color: .orange) }
                    }
                }
                if !upcoming.isEmpty {
                    Section("متابعات قادمة") {
                        ForEach(upcoming) { item in pendingRow(item, color: .secondary) }
                    }
                }
                if !done.isEmpty {
                    Section("تمت اليوم (\(done.count))") {
                        ForEach(done) { item in
                            NavigationLink(value: item.house.id) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.house.ownerName).font(.headline)
                                    Text("\(item.house.district) • بيت \(item.house.houseNumber)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    if !item.visit.workTypes.isEmpty {
                                        Text(item.visit.workTypes.joined(separator: "، "))
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("اليوم")
            .navigationDestination(for: UUID.self) { id in
                HouseDetailView(houseID: id)
            }
        }
    }

    private func pendingRow(_ item: PendingItem, color: Color) -> some View {
        NavigationLink(value: item.house.id) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.house.ownerName).font(.headline)
                Text("\(item.house.district) • بيت \(item.house.houseNumber)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if let d = item.visit.followUpDate {
                    Text("الموعد: \(Fmt.short(d))")
                        .font(.caption)
                        .foregroundColor(color)
                }
                if !item.visit.notes.isEmpty {
                    Text(item.visit.notes)
                        .font(.caption)
                        .lineLimit(2)
                }
            }
        }
    }
}
