import SwiftUI
import PhotosUI
import UIKit

struct VisitFormView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    let houseID: UUID
    let editing: Visit?

    @State private var date: Date
    @State private var workers: String
    @State private var selected: Set<String>
    @State private var notes: String
    @State private var status: VisitStatus
    @State private var followUpDate: Date
    @State private var existingPhotos: [String]
    @State private var newImages: [UIImage] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showCamera = false

    init(houseID: UUID, editing: Visit? = nil) {
        self.houseID = houseID
        self.editing = editing
        _date = State(initialValue: editing?.date ?? Date())
        _workers = State(initialValue: editing?.workers ?? "")
        _selected = State(initialValue: Set(editing?.workTypes ?? []))
        _notes = State(initialValue: editing?.notes ?? "")
        _status = State(initialValue: editing?.status ?? .done)
        _followUpDate = State(initialValue: editing?.followUpDate
            ?? Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
        _existingPhotos = State(initialValue: editing?.photos ?? [])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("التاريخ") {
                    DatePicker("تاريخ الزيارة", selection: $date, displayedComponents: .date)
                }

                Section("العمال") {
                    TextField("أسماء العمال", text: $workers)
                }

                Section("نوع العمل") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
                        ForEach(WorkTypes.all, id: \.self) { type in
                            Button {
                                toggle(type)
                            } label: {
                                Text(type)
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(selected.contains(type) ? Color.accentColor : Color.gray.opacity(0.15))
                                    .foregroundColor(selected.contains(type) ? Color.white : Color.primary)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("تفاصيل الزيارة") {
                    TextField("ماذا تم في الزيارة؟", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("صور بعد الإنجاز") {
                    if !existingPhotos.isEmpty || !newImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(existingPhotos, id: \.self) { name in
                                    removable(onRemove: { existingPhotos.removeAll { $0 == name } }) {
                                        StoredPhoto(name: name)
                                    }
                                }
                                ForEach(Array(newImages.enumerated()), id: \.offset) { index, img in
                                    removable(onRemove: { newImages.remove(at: index) }) {
                                        Image(uiImage: img).resizable().scaledToFill()
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    PhotosPicker(selection: $pickerItems, maxSelectionCount: 10, matching: .images) {
                        Label("اختيار من الألبوم", systemImage: "photo.on.rectangle")
                    }
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button {
                            showCamera = true
                        } label: {
                            Label("تصوير بالكاميرا", systemImage: "camera")
                        }
                    }
                }

                Section("الحالة") {
                    Picker("الحالة", selection: $status) {
                        ForEach(VisitStatus.allCases, id: \.self) { s in
                            Text(s.title).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                    if status == .followUp {
                        DatePicker("موعد المتابعة", selection: $followUpDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle(editing == nil ? "زيارة جديدة" : "تعديل الزيارة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("حفظ") { save() }
                }
            }
            .onChange(of: pickerItems) { items in
                guard !items.isEmpty else { return }
                Task { await loadPicked(items) }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    newImages.append(image.resized(maxDimension: 1600))
                }
                .ignoresSafeArea()
            }
        }
    }

    private func toggle(_ type: String) {
        if selected.contains(type) {
            selected.remove(type)
        } else {
            selected.insert(type)
        }
    }

    private func loadPicked(_ items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                newImages.append(image.resized(maxDimension: 1600))
            }
        }
        pickerItems = []
    }

    private func removable<Content: View>(onRemove: @escaping () -> Void,
                                          @ViewBuilder content: () -> Content) -> some View {
        ZStack(alignment: .topTrailing) {
            content()
                .frame(width: 90, height: 90)
                .clipped()
                .cornerRadius(8)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white)
                    .background(Circle().fill(Color.black.opacity(0.5)))
            }
            .buttonStyle(.plain)
            .padding(4)
        }
    }

    private func save() {
        let saved = newImages.compactMap { store.savePhoto($0) }
        var visit = editing ?? Visit()
        visit.date = date
        visit.workers = workers.trimmed
        visit.workTypes = WorkTypes.all.filter { selected.contains($0) }
        visit.notes = notes.trimmed
        visit.status = status
        visit.followUpDate = status == .followUp ? followUpDate : nil
        visit.photos = existingPhotos + saved
        if editing != nil {
            store.updateVisit(houseID: houseID, visit: visit)
        } else {
            store.addVisit(houseID: houseID, visit: visit)
        }
        dismiss()
    }
}

struct StoredPhoto: View {
    @EnvironmentObject var store: Store
    let name: String

    var body: some View {
        Group {
            if let img = store.image(name) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Color.gray.opacity(0.2)
            }
        }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
