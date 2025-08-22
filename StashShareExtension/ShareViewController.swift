import UIKit
import Social
import UniformTypeIdentifiers
import CoreData

class ShareViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        handleSharedContent()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        let titleLabel = UILabel()
        titleLabel.text = "Add to Stash"
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let messageLabel = UILabel()
        messageLabel.text = "Processing your content..."
        messageLabel.font = .systemFont(ofSize: 16)
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = UIStackView(arrangedSubviews: [titleLabel, messageLabel])
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    private func handleSharedContent() {
        guard let extensionContext = extensionContext else {
            completeRequest()
            return
        }
        
        let itemProvider = extensionContext.inputItems.first as? NSExtensionItem
        guard let attachments = itemProvider?.attachments else {
            completeRequest()
            return
        }
        
        for attachment in attachments {
            if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                handleImageAttachment(attachment)
            } else if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                handleURLAttachment(attachment)
            } else if attachment.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                handleTextAttachment(attachment)
            }
        }
    }
    
    private func handleImageAttachment(_ attachment: NSItemProvider) {
        attachment.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] (data, error) in
            DispatchQueue.main.async {
                if let imageData = data as? Data {
                    self?.saveStashItem(type: "screenshot", content: imageData)
                }
                self?.completeRequest()
            }
        }
    }
    
    private func handleURLAttachment(_ attachment: NSItemProvider) {
        attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (data, error) in
            DispatchQueue.main.async {
                if let url = data as? URL {
                    self?.saveStashItem(type: "link", url: url.absoluteString)
                }
                self?.completeRequest()
            }
        }
    }
    
    private func handleTextAttachment(_ attachment: NSItemProvider) {
        attachment.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { [weak self] (data, error) in
            DispatchQueue.main.async {
                if let text = data as? String {
                    self?.saveStashItem(type: "text", content: text.data(using: .utf8))
                }
                self?.completeRequest()
            }
        }
    }
    
    private func saveStashItem(type: String, content: Data? = nil, url: String? = nil) {
        let container = NSPersistentContainer(name: "StashDataModel")
        container.loadPersistentStores { _, error in
            if let error = error {
                print("Core Data failed to load: \(error.localizedDescription)")
                return
            }
        }
        
        let context = container.viewContext
        let newItem = StashItem(context: context)
        newItem.id = UUID()
        newItem.type = type
        newItem.bucket = "inbox"
        newItem.createdAt = Date()
        newItem.updatedAt = Date()
        newItem.isProcessed = false
        newItem.userCorrectedBucket = false
        newItem.confidence = 0.0
        newItem.content = content
        newItem.url = url
        
        do {
            try context.save()
        } catch {
            print("Failed to save item: \(error.localizedDescription)")
        }
    }
    
    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}