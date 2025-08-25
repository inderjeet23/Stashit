import UIKit
import Social
import UniformTypeIdentifiers
import CoreData

class ShareViewController: UIViewController {
    // If you enable an App Group, set the same identifier here or
    // read from a shared defaults key. It should match DataController.appGroupID
    private let appGroupID: String? = "group.com.yourdomain.stash"
    
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
        guard let extensionContext = extensionContext else { completeRequest(); return }
        let itemProvider = extensionContext.inputItems.first as? NSExtensionItem
        guard let attachments = itemProvider?.attachments, attachments.isEmpty == false else { completeRequest(); return }

        let group = DispatchGroup()
        var handledAny = false

        for attachment in attachments {
            // Prefer URL, then text, then image for tweets/links
            if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                group.enter()
                handleURLAttachment(attachment) { didSave in 
                    handledAny = handledAny || didSave
                    group.leave() 
                }
                continue
            }
            if attachment.hasItemConformingToTypeIdentifier(UTType.text.identifier) || attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                group.enter()
                handleTextAttachment(attachment) { didSave in 
                    handledAny = handledAny || didSave
                    group.leave() 
                }
                continue
            }
            if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                group.enter()
                handleImageAttachment(attachment) { didSave in 
                    handledAny = handledAny || didSave
                    group.leave() 
                }
                continue
            }
        }

        group.notify(queue: .main) { [weak self] in
            // Add a small delay to ensure Core Data operations complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.completeRequest()
            }
        }
    }
    
    private func handleImageAttachment(_ attachment: NSItemProvider, completion: @escaping (Bool) -> Void) {
        attachment.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] (item, error) in
            DispatchQueue.main.async {
                if let data = item as? Data {
                    self?.saveStashItem(type: "screenshot", content: data, completion: completion)
                } else if let image = item as? UIImage, let data = image.jpegData(compressionQuality: 0.85) {
                    self?.saveStashItem(type: "screenshot", content: data, completion: completion)
                } else if let url = item as? URL, let data = try? Data(contentsOf: url) {
                    self?.saveStashItem(type: "screenshot", content: data, completion: completion)
                } else {
                    completion(false)
                }
            }
        }
    }
    
    private func handleURLAttachment(_ attachment: NSItemProvider, completion: @escaping (Bool) -> Void) {
        attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (item, error) in
            DispatchQueue.main.async {
                if let url = item as? URL {
                    self?.saveStashItem(type: "link", url: url.absoluteString, completion: completion)
                } else if let nsurl = item as? NSURL {
                    self?.saveStashItem(type: "link", url: (nsurl as URL).absoluteString, completion: completion)
                } else if let str = item as? String, let url = URL(string: str) {
                    self?.saveStashItem(type: "link", url: url.absoluteString, completion: completion)
                } else {
                    completion(false)
                }
            }
        }
    }
    
    private func handleTextAttachment(_ attachment: NSItemProvider, completion: @escaping (Bool) -> Void) {
        let type = attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) ? UTType.plainText.identifier : UTType.text.identifier
        attachment.loadItem(forTypeIdentifier: type, options: nil) { [weak self] (item, error) in
            DispatchQueue.main.async {
                if let str = item as? String {
                    self?.saveStashItem(type: "text", content: str.data(using: .utf8), completion: completion)
                } else if let attr = item as? NSAttributedString {
                    self?.saveStashItem(type: "text", content: attr.string.data(using: .utf8), completion: completion)
                } else {
                    completion(false)
                }
            }
        }
    }
    
    private func saveStashItem(type: String, content: Data? = nil, url: String? = nil, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let modelURL = Bundle.main.url(forResource: "StashDataModel", withExtension: "momd") else {
                print("Error: Could not find StashDataModel.momd in bundle")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            guard let model = NSManagedObjectModel(contentsOf: modelURL) else {
                print("Error: Could not load Core Data model")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            let container = NSPersistentContainer(name: "StashDataModel", managedObjectModel: model)

            // Use the shared App Group store if available so items appear in the main app
            if let appGroupID = self?.appGroupID,
               let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
                let storeURL = containerURL.appendingPathComponent("Stash.sqlite")
                let description = NSPersistentStoreDescription(url: storeURL)
                container.persistentStoreDescriptions = [description]
            }

            var storeLoadSuccess = false
            let semaphore = DispatchSemaphore(value: 0)
            
            container.loadPersistentStores { _, error in
                if let error = error {
                    print("Core Data failed to load: \(error.localizedDescription)")
                } else {
                    storeLoadSuccess = true
                }
                semaphore.signal()
            }
            
            semaphore.wait()
            
            guard storeLoadSuccess else {
                print("Error: Core Data store failed to load")
                DispatchQueue.main.async { completion(false) }
                return
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
                print("Successfully saved item to Stash")
                DispatchQueue.main.async { completion(true) }
            } catch {
                print("Failed to save item: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(false) }
            }
        }
    }
    
    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
