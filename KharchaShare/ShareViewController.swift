import UIKit
import Social
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        handleSharedContent()
    }
    
    private func handleSharedContent() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            completeRequest(success: false)
            return
        }
        
        for item in extensionItems {
            guard let attachments = item.attachments else { continue }
            
            for attachment in attachments {
                // Handle plain text
                if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] (data, error) in
                        if let text = data as? String {
                            self?.processSMS(text: text)
                        } else {
                            self?.completeRequest(success: false)
                        }
                    }
                    return
                }
                
                // Handle URL (sometimes text is shared as URL)
                if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (data, error) in
                        if let url = data as? URL {
                            self?.processSMS(text: url.absoluteString)
                        } else {
                            self?.completeRequest(success: false)
                        }
                    }
                    return
                }
            }
        }
        
        completeRequest(success: false)
    }
    
    private func processSMS(text: String) {
        // Save to shared queue
        let queueStorage = SharedQueueStorage.shared
        queueStorage.addToQueue(smsText: text)
        
        // Show brief success feedback
        DispatchQueue.main.async {
            self.showSuccessAndDismiss()
        }
    }
    
    private func showSuccessAndDismiss() {
        // Create a simple success view
        let successView = UIView()
        successView.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 0.95)
        successView.layer.cornerRadius = 16
        successView.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let checkmark = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        checkmark.tintColor = UIColor(red: 0.9, green: 0.03, blue: 0.08, alpha: 1.0)
        checkmark.contentMode = .scaleAspectFit
        checkmark.translatesAutoresizingMaskIntoConstraints = false
        checkmark.heightAnchor.constraint(equalToConstant: 50).isActive = true
        checkmark.widthAnchor.constraint(equalToConstant: 50).isActive = true
        
        let label = UILabel()
        label.text = "Added to Kharcha"
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        
        let sublabel = UILabel()
        sublabel.text = "Open app to review"
        sublabel.textColor = .lightGray
        sublabel.font = .systemFont(ofSize: 13)
        
        stackView.addArrangedSubview(checkmark)
        stackView.addArrangedSubview(label)
        stackView.addArrangedSubview(sublabel)
        
        successView.addSubview(stackView)
        view.addSubview(successView)
        
        NSLayoutConstraint.activate([
            successView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            successView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            successView.widthAnchor.constraint(equalToConstant: 200),
            successView.heightAnchor.constraint(equalToConstant: 140),
            stackView.centerXAnchor.constraint(equalTo: successView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: successView.centerYAnchor)
        ])
        
        // Auto dismiss after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.completeRequest(success: true)
        }
    }
    
    private func completeRequest(success: Bool) {
        if success {
            extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        } else {
            let error = NSError(domain: "com.kunalm.kharcha.share", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unable to process shared content"])
            extensionContext?.cancelRequest(withError: error)
        }
    }
}

