import SwiftUI

struct ViewerItem: Identifiable {
    let id = UUID()
    let index: Int
}

struct VisitDetailView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    let houseID: UUID
    let visitID: UUID

    @State private var showEdit = false
    @State private var showDelete = false
    @State private var viewer: ViewerItem?

    var body: some View {
        if let house = store.house(houseID), let visit = store.visit(houseID: houseID, visitID: visitID) {
            List {
                Section {
                    row("التاريخ", Fmt.full(visit.date))
                    row("الحالة", visit.status.title)
                    if visit.status == .followUp, let d = visit.followUpDate {
                        row("موعد المتابعة", Fmt.short(d))
                    }
                    if !visit.workers.isEmpty {
                        row("العمال", visit.workers)
                    }
                    if !visit.workTypes.isEmpty {
                        row("نوع العمل", visit.workTypes.joined(separator: "، "))
                    }
                }

                if !visit.notes.isEmpty {
                    Section("تفاصيل الزيارة") {
                        Text(visit.notes)
                    }
                }

                if !visit.photos.isEmpty {
                    Section("صور بعد الإنجاز") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                            ForEach(Array(visit.photos.enumerated()), id: \.offset) { index, name in
                                StoredPhoto(name: name)
                                    .frame(width: 100, height: 100)
                                    .clipped()
                                    .cornerRadius(8)
                                    .onTapGesture { viewer = ViewerItem(index: index) }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showDelete = true
                    } label: {
                        Label("حذف الزيارة", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("تفاصيل الزيارة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("تعديل") { showEdit = true }
                }
            }
            .sheet(isPresented: $showEdit) {
                VisitFormView(houseID: house.id, editing: visit)
            }
            .fullScreenCover(item: $viewer) { item in
                PhotoViewer(names: visit.photos, start: item.index)
            }
            .alert("حذف الزيارة؟", isPresented: $showDelete) {
                Button("حذف", role: .destructive) {
                    store.deleteVisit(houseID: houseID, visitID: visitID)
                    dismiss()
                }
                Button("إلغاء", role: .cancel) {}
            } message: {
                Text("سيتم حذف الزيارة وصورها نهائيًا.")
            }
        } else {
            Text("الزيارة غير موجودة").foregroundColor(.secondary)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
    }
}

struct PhotoViewer: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    let names: [String]
    @State private var index: Int

    init(names: [String], start: Int) {
        self.names = names
        _index = State(initialValue: start)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TabView(selection: $index) {
                ForEach(Array(names.enumerated()), id: \.offset) { i, name in
                    Group {
                        if let img = store.image(name) {
                            Image(uiImage: img).resizable().scaledToFit()
                        }
                    }
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
            }
        }
    }
}
