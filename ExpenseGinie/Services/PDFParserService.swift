import Foundation
import PDFKit
import SwiftUI

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Statement Type
enum StatementType: String, CaseIterable {
    case bank = "Bank Statement"
    case creditCard = "Credit Card Statement"
    
    var icon: String {
        switch self {
        case .bank: return "building.columns.fill"
        case .creditCard: return "creditcard.fill"
        }
    }
    
    var menuTitle: String {
        switch self {
        case .bank: return "Analyse Bank Statement"
        case .creditCard: return "Analyse Credit Card Statement"
        }
    }
    
    var importTitle: String {
        switch self {
        case .bank: return "Import Bank Statement"
        case .creditCard: return "Import Credit Card Statement"
        }
    }
    
    var description: String {
        switch self {
        case .bank: return "Upload a savings/current account statement to extract debits and withdrawals"
        case .creditCard: return "Upload a credit card statement to extract purchases and charges"
        }
    }
}

// MARK: - Parsed Transaction from PDF
struct ParsedTransaction: Identifiable, Codable {
    let id: UUID
    let date: Date
    let description: String
    let amount: Double
    let category: String
    let detectedCurrency: DetectedCurrency
    
    init(date: Date, description: String, amount: Double, category: String = "Other", currency: DetectedCurrency = .inr) {
        self.id = UUID()
        self.date = date
        self.description = description
        self.amount = amount
        self.category = category
        self.detectedCurrency = currency
    }
}

// MARK: - PDF Parser Result
enum PDFParseResult {
    case success([ParsedTransaction], parsedWithAI: Bool)
    case noTransactionsFound
    case extractionFailed(String)
    case llmNotAvailable
}

// MARK: - LLM Availability Status
enum LLMStatus {
    case enabled       // iOS 26+ and Apple Intelligence is enabled
    case notEnabled    // iOS 26+ but Apple Intelligence not enabled
    case unavailable   // iOS < 26 or hardware not supported
    
    var statusText: String {
        switch self {
        case .enabled: return "Enabled"
        case .notEnabled: return "Enable"
        case .unavailable: return "Unavailable"
        }
    }
    
    var icon: String {
        switch self {
        case .enabled: return "checkmark.circle.fill"
        case .notEnabled, .unavailable: return "xmark.circle.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .enabled: return .green
        case .notEnabled, .unavailable: return .red
        }
    }
    
    var canOpenSettings: Bool {
        switch self {
        case .enabled, .notEnabled: return true
        case .unavailable: return false
        }
    }
}

// MARK: - LLM Availability & Settings
class LLMAvailability: ObservableObject {
    static let shared = LLMAvailability()
    
    private let defaults = UserDefaults.standard
    private let aiParsingEnabledKey = "aiStatementParsingEnabled"
    
    @Published var status: LLMStatus = .unavailable
    
    @Published var isAIParsingEnabled: Bool {
        didSet {
            // Only save if status allows it
            if status == .enabled {
                defaults.set(isAIParsingEnabled, forKey: aiParsingEnabledKey)
            }
        }
    }
    
    private init() {
        // Default to false - user must opt-in
        self.isAIParsingEnabled = defaults.bool(forKey: aiParsingEnabledKey)
        checkStatus()
    }
    
    // Reset toggle to false if AI becomes unavailable
    func resetIfUnavailable() {
        if status != .enabled && isAIParsingEnabled {
            isAIParsingEnabled = false
            defaults.set(false, forKey: aiParsingEnabledKey)
        }
    }
    
