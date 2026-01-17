import SwiftUI
import SwiftData

struct BillersView: View {
    @Query(sort: \BillerMapping.category) private var billerMappings: [BillerMapping]
    @Environment(\.modelContext) private var modelContext
    
    @State private var showingAddSheet = false
    @State private var editingMapping: BillerMapping?
    @State private var searchText = ""
    
    let onMappingsChanged: () -> Void
    
    private var filteredMappings: [BillerMapping] {
        if searchText.isEmpty {
            return billerMappings
        }
        return billerMappings.filter { mapping in
            mapping.biller.localizedCaseInsensitiveContains(searchText) ||
            mapping.category.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var groupedMappings: [String: [BillerMapping]] {
        Dictionary(grouping: filteredMappings) { $0.category }
    }
    
    var body: some View {
        List {
            ForEach(groupedMappings.keys.sorted(), id: \.self) { category in
                Section {
                    ForEach(groupedMappings[category] ?? []) { mapping in
                        HStack {
                            Text(mapping.biller)
                                .font(.system(.body, design: .monospaced))
                            
                            Spacer()
                            
                            Button {
                                editingMapping = mapping
                            } label: {
                                Image(systemName: "pencil.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteMapping(mapping)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                    }
                } header: {
                    Label(category, systemImage: AppTheme.iconForCategory(category))
                        .foregroundStyle(AppTheme.colorForCategory(category))
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollIndicators(.hidden)
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
                mode: .add,
                onSave: {
                    onMappingsChanged()
                    MappingStorage.shared.refreshMappings()
                }
            )
        }
        .sheet(item: $editingMapping) { mapping in
            BillerEditView(
                mode: .edit(mapping: mapping),
                onSave: {
                    onMappingsChanged()
                    MappingStorage.shared.refreshMappings()
                }
            )
        }
        .overlay {
            if billerMappings.isEmpty {
                ContentUnavailableView(
                    "No Billers",
                    systemImage: "building.2",
                    description: Text("Add billers to automatically categorize your expenses")
                )
            }
        }
    }
    
    private func deleteMapping(_ mapping: BillerMapping) {
        modelContext.delete(mapping)
        try? modelContext.save()
        onMappingsChanged()
        MappingStorage.shared.refreshMappings()
    }
}

struct BillerEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    
    enum Mode {
        case add
        case edit(mapping: BillerMapping)
    }
    
    let mode: Mode
    let onSave: () -> Void
    
    @State private var biller: String = ""
    @State private var category: String = "Other"
    
    private let categories = AppTheme.allCategories
    
    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }
    
    private var editingMapping: BillerMapping? {
        if case .edit(let mapping) = mode { return mapping }
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
                if case .edit(let mapping) = mode {
                    biller = mapping.biller
                    category = mapping.category
                }
            }
        }
    }
    
    private func save() {
        let trimmedBiller = biller.trimmingCharacters(in: .whitespaces).uppercased()
        guard !trimmedBiller.isEmpty else { return }
        
        if let mapping = editingMapping {
            // Update existing
            if mapping.biller != trimmedBiller {
                // Biller name changed - delete old, create new (unique constraint)
                modelContext.delete(mapping)
                let newMapping = BillerMapping(biller: trimmedBiller, category: category)
                modelContext.insert(newMapping)
            } else {
                mapping.category = category
            }
        } else {
            // Add new
            let newMapping = BillerMapping(biller: trimmedBiller, category: category)
            modelContext.insert(newMapping)
        }
        
        try? modelContext.save()
        onSave()
        dismiss()
    }
}

#Preview {
    NavigationStack {
        BillersView(onMappingsChanged: {})
    }
}
