import SwiftUI
import UniformTypeIdentifiers

struct PDFImportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeSettings: ThemeSettings
    @StateObject private var parserService = PDFParserService.shared
    
    @State private var showingFilePicker = false
    @State private var parseError: String?
    
    let statementType: StatementType
    let onTransactionsAdded: (Int) -> Void
    
    private var tintColor: Color {
        themeSettings.accentColor.color
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if parserService.isProcessing {
                    processingView
                } else if let error = parseError {
                    errorView(error)
                } else {
                    uploadView
                }
            }
            .navigationTitle(statementType.importTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [UTType.pdf],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
        }
    }
    
    // MARK: - Upload View (Initial Screen)
    private var uploadView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon based on statement type
            Image(systemName: statementType.icon)
                .font(.system(size: 72))
                .foregroundStyle(tintColor)
            
            // Title & Description
            VStack(spacing: 12) {
                Text(statementType.importTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(statementType.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // Upload Button
            Button {
                showingFilePicker = true
            } label: {
                Label("Select PDF", systemImage: "doc.badge.plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(tintColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Privacy Notice
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(.green)
                
                Text("PDF is processed locally on your device")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Processing View
    private var processingView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.5)
            
            Text(parserService.processingStatus)
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("This may take a moment...")
                .font(.caption)
                .foregroundStyle(.tertiary)
            
            Spacer()
            
            // Privacy reminder during processing
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(.green)
                
                Text("Processing locally on your device")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Error View
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
            
            VStack(spacing: 8) {
                Text("Import Failed")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button {
                parseError = nil
            } label: {
                Label("Try Again", systemImage: "arrow.counterclockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(tintColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    // MARK: - Actions
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        parseError = nil
        
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            // Need to start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                parseError = "Cannot access the selected file"
                return
            }
            
            // Copy to temp location for processing
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("pdf")
            
            do {
                try FileManager.default.copyItem(at: url, to: tempURL)
                url.stopAccessingSecurityScopedResource()
                
                // Process the PDF with the appropriate parser
                Task {
                    let result = await parserService.parseStatement(from: tempURL, type: statementType)
                    
                    await MainActor.run {
                        switch result {
                        case .success(let transactions, let parsedWithAI):
                            // Add ALL transactions directly to queue with AI flag and statement type
                            parserService.addTransactionsToQueue(transactions, parsedWithAI: parsedWithAI, statementType: statementType)
                            let count = transactions.count
                            
                            // Notify parent FIRST, then dismiss
                            onTransactionsAdded(count)
                            dismiss()
                            
                        case .noTransactionsFound:
                            parseError = statementType == .bank 
                                ? "No debit transactions found in this bank statement"
                                : "No purchases found in this credit card statement"
                            
                        case .extractionFailed(let error):
                            parseError = error
                            
                        case .llmNotAvailable:
                            parseError = "AI parsing not available on this device"
                        }
                    }
                }
            } catch {
                url.stopAccessingSecurityScopedResource()
                parseError = "Failed to read PDF: \(error.localizedDescription)"
            }
            
        case .failure(let error):
            // User cancelled - just ignore
            if (error as NSError).code != NSUserCancelledError {
                parseError = "Failed to select file: \(error.localizedDescription)"
            }
        }
    }
}

#Preview("Bank Statement") {
    PDFImportView(statementType: .bank) { count in
        print("Added \(count) transactions")
    }
    .environmentObject(ThemeSettings())
}

#Preview("Credit Card") {
    PDFImportView(statementType: .creditCard) { count in
        print("Added \(count) transactions")
    }
    .environmentObject(ThemeSettings())
}