    // Check if iOS version supports Foundation Models
    var isOSSupported: Bool {
        if #available(iOS 26.0, *) {
            #if canImport(FoundationModels)
            return true
            #else
            return false
            #endif
        }
        return false
    }
    
    // Whether AI parsing should be used (enabled + available)
    var shouldUseAIParsing: Bool {
        return isAIParsingEnabled && status == .enabled
    }
    
    func checkStatus() {
        #if canImport(FoundationModels)
        print("🔍 FoundationModels available at compile time")
        if #available(iOS 26.0, *) {
            print("🔍 iOS 26.0+ detected, checking Apple Intelligence status...")
            // Try to check if Apple Intelligence is available
            // by attempting to create a session
            Task {
                let isEnabled = await checkAppleIntelligenceEnabled()
                await MainActor.run {
                    self.status = isEnabled ? .enabled : .notEnabled
                    print("🔍 Apple Intelligence status: \(isEnabled ? "enabled" : "not enabled")")
                    self.resetIfUnavailable()
                }
            }
            return
        }
        #else
        print("🔍 FoundationModels NOT available at compile time")
        #endif
        status = .unavailable
        resetIfUnavailable()
        print("🔍 Status set to unavailable")
    }
    
    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func checkAppleIntelligenceEnabled() async -> Bool {
        do {
            // Try to create a session - this will fail if Apple Intelligence is not enabled
            let session = LanguageModelSession()
            // Try a minimal request to verify it works
            _ = try await session.respond(to: "Hi")
            return true
        } catch {
            // Session creation or request failed - Apple Intelligence not enabled
            return false
        }
    }
    #endif
}

// MARK: - PDF Parser Service (Coordinator)
@MainActor
class PDFParserService: ObservableObject {
    static let shared = PDFParserService()
    
    @Published var isProcessing = false
    @Published var processingStatus = ""
    
    private let bankParser = BankStatementParser.shared
    private let creditCardParser = CreditCardStatementParser.shared
    
    private init() {}
    
    // MARK: - Main Parse Function (delegates to specific parser)
    func parseStatement(from url: URL, type: StatementType) async -> PDFParseResult {
        isProcessing = true
        
        // Observe the specific parser's status
        switch type {
        case .bank:
            processingStatus = bankParser.processingStatus.isEmpty ? "Processing..." : bankParser.processingStatus
        case .creditCard:
            processingStatus = creditCardParser.processingStatus.isEmpty ? "Processing..." : creditCardParser.processingStatus
        }
        
        defer {
            isProcessing = false
            processingStatus = ""
        }
        
        // Delegate to the appropriate parser
        switch type {
        case .bank:
            print("📄 Delegating to BankStatementParser...")
            return await bankParser.parse(from: url)
        case .creditCard:
            print("📄 Delegating to CreditCardStatementParser...")
            return await creditCardParser.parse(from: url)
        }
    }
    
    // Legacy function for backward compatibility
    func parseBankStatement(from url: URL) async -> PDFParseResult {
        return await parseStatement(from: url, type: .bank)
    }
    
    // MARK: - PDF Text Extraction
    private func extractText(from url: URL) -> String? {
        guard let document = PDFDocument(url: url) else {
            return nil
        }
        
        var fullText = ""
        for pageIndex in 0..<document.pageCount {
            if let page = document.page(at: pageIndex),
               let pageText = page.string {
                fullText += pageText + "\n"
            }
        }
        
        return fullText
    }
    
    // MARK: - Foundation Models Parsing (iOS 26.0+)
    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func parseWithFoundationModels(text: String) async -> PDFParseResult {
        print("🤖 Starting AI parsing with Foundation Models...")
        do {
            let transactions = try await callFoundationModel(with: text)
            if transactions.isEmpty {
                // If LLM returns nothing, try heuristics
                print("🤖 AI returned no transactions, falling back to heuristics")
                return parseWithHeuristics(text: text)
            }
            print("🤖 AI successfully parsed \(transactions.count) transactions")
            return .success(transactions, parsedWithAI: true)
        } catch {
            let errorString = String(describing: error)
            print("🤖 Foundation Models error: \(error)")
            
            // Check if it's a context window error
            if errorString.contains("exceededContextWindowSize") || errorString.contains("context") {
                print("🤖 Context window exceeded, trying with smaller text...")
                // Try again with even smaller text (half size)
                let smallerText = String(text.prefix(3000))
                do {
                    let transactions = try await callFoundationModel(with: smallerText)
                    if !transactions.isEmpty {
                        print("🤖 Retry with smaller text succeeded: \(transactions.count) transactions")
                        return .success(transactions, parsedWithAI: true)
                    }
                } catch {
                    print("🤖 Retry also failed: \(error)")
                }
            }
            
            print("🤖 Falling back to heuristics due to error")
            // Fallback to heuristics if LLM fails
            return parseWithHeuristics(text: text)
        }
    }
    
