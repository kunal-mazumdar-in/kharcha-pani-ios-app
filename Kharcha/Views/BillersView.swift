import SwiftUI

struct BillersView: View {
    @ObservedObject var mappingStorage: MappingStorage
    
    @State private var showingAddSheet = false
    @State private var editingMapping: (biller: String, category: String)?
    @State private var searchText = ""
    
    let onMappingsChanged: () -> Void
    
    private var sortedMappings: [(key: String, value: String)] {
        let filtered = mappingStorage.mappings.filter { mapping in
            searchText.isEmpty || 
            mapping.key.localizedCaseInsensitiveContains(searchText) ||
            mapping.value.localizedCaseInsensitiveContains(searchText)
        }
        return filtered.sorted { $0.value < $1.value }
    }
    
    private var groupedMappings: [String: [(key: String, value: String)]] {
        Dictionary(grouping: sortedMappings) { $0.value }
    }
    
    var body: some View {
        List {
            ForEach(groupedMappings.keys.sorted(), id: \.self) { category in
                Section {
                    ForEach(groupedMappings[category] ?? [], id: \.key) { mapping in
                        HStack {
                            Text(mapping.key)
                                .font(.system(.body, design: .monospaced))
                            
                            Spacer()
                            
                            Button {
                                editingMapping = (mapping.key, mapping.value)
                            } label: {
                                Image(systemName: "pencil.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                mappingStorage.deleteMapping(biller: mapping.key)
                                onMappingsChanged()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Label(category, systemImage: AppTheme.iconForCategory(category))
                        .foregroundStyle(AppTheme.colorForCategory(category))
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, prompt: "Search billers")
        .navigationTitle("Billers")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            BillerEditView(
                mappingStorage: mappingStorage,
                mode: .add,
                onSave: onMappingsChanged
            )
        }
        .sheet(item: Binding(
            get: { editingMapping.map { EditableBillerItem(biller: $0.biller, category: $0.category) } },
            set: { editingMapping = $0.map { ($0.biller, $0.category) } }
        )) { item in
            BillerEditView(
                mappingStorage: mappingStorage,
                mode: .edit(biller: item.biller, category: item.category),
                onSave: onMappingsChanged
            )
        }
        .overlay {
            if mappingStorage.mappings.isEmpty {
                ContentUnavailableView(
                    "No Billers",
                    systemImage: "building.2",
                    description: Text("Add billers to automatically categorize your expenses")
                )
            }
        }
    }
}

struct EditableBillerItem: Identifiable {
    let id = UUID()
    let biller: String
    let category: String
}

struct BillerEditView: View {
    @ObservedObject var mappingStorage: MappingStorage
    @Environment(\.dismiss) var dismiss
    
    enum Mode {
        case add
        case edit(biller: String, category: String)
    }
    
    let mode: Mode
    let onSave: () -> Void
    
    @State private var biller: String = ""
    @State private var category: String = "Other"
    
    private let categories = ["Banking", "Food", "Groceries", "Transport", "Shopping", "UPI", "Bills", "Entertainment", "Medical", "Other"]
    
    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }
    
    private var originalBiller: String? {
        if case .edit(let biller, _) = mode { return biller }
        return nil
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Biller Code", text: $biller)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                } header: {
                    Text("Biller")
                } footer: {
                    Text("Enter the biller code as it appears in SMS (e.g., HDFCBK, SWIGGY)")
                }
                
                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { cat in
                            Label(cat, systemImage: AppTheme.iconForCategory(cat))
                                .tag(cat)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
            }
            .navigationTitle(isEditing ? "Edit Biller" : "Add Biller")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(biller.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if case .edit(let b, let c) = mode {
                    biller = b
                    category = c
                }
            }
        }
    }
    
    private func save() {
        let trimmedBiller = biller.trimmingCharacters(in: .whitespaces)
        guard !trimmedBiller.isEmpty else { return }
        
        if let original = originalBiller {
            mappingStorage.updateMapping(oldBiller: original, newBiller: trimmedBiller, category: category)
        } else {
            mappingStorage.addMapping(biller: trimmedBiller, category: category)
        }
        onSave()
        dismiss()
    }
}

#Preview {
    NavigationStack {
        BillersView(mappingStorage: MappingStorage.shared, onMappingsChanged: {})
    }
}
