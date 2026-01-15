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
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppTheme.textMuted)
                    TextField("Search billers or categories", text: $searchText)
                        .foregroundColor(AppTheme.textPrimary)
                }
                .padding(12)
                .background(AppTheme.cardBackground)
                .cornerRadius(10)
                .padding()
                
                // Stats bar
                HStack {
                    Label("\(mappingStorage.mappings.count) billers", systemImage: "building.2")
                    Spacer()
                    Label("\(Set(mappingStorage.mappings.values).count) categories", systemImage: "folder")
                }
                .font(.caption)
                .foregroundColor(AppTheme.textMuted)
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // Mappings list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(groupedMappings.keys.sorted(), id: \.self) { category in
                            VStack(alignment: .leading, spacing: 8) {
                                // Category header
                                HStack {
                                    Circle()
                                        .fill(AppTheme.colorForCategory(category))
                                        .frame(width: 10, height: 10)
                                    Text(category)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(AppTheme.textSecondary)
                                    
                                    Spacer()
                                    
                                    Text("\(groupedMappings[category]?.count ?? 0)")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.textMuted)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(AppTheme.cardBackgroundLight)
                                        .cornerRadius(10)
                                }
                                .padding(.horizontal)
                                
                                // Billers in this category
                                ForEach(groupedMappings[category] ?? [], id: \.key) { mapping in
                                    BillerRow(
                                        biller: mapping.key,
                                        category: mapping.value,
                                        onEdit: {
                                            editingMapping = (mapping.key, mapping.value)
                                        },
                                        onDelete: {
                                            mappingStorage.deleteMapping(biller: mapping.key)
                                            onMappingsChanged()
                                        }
                                    )
                                }
                            }
                            .padding(.bottom, 8)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle("Billers")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(AppTheme.accent)
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
    }
}

struct EditableBillerItem: Identifiable {
    let id = UUID()
    let biller: String
    let category: String
}

struct BillerRow: View {
    let biller: String
    let category: String
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Text(biller)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(AppTheme.textPrimary)
            
            Spacer()
            
            Button(action: onEdit) {
                Image(systemName: "pencil.circle.fill")
                    .font(.title3)
                    .foregroundColor(AppTheme.textSecondary)
            }
            
            Button(action: onDelete) {
                Image(systemName: "trash.circle.fill")
                    .font(.title3)
                    .foregroundColor(AppTheme.accent.opacity(0.7))
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(10)
    }
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
    @State private var category: String = ""
    
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
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header icon
                    ZStack {
                        Circle()
                            .fill(AppTheme.accent.opacity(0.2))
                            .frame(width: 70, height: 70)
                        Image(systemName: isEditing ? "pencil" : "plus")
                            .font(.title)
                            .foregroundColor(AppTheme.accent)
                    }
                    .padding(.top, 20)
                    
                    // Biller input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("BILLER CODE")
                            .font(.caption)
                            .foregroundColor(AppTheme.textMuted)
                        
                        TextField("e.g. HDFCBK, SWIGGY", text: $biller)
                            .textInputAutocapitalization(.characters)
                            .foregroundColor(AppTheme.textPrimary)
                            .padding()
                            .background(AppTheme.cardBackground)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    
                    // Category picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CATEGORY")
                            .font(.caption)
                            .foregroundColor(AppTheme.textMuted)
                        
                        Menu {
                            ForEach(categories, id: \.self) { cat in
                                Button(action: { category = cat }) {
                                    HStack {
                                        Text(cat)
                                        if category == cat {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                if category.isEmpty {
                                    Text("Select category")
                                        .foregroundColor(AppTheme.textMuted)
                                } else {
                                    Circle()
                                        .fill(AppTheme.colorForCategory(category))
                                        .frame(width: 12, height: 12)
                                    Text(category)
                                        .foregroundColor(AppTheme.textPrimary)
                                }
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(AppTheme.textMuted)
                            }
                            .padding()
                            .background(AppTheme.cardBackground)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Save button
                    Button(action: save) {
                        Text(isEditing ? "Update Biller" : "Add Biller")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                (biller.isEmpty || category.isEmpty) 
                                    ? AppTheme.textMuted 
                                    : AppTheme.accent
                            )
                            .cornerRadius(12)
                    }
                    .disabled(biller.isEmpty || category.isEmpty)
                    .padding()
                }
            }
            .navigationTitle(isEditing ? "Edit Biller" : "Add Biller")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.accent)
                }
            }
            .onAppear {
                if case .edit(let b, let c) = mode {
                    biller = b
                    category = c
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func save() {
        if let original = originalBiller {
            mappingStorage.updateMapping(oldBiller: original, newBiller: biller, category: category)
        } else {
            mappingStorage.addMapping(biller: biller, category: category)
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
