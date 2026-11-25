import SwiftUI

struct HouseDetailView: View {
    @EnvironmentObject var store: Store
    let houseID: UUID

    @State private var showNewVisit = false
    @State private var showEdit = false

    var body: some View {
        if let house = store.house(houseID) {
            List {
                Section {
                    VStack(spacing: 12) {
                        infoRow("اسم صاحب البيت", house.ownerName)
                        infoRow("رقم البيت", house.houseNumber)
                        infoRow("الحي", house.district)
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    HStack {
                        stat("عدد الزيارات", "\(house.visits.count)")
                        Divider()
                        stat("آخر زيارة", house.lastVisit.map { Fmt.short($0.date) } ?? "—")
                    }
                    if house.needsFollowUp, let d = house.lastVisit?.followUpDate {
                        Label("يحتاج متابعة بتاريخ \(Fmt.short(d))", systemImage: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                    }
                }

                Section {
                    Button {
                        showNewVisit = true
                    } label: {
                        Label("زيارة جديدة", systemImage: "plus.circle.fill")
                            .font(.headline)
                    }
                }

                Section("سجل الزيارات") {
                    if house.visits.isEmpty {
                        Text("لا توجد زيارات بعد").foregroundColor(.secondary)
                    }
                    ForEach(Array(house.sortedVisits.enumerated()), id: \.element.id) { index, visit in
                        NavigationLink(value: VisitRoute(houseID: house.id, visitID: visit.id)) {
                            VisitRow(visit: visit, number: house.visits.count - index)
                        }
                    }
                }
            }
            .navigationTitle("بطاقة البيت")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("تعديل") { showEdit = true }
                }
            }
            .navigationDestination(for: VisitRoute.self) { route in
                VisitDetailView(houseID: route.houseID, visitID: route.visitID)
            }
            .sheet(isPresented: $showNewVisit) {
                VisitFormView(houseID: houseID)
            }
            .sheet(isPresented: $showEdit) {
                HouseFormView(editing: house)
            }
        } else {
            Text("البيت غير موجود").foregroundColor(.secondary)
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold)
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.headline)
            Text(label).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct VisitRow: View {
    let visit: Visit
    let number: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("الزيارة \(number)").font(.headline)
                Spacer()
                Text(visit.status.title)
                    .font(.caption)
                    .foregroundColor(visit.status == .done ? .green : .orange)
            }
            Text(Fmt.short(visit.date))
                .font(.subheadline)
                .foregroundColor(.secondary)
            if !visit.workTypes.isEmpty {
                Text(visit.workTypes.joined(separator: "، "))
                    .font(.caption)
            }
            if !visit.photos.isEmpty {
                Label("\(visit.photos.count) صور", systemImage: "photo")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
