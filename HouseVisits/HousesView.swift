import SwiftUI

struct DistrictGroup: Identifiable {
    let district: String
    let houses: [House]
    var id: String { district }
}

struct HousesView: View {
    @EnvironmentObject var store: Store
    @State private var search = ""
    @State private var showAdd = false
    @State private var houseToDelete: House?
    @State private var showDeleteAlert = false

    private var groups: [DistrictGroup] {
        let q = search.trimmed.normalizedDigits
        let list = store.houses.filter { h in
            q.isEmpty
                || h.ownerName.contains(q)
                || h.houseNumber.contains(q)
                || h.district.contains(q)
        }
        let dict = Dictionary(grouping: list, by: { $0.district })
        return dict.keys.sorted().map { key in
            let sorted = (dict[key] ?? []).sorted {
                $0.houseNumber.localizedStandardCompare($1.houseNumber) == .orderedAscending
            }
            return DistrictGroup(district: key, houses: sorted)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.houses.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "house")
                            .font(.system(size: 52))
                            .foregroundColor(.secondary)
                        Text("ما فيه بيوت بعد")
                            .font(.headline)
                        Text("اضغط زر + لإضافة أول بيت")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(groups) { group in
                            Section(group.district) {
                                ForEach(group.houses) { house in
                                    NavigationLink(value: house.id) {
                                        HouseRow(house: house)
                                    }
                                    .swipeActions {
                                        Button(role: .destructive) {
                                            houseToDelete = house
                                            showDeleteAlert = true
                                        } label: {
                                            Label("حذف", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("البيوت")
            .searchable(text: $search, prompt: "ابحث بالاسم أو رقم البيت أو الحي")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(for: UUID.self) { id in
                HouseDetailView(houseID: id)
            }
            .sheet(isPresented: $showAdd) {
                HouseFormView()
            }
            .alert("حذف البيت؟", isPresented: $showDeleteAlert, presenting: houseToDelete) { h in
                Button("حذف", role: .destructive) { store.deleteHouse(h.id) }
                Button("إلغاء", role: .cancel) {}
            } message: { h in
                Text("سيتم حذف بيت \(h.ownerName) مع كل زياراته وصوره.")
            }
        }
    }
}

struct HouseRow: View {
    let house: House

    private var summary: String {
        if let last = house.lastVisit {
            return "\(house.visits.count) زيارة • آخر زيارة \(Fmt.short(last.date))"
        }
        return "لا توجد زيارات"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(house.ownerName).font(.headline)
                Spacer()
                if house.needsFollowUp {
                    Label("متابعة", systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            Text("بيت رقم \(house.houseNumber)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(summary)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct HouseFormView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    let editing: House?
    @State private var owner: String
    @State private var number: String
    @State private var district: String

    init(editing: House? = nil) {
        self.editing = editing
        _owner = State(initialValue: editing?.ownerName ?? "")
        _number = State(initialValue: editing?.houseNumber ?? "")
        _district = State(initialValue: editing?.district ?? "")
    }

    private var districts: [String] {
        Array(Set(store.houses.map { $0.district })).sorted()
    }

    private var canSave: Bool {
        !owner.trimmed.isEmpty && !number.trimmed.isEmpty && !district.trimmed.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("بيانات البيت") {
                    TextField("اسم صاحب البيت", text: $owner)
                    TextField("رقم البيت", text: $number)
                    TextField("اسم الحي", text: $district)
                    if !districts.isEmpty {
                        Menu("اختر من الأحياء المضافة") {
                            ForEach(districts, id: \.self) { d in
                                Button(d) { district = d }
                            }
                        }
                    }
                }
            }
            .navigationTitle(editing == nil ? "بيت جديد" : "تعديل البيت")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("حفظ") { save() }.disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        if let editing = editing {
            store.updateHouse(id: editing.id, owner: owner, number: number, district: district)
        } else {
            store.addHouse(owner: owner, number: number, district: district)
        }
        dismiss()
    }
}