    @available(iOS 26.0, *)
    private func callFoundationModel(with text: String) async throws -> [ParsedTransaction] {
        // Create a language model session
        let session = LanguageModelSession()
        
        // Truncate text if too long (LLM context limit is 4096 tokens)
        // Tokens ≈ chars / 3-4 for mixed content
        // Prompt takes ~300-400 tokens, need room for response (~500 tokens)
        // Safe limit: ~3000 tokens for text = ~9000-12000 chars
        // Being conservative with 6000 chars
        let maxLength = 6000
        var truncatedText = text
        
        if text.count > maxLength {
            // Try to truncate at a line boundary to avoid cutting mid-transaction
            let prefix = String(text.prefix(maxLength))
            if let lastNewline = prefix.lastIndex(of: "\n") {
                truncatedText = String(prefix[..<lastNewline])
            } else {
                truncatedText = prefix
            }
            print("🤖 PDF text truncated from \(text.count) to \(truncatedText.count) chars")
        }
        
        print("🤖 PDF text length: \(truncatedText.count) chars")
        
        // Create the prompt for transaction extraction
        let prompt = """
        You are a bank/credit card statement parser. Extract all EXPENSE transactions (money spent/charged).

        For each transaction, extract:
        - date: transaction date in DD/MM/YYYY format
        - description: merchant/vendor name only (max 50 chars)
        - amount: numeric value (positive number, no currency symbol or commas)
        - category: one of [Housing & Rent, Utilities, Groceries, Food & Dining, Transport & Fuel, Shopping, Medical & Healthcare, Entertainment, Subscriptions, Bills & Recharge, Insurance, Debt & EMI, Investments, Education & Learning, Travel & Vacation, Banking & Fees, UPI / Petty Cash, Other]

        IMPORTANT RULES:
        - For CREDIT CARD statements: Extract purchases, charges, fees (EXCLUDE payments, credits, refunds)
        - For BANK statements: Extract debits, withdrawals, transfers OUT (EXCLUDE credits, deposits, incoming)
        - Look for keywords like: POS, ATM, UPI, IMPS, NEFT, purchase, paid, charged
        - Skip entries with: CREDIT, PAYMENT RECEIVED, REFUND, REVERSAL, CASHBACK
        - Return ONLY a JSON array, no explanation or markdown

        Statement Text:
        \(truncatedText)

        JSON Response:
        """
        
        print("🤖 Sending prompt to LLM...")
        
        // Call the model
        let response = try await session.respond(to: prompt)
        
        print("🤖 LLM raw response: \(response.content)")
        
        // Parse the JSON response
        let transactions = parseJSONResponse(response.content)
        print("🤖 Parsed \(transactions.count) transactions from response")
        return transactions
    }
    
