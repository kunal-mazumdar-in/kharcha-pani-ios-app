import SwiftUI
import PhotosUI
import Vision

struct BillScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeSettings: ThemeSettings
    
    // Multi-image support (max 2)
    @State private var capturedImages: [UIImage] = []
    @State private var currentImageTarget: ImageTarget = .first
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var tempSelectedImage: UIImage?
    
    @State private var isProcessing = false
    @State private var extractedText: String?
    @State private var parseError: String?
    @State private var parsedExpense: ParsedBillResult?
    
    // Editable fields (shared with BillResultForm)
    @State private var editedAmount: String = ""
    @State private var editedDescription: String = ""
    @State private var editedCategory: String = "Other"
    @State private var editedDate: Date = Date()
    
    let parser: SMSParser
    let onExpenseAdded: (Expense) -> Void
    
    enum ImageTarget {
        case first
        case second
    }
    
    private var tintColor: Color {
        themeSettings.accentColor.color
    }
    
    private var canSave: Bool {
        guard parsedExpense?.hasAnyParsedField == true else { return false }
        if let amt = Double(editedAmount.replacingOccurrences(of: ",", with: "")), 
           amt > 0, 
           !editedDescription.isEmpty {
            return true
        }
        return false
    }
    
    private var canProcess: Bool {
        !capturedImages.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isProcessing {
                    processingView
                } else if let error = parseError {
                    errorView(error)
                } else if let result = parsedExpense {
                    resultView(result)
                } else {
                    scannerView
                }
            }
            .navigationTitle("Scan Bill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                if parsedExpense?.hasAnyParsedField == true {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: saveExpense) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                        }
                        .disabled(!canSave)
                    }
                }
            }
            .sheet(isPresented: $showingCamera) {
                ImagePicker(image: $tempSelectedImage, sourceType: .camera)
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showingImagePicker) {
                MultiPhotoPicker(
                    maxSelection: 2 - capturedImages.count,
                    onImagesSelected: { images in
                        for image in images {
                            if capturedImages.count < 2 {
                                capturedImages.append(image)
                            }
                        }
                    }
                )
            }
            .onChange(of: tempSelectedImage) { _, newImage in
                if let image = newImage {
                    if capturedImages.count < 2 {
                        capturedImages.append(image)
                    }
                    tempSelectedImage = nil
                }
            }
        }
    }
    
    private func saveExpense() {
        guard let amt = Double(editedAmount.replacingOccurrences(of: ",", with: "")) else { return }
        let expense = Expense(
            amount: amt,
            category: editedCategory,
            biller: editedDescription,
            rawSMS: "Scanned: \(editedDescription) - \(amt.currencyFormatted)",
            date: editedDate
        )
        onExpenseAdded(expense)
        dismiss()
    }
    
    // MARK: - Scanner View (Initial Screen)
    private var scannerView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Icon
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 56))
                    .foregroundStyle(tintColor)
                    .padding(.top, 24)
                
                // Title & Description
                VStack(spacing: 8) {
                    Text("Scan Bill or Receipt")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Capture up to 2 photos")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                
                // Captured Images Preview
                if !capturedImages.isEmpty {
                    VStack(spacing: 12) {
                        Text("Captured Photos (\(capturedImages.count)/2)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 16) {
                            ForEach(Array(capturedImages.enumerated()), id: \.offset) { index, image in
                                CapturedImageThumbnail(
                                    image: image,
                                    label: index == 0 ? "Photo 1" : "Photo 2",
                                    onRemove: {
                                        capturedImages.remove(at: index)
                                    }
                                )
                            }
                            
                            // Add more placeholder if less than 2
                            if capturedImages.count < 2 {
                                AddImagePlaceholder(
                                    tintColor: tintColor,
                                    showingCamera: $showingCamera,
                                    showingImagePicker: $showingImagePicker
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.vertical, 16)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                }
                
                // Action Buttons
                VStack(spacing: 12) {
                    if capturedImages.isEmpty {
                        // Initial capture options
                        Button {
                            showingCamera = true
                        } label: {
                            Label("Take Photo", systemImage: "camera.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(tintColor)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        Button {
                            showingImagePicker = true
                        } label: {
                            Label("Choose from Photos", systemImage: "photo.on.rectangle")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .foregroundStyle(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    } else {
                        // Process button when images captured
                        Button {
                            processAllImages()
                        } label: {
                            Label("Scan \(capturedImages.count == 1 ? "Photo" : "Photos")", systemImage: "doc.text.magnifyingglass")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(tintColor)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        if capturedImages.count < 2 {
                            Menu {
                                Button {
                                    showingCamera = true
                                } label: {
                                    Label("Take Photo", systemImage: "camera.fill")
                                }
                                
                                Button {
                                    showingImagePicker = true
                                } label: {
                                    Label("Choose from Photos", systemImage: "photo.on.rectangle")
                                }
                            } label: {
                                Label("Add Another Photo", systemImage: "plus.circle")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(.secondarySystemBackground))
                                    .foregroundStyle(.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        
                        Button {
                            capturedImages.removeAll()
                        } label: {
                            Label("Clear All", systemImage: "trash")
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 40)
                
                Spacer(minLength: 40)
                
                // Tip for long bills
                if capturedImages.isEmpty {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(.yellow)
                            Text("Tip for long bills")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        Text("Take one photo of the top showing merchant name, and another of the bottom showing the total amount")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 40)
                }
                
                // Privacy Notice
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(.green)
                    
                    Text("Images processed locally on your device")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 24)
            }
        }
    }
    
    // MARK: - Processing View
    private var processingView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Scanning bill...")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Extracting text from image")
                .font(.caption)
                .foregroundStyle(.tertiary)
            
            Spacer()
            
            // Privacy reminder
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
                Text("Scan Failed")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button {
                resetState()
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
    
    // MARK: - Result View (Parsed Expense)
    private func resultView(_ result: ParsedBillResult) -> some View {
        BillResultForm(
            result: result,
            amount: $editedAmount,
            description: $editedDescription,
            category: $editedCategory,
            date: $editedDate,
            onRetry: {
                resetState()
            }
        )
    }
    
    // MARK: - Actions
    
    /// Process all captured images - combines OCR text from all images
    private func processAllImages() {
        guard !capturedImages.isEmpty else { return }
        
        isProcessing = true
        parseError = nil
        parsedExpense = nil
        
        Task {
            do {
                // Process all images and combine text
                var allTexts: [String] = []
                
                for (index, image) in capturedImages.enumerated() {
                    let text = try await performOCR(on: image)
                    if !text.isEmpty {
                        allTexts.append("--- Photo \(index + 1) ---\n\(text)")
                    }
                }
                
                // Combine all OCR text (preserving order: first image at top)
                let combinedText = allTexts.joined(separator: "\n\n")
                
                await MainActor.run {
                    isProcessing = false
                    extractedText = combinedText
                    
                    if combinedText.isEmpty {
                        parseError = "No text found in the images. Please try with clearer photos."
                        return
                    }
                    
                    // Try to parse the combined text
                    if let parsed = parser.parse(sms: combinedText) {
                        parsedExpense = ParsedBillResult(
                            amount: parsed.amount,
                            description: parsed.biller,
                            category: parsed.category,
                            date: parsed.date,
                            rawText: combinedText,
                            parserSucceeded: true
                        )
                        // Set editable fields
                        editedAmount = String(format: "%.2f", parsed.amount)
                        editedDescription = parsed.biller
                        editedCategory = parsed.category
                        editedDate = parsed.date
                    } else {
                        // Parser failed, try to extract at least amount
                        let extractedAmount = extractAmountFromText(combinedText)
                        parsedExpense = ParsedBillResult(
                            amount: extractedAmount,
                            description: "",
                            category: "Other",
                            date: Date(),
                            rawText: combinedText,
                            parserSucceeded: false
                        )
                        // Set editable fields
                        editedAmount = extractedAmount.map { String(format: "%.2f", $0) } ?? ""
                        editedDescription = ""
                        editedCategory = "Other"
                        editedDate = Date()
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    parseError = "Failed to scan: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Legacy single image processing (kept for backwards compatibility)
    private func processImage(_ image: UIImage) {
        capturedImages = [image]
        processAllImages()
    }
    
    private func performOCR(on image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                
                continuation.resume(returning: text)
            }
            
            // Configure for best accuracy
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US", "en-IN"]
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func extractAmountFromText(_ text: String) -> Double? {
        // Try to find amount patterns in the text
        let patterns = [
            "₹\\s*([\\d,]+\\.?\\d*)",
            "Rs\\.?\\s*([\\d,]+\\.?\\d*)",
            "INR\\s*([\\d,]+\\.?\\d*)",
            "Total:?\\s*₹?\\s*([\\d,]+\\.?\\d*)",
            "Amount:?\\s*₹?\\s*([\\d,]+\\.?\\d*)",
            "Grand Total:?\\s*₹?\\s*([\\d,]+\\.?\\d*)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                let amountString = String(text[range]).replacingOccurrences(of: ",", with: "")
                if let amount = Double(amountString) {
                    return amount
                }
            }
        }
        
        return nil
    }
    
    private func resetState() {
        capturedImages.removeAll()
        tempSelectedImage = nil
        extractedText = nil
        parseError = nil
        parsedExpense = nil
        isProcessing = false
    }
}

// MARK: - Captured Image Thumbnail

struct CapturedImageThumbnail: View {
    let image: UIImage
    let label: String
    let onRemove: () -> Void
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separator), lineWidth: 1)
                    )
                
                // Remove button
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white, .red)
                        .shadow(radius: 2)
                }
                .offset(x: 6, y: -6)
            }
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Add Image Placeholder

struct AddImagePlaceholder: View {
    let tintColor: Color
    @Binding var showingCamera: Bool
    @Binding var showingImagePicker: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            Menu {
                Button {
                    showingCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera.fill")
                }
                
                Button {
                    showingImagePicker = true
                } label: {
                    Label("Choose from Photos", systemImage: "photo.on.rectangle")
                }
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                        .foregroundStyle(tintColor)
                    
                    Text("Add")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 100, height: 100)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                        .foregroundStyle(tintColor.opacity(0.5))
                )
            }
            
            Text("Photo 2")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Supporting Types

enum OCRError: LocalizedError {
    case invalidImage
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Could not process the image"
        }
    }
}

struct ParsedBillResult {
    var amount: Double?
    var description: String
    var category: String
    var date: Date
    var rawText: String
    var parserSucceeded: Bool // True if SMSParser found at least something
    
    var hasAnyParsedField: Bool {
        // Check if we have at least one meaningful parsed value
        amount != nil || !description.isEmpty
    }
}

// MARK: - Bill Result Form

struct BillResultForm: View {
    let result: ParsedBillResult
    @Binding var amount: String
    @Binding var description: String
    @Binding var category: String
    @Binding var date: Date
    let onRetry: () -> Void
    
    @State private var showRawText = true // Show by default
    
    private let categories = AppTheme.allCategories
    
    var body: some View {
        Form {
            // Scanned Text (at the top, collapsible)
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showRawText.toggle()
                        }
                    } label: {
                        HStack {
                            Label("Scanned Text", systemImage: "doc.text")
                            Spacer()
                            Image(systemName: showRawText ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    if showRawText {
                        Text(result.rawText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            
            // Show helpful message if parsing couldn't extract details
            if !result.hasAnyParsedField {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(.orange)
                                .font(.title2)
                            
                            Text("We couldn't find expense details")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        Text("This can happen when:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                Text("The image is blurry or has poor lighting")
                            }
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                Text("Amount is not visible or couldn't be identified as a total")
                            }
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                Text("Text is too small or at an angle")
                            }
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                Text("Bill format is not commonly used")
                            }
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                Text("Handwritten receipts may not be recognized in some cases")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        
                        Text("You can try scanning again or use 'Add Manually' instead.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                }
                
                // Retry Button
                Section {
                    Button {
                        onRetry()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Scan Another", systemImage: "camera.fill")
                                .font(.headline)
                            Spacer()
                        }
                    }
                }
            } else {
                // Show editable fields when at least 1 field was parsed
                
                // Amount
                Section("Amount") {
                    HStack {
                        Text("₹")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .font(.title2)
                    }
                }
                
                // Description
                Section("Description") {
                    TextField("Merchant or description", text: $description)
                }
                
                // Category
                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { cat in
                            Label(cat, systemImage: AppTheme.iconForCategory(cat))
                                .tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Date
                Section("Date") {
                    DatePicker("Transaction Date", selection: $date, displayedComponents: .date)
                }
                
                // Retry Button
                Section {
                    Button {
                        onRetry()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Scan Another", systemImage: "camera.fill")
                                .font(.subheadline)
                            Spacer()
                        }
                    }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - Image Picker (Camera)

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Multi Photos Picker (Supports selecting up to N images)

struct MultiPhotoPicker: UIViewControllerRepresentable {
    let maxSelection: Int
    let onImagesSelected: ([UIImage]) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = maxSelection
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: MultiPhotoPicker
        
        init(_ parent: MultiPhotoPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            
            guard !results.isEmpty else { return }
            
            var loadedImages: [UIImage] = []
            let group = DispatchGroup()
            
            for result in results {
                group.enter()
                result.itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                    if let image = object as? UIImage {
                        DispatchQueue.main.async {
                            loadedImages.append(image)
                        }
                    }
                    group.leave()
                }
            }
            
            group.notify(queue: .main) { [weak self] in
                self?.parent.onImagesSelected(loadedImages)
            }
        }
    }
}

// MARK: - Legacy Single Photos Picker (for backwards compatibility)

struct PhotosPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotosPicker
        
        init(_ parent: PhotosPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            
            guard let result = results.first else { return }
            
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                if let image = object as? UIImage {
                    DispatchQueue.main.async {
                        self?.parent.selectedImage = image
                    }
                }
            }
        }
    }
}

#Preview {
    BillScannerView(
        parser: SMSParser(mappingStorage: MappingStorage.shared),
        onExpenseAdded: { _ in }
    )
    .environmentObject(ThemeSettings())
}