    @available(iOS 26.0, *)
    private func parseJSONResponse(_ response: String) -> [ParsedTransaction] {
        print("🔧 Parsing JSON response...")
        
        // Clean up response - remove markdown code blocks if present
        var jsonString = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("🔧 After cleanup: \(jsonString.prefix(200))...")
        
        // Try to find JSON array in response
        if let startIndex = jsonString.firstIndex(of: "["),
           let endIndex = jsonString.lastIndex(of: "]") {
            jsonString = String(jsonString[startIndex...endIndex])
            print("🔧 Extracted JSON array: \(jsonString.prefix(300))...")
        } else {
            print("🔧 No JSON array found in response!")
            return []
        }
        
        guard let data = jsonString.data(using: .utf8) else {
            print("🔧 Failed to convert response to data")
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            // Define a struct to match LLM output
            struct LLMTransaction: Codable {
                let date: String
                let description: String
                let amount: Double
                let category: String
            }
            
            let llmTransactions = try decoder.decode([LLMTransaction].self, from: data)
            print("🔧 Decoded \(llmTransactions.count) transactions from JSON")
            
            // Support multiple date formats
            let dateFormats = [
                "yyyy-MM-dd",      // 2025-09-04
                "dd/MM/yyyy",      // 04/09/2025
                "dd-MM-yyyy",      // 04-09-2025
                "MM/dd/yyyy",      // 09/04/2025
                "dd/MM/yy",        // 04/09/25
                "dd-MM-yy",        // 04-09-25
            ]
            
            let transactions = llmTransactions.compactMap { llm -> ParsedTransaction? in
                // Try parsing date with multiple formats
                var parsedDate: Date?
                for format in dateFormats {
                    dateFormatter.dateFormat = format
                    if let date = dateFormatter.date(from: llm.date) {
                        parsedDate = date
                        break
                    }
                }
                
                guard let date = parsedDate else {
                    print("🔧 Failed to parse date: \(llm.date)")
                    return nil
                }
                
                return ParsedTransaction(
                    date: date,
                    description: llm.description,
                    amount: llm.amount,
                    category: validateCategory(llm.category)
                )
            }
            
            print("🔧 Successfully created \(transactions.count) ParsedTransaction objects")
            return transactions
        } catch {
            print("🔧 JSON parsing error: \(error)")
            return []
        }
    }
    
    private func validateCategory(_ category: String) -> String {
        let validCategories = AppTheme.allCategories
        return validCategories.contains(category) ? category : "Other"
    }
    #endif
    
    // MARK: - Heuristic Parsing (Fallback)
    private func parseWithHeuristics(text: String) -> PDFParseResult {
        let transactions = parseTransactionsHeuristically(from: text)
        
        if transactions.isEmpty {
            return .noTransactionsFound
        }
        return .success(transactions, parsedWithAI: false)
    }
    
    private func parseTransactionsHeuristically(from text: String) -> [ParsedTransaction] {
        var transactions: [ParsedTransaction] = []
        
        let lines = text.components(separatedBy: .newlines)
        
        // Common date patterns in Indian bank statements
        let datePatterns = [
            "\\d{1,2}/\\d{1,2}/\\d{2,4}",      // DD/MM/YY or DD/MM/YYYY
            "\\d{1,2}-\\d{1,2}-\\d{2,4}",      // DD-MM-YY or DD-MM-YYYY
            "\\d{1,2}-[A-Za-z]{3}-\\d{2,4}",   // DD-Mon-YY or DD-Mon-YYYY
            "\\d{1,2}\\s+[A-Za-z]{3}\\s+\\d{2,4}" // DD Mon YY
        ]
        
        // Amount patterns (looking for debits)
        let amountPattern = "([\\d,]+\\.\\d{2})"
        
        // Keywords indicating debit transactions
        let debitKeywords = ["DR", "DEBIT", "PAID", "PURCHASE", "POS", "ATM", "IMPS", "NEFT", "UPI", "RTGS", "WITHDRAWAL"]
        
        var i = 0
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines
            guard !line.isEmpty else {
                i += 1
                continue
            }
            
            // Try to find a date in this line
            var foundDate: Date?
            for pattern in datePatterns {
                if let range = line.range(of: pattern, options: .regularExpression) {
                    let dateString = String(line[range])
                    foundDate = parseDate(dateString)
                    if foundDate != nil { break }
                }
            }
            
            // If we found a date, look for amount and description
            if let date = foundDate {
                // Combine this line and next few lines for context
                var contextLines = [line]
                for j in 1...3 where i + j < lines.count {
                    contextLines.append(lines[i + j])
                }
                let context = contextLines.joined(separator: " ")
                
                // Check if this looks like a debit transaction
                let isDebit = debitKeywords.contains { context.uppercased().contains($0) }
                
                // Find amount
                if let amountRange = context.range(of: amountPattern, options: .regularExpression) {
                    let amountString = String(context[amountRange])
                        .replacingOccurrences(of: ",", with: "")
                    
                    if let amount = Double(amountString), amount > 0 {
                        // Extract description (text between date and amount, or nearby text)
                        let description = extractDescription(from: context, date: date)
                        
                        // Only add if it looks like a debit or we're not sure
                        if isDebit || !context.uppercased().contains("CR") {
                            let transaction = ParsedTransaction(
                                date: date,
                                description: description,
                                amount: amount,
                                category: categorizeTransaction(description)
                            )
                            transactions.append(transaction)
                        }
                    }
                }
            }
            
            i += 1
        }
        
        // Remove duplicates based on date + amount + similar description
        return removeDuplicates(from: transactions)
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formats = [
            "dd/MM/yy", "dd/MM/yyyy",
            "dd-MM-yy", "dd-MM-yyyy",
            "dd-MMM-yy", "dd-MMM-yyyy",
            "dd MMM yy", "dd MMM yyyy"
        ]
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                // Adjust year if needed (for 2-digit years)
                let calendar = Calendar.current
                let year = calendar.component(.year, from: date)
                if year < 100 {
                    var components = calendar.dateComponents([.year, .month, .day], from: date)
                    components.year = 2000 + year
                    return calendar.date(from: components)
                }
                return date
            }
        }
        return nil
    }
    
    private func extractDescription(from context: String, date: Date) -> String {
        // Try to extract meaningful description
        // Remove date, amount, and common bank jargon
        var description = context
        
        // Remove common patterns
        let patternsToRemove = [
            "\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4}",  // Dates
            "[\\d,]+\\.\\d{2}",                    // Amounts
            "\\b(DR|CR|DEBIT|CREDIT)\\b",         // Transaction type markers
            "\\b\\d{10,}\\b",                      // Long numbers (reference numbers)
        ]
        
        for pattern in patternsToRemove {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                description = regex.stringByReplacingMatches(
                    in: description,
                    range: NSRange(description.startIndex..., in: description),
                    withTemplate: ""
                )
            }
        }
        
        // Clean up and truncate
        description = description
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Limit length
        if description.count > 50 {
            description = String(description.prefix(50)) + "..."
        }
        
        return description.isEmpty ? "Bank Transaction" : description
    }
    
    private func categorizeTransaction(_ description: String) -> String {
        BillerMapping.categorize(description)
    }
    
    private func removeDuplicates(from transactions: [ParsedTransaction]) -> [ParsedTransaction] {
        var seen = Set<String>()
        return transactions.filter { transaction in
            let key = "\(transaction.date.timeIntervalSince1970)-\(transaction.amount)"
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }
    }
    
    // MARK: - Cleanup
    private func deletePDF(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            print("PDF deleted successfully")
        } catch {
            print("Failed to delete PDF: \(error)")
        }
    }
}

// MARK: - Add to Queue Extension
extension PDFParserService {
    func addTransactionsToQueue(_ transactions: [ParsedTransaction], parsedWithAI: Bool, statementType: StatementType) {
        let queueStorage = SharedQueueStorage.shared
        
        // Convert StatementType to StatementSource
        let source: SharedQueueStorage.StatementSource = statementType == .bank ? .bank : .creditCard
        
        // Add to bank statement queue (not SMS queue)
        let expenses = transactions.map { transaction in
            (
                amount: transaction.amount,
                category: transaction.category,
                description: transaction.description,
                date: transaction.date,
                currency: transaction.detectedCurrency
            )
        }
        queueStorage.addMultipleFromBankStatement(expenses, parsedWithAI: parsedWithAI, source: source)
    }
}

