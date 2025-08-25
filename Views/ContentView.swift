import SwiftUI
import CoreData
import UIKit
import Photos
import PhotosUI
import AVFoundation
import AudioToolbox

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var dataController: DataController
    @EnvironmentObject var notificationDelegate: NotificationDelegate
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \StashItem.createdAt, ascending: false)],
        animation: .default)
    private var items: FetchedResults<StashItem>
    
    @State private var selectedBucketForEditing: Bucket?
    @State private var showingItemsList = false
    @State private var showAddModal = false
    @State private var showingInboxView = false
    @State private var selectedItemForCategorization: StashItem?
    @State private var selectedBucketForViewing: Bucket?
    @State private var selectedRecentGroup: RecentGroup?
    @State private var showingQuickText = false
    @State private var quickTextDraft = ""
    @State private var showingSettings = false
    @State private var showingOnboarding = false

    // Dashboard summary moved near buckets
    private var todaySummary: String {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: Date())
        let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay)!
        let todays = items.filter { i in
            guard let d = i.createdAt else { return false }
            return d >= startOfDay && d < endOfDay
        }
        return ItemInsights.dashboardSummary(from: Array(todays))
    }
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                // Background
                DesignSystem.cardBackground(colorScheme)
                    .ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Dashboard Header
                        DashboardHeaderView(onReviewNow: startQuickReview)
                        // Recently Added carousel (collapsed by type)
                        RecentlyAddedSection(onOpenGroup: openRecentGroup)
                        
                        if items.isEmpty {
                            // Empty state
                            VStack(spacing: 20) {
                                Image(systemName: "folder.badge.plus")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                
                                Text("Welcome to Stash")
                                    .font(.title)
                                    .fontWeight(.semibold)
                                
                                Text("Capture everything. Deal with it later. Actually deal with it.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                        } else {
                            // Bucket Grid
                            VStack(alignment: .leading, spacing: UI.gapM) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Stacks")
                                            .font(.title2)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            openAllBuckets()
                                        }) {
                                            HStack(spacing: 4) {
                                                Text("View All")
                                                    .font(.subheadline)
                                                Image(systemName: "chevron.right")
                                                    .font(.caption)
                                            }
                                            .foregroundColor(.blue)
                                        }
                                    }
                                    if !todaySummary.isEmpty {
                                        Text(todaySummary)
                                            .font(.footnote)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.horizontal, UI.inset)
                                .padding(.top, UI.gapM)

                                UpdatedBucketGridView(
                                    selectedBucketForEditing: $selectedBucketForEditing,
                                    showingInboxView: $showingInboxView,
                                    selectedBucketForViewing: $selectedBucketForViewing
                                )
                            }
                        }
                    }
                }

                // Floating Actions: Clear Now + Add
                HStack(spacing: 12) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showingInboxView = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Sort Now")
                                .font(.headline)
                        }
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                        .padding(.horizontal, 16)
                        .frame(height: 56)
                        .background(colorScheme == .dark ? .white : .black)
                        .clipShape(Capsule())
                        .adaptiveStrongShadow(colorScheme)
                        .overlay(
                            Capsule()
                                .stroke(colorScheme == .dark ? Color.white.opacity(0.15) : Color.clear, lineWidth: 1)
                        )
                    }
                    .accessibilityLabel("Sort Inbox Now")

                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showAddModal = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? .black : .white)
                            .frame(width: 56, height: 56)
                            .background(colorScheme == .dark ? .white : DesignSystem.accent(colorScheme))
                            .clipShape(Circle())
                            .adaptiveStrongShadow(colorScheme)
                            .overlay(
                                Circle()
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.15) : Color.clear, lineWidth: 1)
                            )
                    }
                    .accessibilityLabel("Add Item")
                    // Long-press for instant text capture (keyboard up)
                    .simultaneousGesture(LongPressGesture(minimumDuration: 0.35).onEnded { _ in
                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                        quickTextDraft = ""
                        showingQuickText = true
                    })
                }
                .padding(.trailing, UI.inset)
                .padding(.bottom, 24)
            }
            .navigationTitle("Stash")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showingInboxView = true
                    }) {
                        Image(systemName: "tray.full.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                    }
                    .accessibilityLabel("Open Inbox")
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape")
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                    }
                }
            }
        }
        .background(DesignSystem.pageBackground(colorScheme))
        .sheet(item: $selectedBucketForEditing) { bucket in
            BucketEditModal(bucket: bucket)
        }
        .sheet(isPresented: $showingItemsList) {
            ItemsListView()
        }
        .sheet(isPresented: $showAddModal) {
            AddItemModalView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(
                onRequestOnboarding: {
                    showingSettings = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        showingOnboarding = true
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingView { showingOnboarding = false }
        }
        .sheet(isPresented: $showingInboxView) {
            InboxItemsView(selectedItemForCategorization: $selectedItemForCategorization)
        }
        // Quick text capture (goes to Inbox for later organization)
        .sheet(isPresented: $showingQuickText) {
            TextInputSheet(text: $quickTextDraft) {
                let trimmed = quickTextDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                let newItem = StashItem(context: viewContext)
                newItem.id = UUID()
                newItem.type = ItemType.text.rawValue
                newItem.bucket = BucketType.inbox.rawValue
                newItem.createdAt = Date()
                newItem.updatedAt = Date()
                newItem.isProcessed = false
                newItem.userCorrectedBucket = false
                newItem.confidence = 0.0
                newItem.ocrText = trimmed
                dataController.save()
            }
        }
        .sheet(item: $selectedItemForCategorization) { item in
            ItemCategorizationModal(item: item)
        }
        .sheet(item: $selectedBucketForViewing) { bucket in
            BucketItemsView(bucket: bucket, selectedItemForCategorization: $selectedItemForCategorization)
        }
        // View all items in a recent group
        .sheet(item: $selectedRecentGroup) { group in
            GroupItemsSheet(group: group)
        }
        .onAppear {
            dataController.createDefaultBuckets()
            setupScreenshotDetection()
        }
        .onDisappear {
            removeScreenshotDetection()
        }
        .onChange(of: notificationDelegate.openInboxRequested) { open in
            if open {
                showingInboxView = true
                // reset flag after opening
                notificationDelegate.openInboxRequested = false
            }
        }
    }
    
    // MARK: - Home hooks
    private func startQuickReview() { showingInboxView = true }
    private func openRecentGroup(_ group: RecentGroup) { selectedRecentGroup = group }
    private func openBucket(_ b: Bucket) {
        if b.systemName == "inbox" { showingInboxView = true } else { selectedBucketForViewing = b }
    }
    private func openAllBuckets() { showingItemsList = true }
    
    private func addSampleItem() {
        withAnimation {
            let newItem = StashItem(context: viewContext)
            newItem.id = UUID()
            newItem.type = "sample"
            newItem.bucket = "inbox"
            newItem.createdAt = Date()
            newItem.updatedAt = Date()
            newItem.isProcessed = false
            newItem.userCorrectedBucket = false
            newItem.confidence = 0.0
            
            dataController.save()
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { items[$0] }.forEach(viewContext.delete)
            dataController.save()
        }
    }
    
    // MARK: - Screenshot Detection
    private func setupScreenshotDetection() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.userDidTakeScreenshotNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.handleScreenshotTaken()
        }
    }
    
    private func removeScreenshotDetection() {
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.userDidTakeScreenshotNotification,
            object: nil
        )
    }
    
    private func handleScreenshotTaken() {
        withAnimation {
            let newItem = StashItem(context: viewContext)
            newItem.id = UUID()
            newItem.type = "screenshot"
            newItem.bucket = "inbox"
            newItem.createdAt = Date()
            newItem.updatedAt = Date()
            newItem.isProcessed = false
            newItem.userCorrectedBucket = false
            newItem.confidence = 0.0
            newItem.ocrText = "Screenshot taken at \(Date().formatted(date: .abbreviated, time: .shortened))"
            
            dataController.save()
            
            // Optional: Show a brief confirmation
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()

            // Attempt to attach the latest screenshot image after a brief delay
            attachLatestScreenshotImage(to: newItem)
        }
    }

    // Fetch the most recent screenshot from the Photos library and attach it to the item
    private func attachLatestScreenshotImage(to item: StashItem) {
        func fetchAndAttach() {
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            options.fetchLimit = 1
            options.predicate = NSPredicate(format: "mediaType == %d AND (mediaSubtype & %d) != 0",
                                            PHAssetMediaType.image.rawValue,
                                            PHAssetMediaSubtype.photoScreenshot.rawValue)
            let assets = PHAsset.fetchAssets(with: options)
            guard let asset = assets.firstObject else { return }

            let reqOptions = PHImageRequestOptions()
            reqOptions.deliveryMode = .highQualityFormat
            reqOptions.isNetworkAccessAllowed = true
            reqOptions.resizeMode = .fast

            PHImageManager.default().requestImage(for: asset,
                                                  targetSize: CGSize(width: 1024, height: 1024),
                                                  contentMode: .aspectFit,
                                                  options: reqOptions) { image, _ in
                guard let image, let data = image.jpegData(compressionQuality: 0.85) else { return }
                item.content = data
                item.updatedAt = Date()
                dataController.save()
            }
        }

        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            // Delay slightly to allow the system to write the screenshot to Photos
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                fetchAndAttach()
            }
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                if newStatus == .authorized || newStatus == .limited {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        fetchAndAttach()
                    }
                }
            }
        default:
            break
        }
    }

}

struct StashItemRow: View {
    let item: StashItem
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.type?.capitalized ?? "Unknown")
                    .font(.headline)
                
                Text(item.bucket?.capitalized ?? "Inbox")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(bucketColor.opacity(0.2))
                    .foregroundColor(bucketColor)
                    .clipShape(Capsule())
                
                if let createdAt = item.createdAt {
                    Text(createdAt, format: .dateTime.day().month().hour().minute())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if !item.isProcessed {
                Circle()
                    .fill(.blue)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var bucketColor: Color {
        switch item.bucket {
        case "work":
            return .blue
        case "shopping":
            return .green
        case "ideas":
            return .orange
        case "personal":
            return .purple
        default:
            return .gray
        }
    }
}


// MARK: - Add Item Modal
struct AddItemModalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var dataController: DataController
    
    // Stack-first capture
    @State private var selectedBucket: BucketType? = nil
    @State private var showingTextInput = false
    @State private var textDraft: String = ""
    @State private var showingVoiceRecorder = false
    @State private var photoPickerItem: PhotosPickerItem? = nil
    @State private var isLoadingImage = false
    
    // Draft state - content not saved until user hits "Stash"
    @State private var draftImageData: Data? = nil
    @State private var draftAudioData: Data? = nil
    @State private var draftAudioDuration: TimeInterval = 0
    @State private var showingSuccessNotification = false
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // 1) Select Stack (Inbox hidden)
                    AddBucketSelectionView(selectedBucket: $selectedBucket)

                    // 2) Capture options (auto-detect type)
                    CaptureOptionsView(selectedBucket: $selectedBucket,
                                       showingTextInput: $showingTextInput,
                                       textDraft: $textDraft,
                                       showingVoiceRecorder: $showingVoiceRecorder,
                                       photoPickerItem: $photoPickerItem,
                                       isLoadingImage: $isLoadingImage,
                                       draftImageData: $draftImageData,
                                       draftAudioData: $draftAudioData,
                                       draftAudioDuration: $draftAudioDuration)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.accent(colorScheme))
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    Button(action: stashItem) {
                        HStack {
                            Spacer()
                            Text("Stash")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .frame(height: 56)
                        .background(DesignSystem.accent(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(!canStash)
                    .opacity(canStash ? 1.0 : 0.5)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    .background(.regularMaterial)
                }
            }
        }
        .overlay(
            // Success notification pill
            VStack {
                if showingSuccessNotification {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                        
                        Text("Item Stashed!")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
                    .transition(.scale.combined(with: .opacity))
                }
                Spacer()
            }
            .padding(.top, 60)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showingSuccessNotification)
        )
        // Text input sheet
        .sheet(isPresented: $showingTextInput) {
            TextInputSheet(text: $textDraft) {
                // Just close the sheet - content will be saved when user hits "Stash"
            }
        }
        // Voice recorder sheet
        .sheet(isPresented: $showingVoiceRecorder) {
            VoiceRecorderSheet { audioURL, duration in
                // Store in draft state - will be saved when user hits "Stash"
                if let data = try? Data(contentsOf: audioURL) {
                    draftAudioData = data
                    draftAudioDuration = duration
                }
            }
        }
    }
    
    private var canStash: Bool {
        guard selectedBucket != nil else { return false }
        
        // Check if we have any content to save
        let hasText = !textDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasImage = draftImageData != nil
        let hasAudio = draftAudioData != nil
        
        return hasText || hasImage || hasAudio
    }
    
    private func stashItem() {
        guard let bucket = selectedBucket else { return }
        
        withAnimation {
            // Determine the primary content type and create item
            if let imageData = draftImageData {
                let newItem = StashItem(context: viewContext)
                newItem.id = UUID()
                newItem.type = ItemType.photo.rawValue
                newItem.bucket = bucket.rawValue
                newItem.createdAt = Date()
                newItem.updatedAt = Date()
                newItem.isProcessed = bucket != .inbox
                newItem.userCorrectedBucket = bucket != .inbox
                newItem.confidence = 0.0
                newItem.content = imageData
                newItem.ocrText = textDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : textDraft
            } else if let audioData = draftAudioData {
                let newItem = StashItem(context: viewContext)
                newItem.id = UUID()
                newItem.type = ItemType.voice.rawValue
                newItem.bucket = bucket.rawValue
                newItem.createdAt = Date()
                newItem.updatedAt = Date()
                newItem.isProcessed = bucket != .inbox
                newItem.userCorrectedBucket = bucket != .inbox
                newItem.confidence = 0.0
                newItem.content = audioData
                newItem.ocrText = draftAudioDuration > 0 ? "Voice note (\(formatDuration(draftAudioDuration)))" : ""
            } else if !textDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let newItem = StashItem(context: viewContext)
                newItem.id = UUID()
                newItem.type = ItemType.text.rawValue
                newItem.bucket = bucket.rawValue
                newItem.createdAt = Date()
                newItem.updatedAt = Date()
                newItem.isProcessed = bucket != .inbox
                newItem.userCorrectedBucket = bucket != .inbox
                newItem.confidence = 0.0
                newItem.ocrText = textDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            dataController.save()
            
            // Show success notification
            showingSuccessNotification = true
            
            // Haptic feedback
            let impactFeedback = UINotificationFeedbackGenerator()
            impactFeedback.notificationOccurred(.success)
            
            // Auto-dismiss after showing success
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Add Flow Supporting Views
private struct CaptureOptionsView: View {
    @Binding var selectedBucket: BucketType?
    @Binding var showingTextInput: Bool
    @Binding var textDraft: String
    @Binding var showingVoiceRecorder: Bool
    @Binding var photoPickerItem: PhotosPickerItem?
    @Binding var isLoadingImage: Bool
    @Binding var draftImageData: Data?
    @Binding var draftAudioData: Data?
    @Binding var draftAudioDuration: TimeInterval

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var dataController: DataController

    @State private var showPasteOption = false
    @State private var pasteCandidate: PasteCandidate? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CAPTURE")
                .font(.subheadline)
                .fontWeight(.bold)
                .tracking(1.2)
                .foregroundColor(DesignSystem.primaryText(colorScheme))

            if showPasteOption, let candidate = pasteCandidate, let preview = candidate.previewText {
                Button {
                    // Store clipboard content in draft instead of immediately saving
                    switch candidate.kind {
                    case .text(let text):
                        textDraft = text
                    case .url(let url):
                        textDraft = url
                    case .image(let data):
                        draftImageData = data
                    }
                    showPasteOption = false
                    pasteCandidate = nil
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: candidate.icon)
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(DesignSystem.primaryText(colorScheme))
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Paste from Clipboard")
                                .font(.headline)
                                .foregroundColor(DesignSystem.primaryText(colorScheme))
                            Text(preview)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                    }
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background(RoundedRectangle(cornerRadius: 12).fill(DesignSystem.cardBackground(colorScheme)))
                }
                .disabled(selectedBucket == nil)
            }

            HStack(spacing: 12) {
                PhotosPicker(selection: $photoPickerItem, matching: .images, preferredItemEncoding: .automatic) {
                    captureCard(title: isLoadingImage ? "Loading…" : "Photo Library", systemImage: "photo.fill.on.rectangle.fill")
                }
                .disabled(selectedBucket == nil || isLoadingImage)

                Button {
                    showingVoiceRecorder = true
                } label: {
                    captureCard(title: "Record Voice", systemImage: "mic")
                }
                .disabled(selectedBucket == nil)
            }

            HStack(spacing: 12) {
                Button {
                    textDraft = ""
                    showingTextInput = true
                } label: {
                    captureCard(title: "Write Text", systemImage: "square.and.pencil")
                }
                .disabled(selectedBucket == nil)
                
                Button {
                    let candidate = PasteCandidate.detect()
                    if candidate.previewText != nil {
                        pasteCandidate = candidate
                        showPasteOption = true
                    }
                } label: {
                    captureCard(title: "Paste from Clipboard", systemImage: "doc.on.clipboard")
                }
                .disabled(selectedBucket == nil)
            }
        }
        // Handle selected photo
        .onChange(of: photoPickerItem) { newItem in
            guard let newItem else { return }
            isLoadingImage = true
            Task {
                defer { isLoadingImage = false }
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        // Store in draft state - will be saved when user hits "Stash"
                        draftImageData = data
                    }
                }
            }
        }
    }

    private func captureCard(title: String, systemImage: String) -> some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundColor(DesignSystem.accent(colorScheme))
            Text(title)
                .foregroundColor(DesignSystem.primaryText(colorScheme))
            Spacer()
        }
        .font(.headline)
        .padding()
        .frame(maxWidth: .infinity, minHeight: 60)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignSystem.cardBackground(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .adaptiveMediumShadow(colorScheme)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

private struct PasteCandidate {
    enum Kind { case image(Data), url(String), text(String) }
    let kind: Kind

    var icon: String {
        switch kind { case .image: return "doc.on.doc"; case .url: return "link"; case .text: return "text.alignleft" }
    }
    var previewText: String? {
        switch kind {
        case .image: return "Image from clipboard"
        case .url(let s): return s
        case .text(let t): return t
        }
    }

    func commit(into bucket: BucketType, viewContext: NSManagedObjectContext, dataController: DataController) {
        let item = StashItem(context: viewContext)
        item.id = UUID()
        item.bucket = bucket.rawValue
        item.createdAt = Date()
        item.updatedAt = Date()
        item.isProcessed = bucket != .inbox
        item.userCorrectedBucket = bucket != .inbox
        item.confidence = 0.0
        switch kind {
        case .image(let data):
            item.type = ItemType.photo.rawValue
            item.content = data
        case .url(let s):
            item.type = ItemType.link.rawValue
            item.url = s
        case .text(let t):
            item.type = ItemType.text.rawValue
            item.ocrText = t
        }
        dataController.save()
    }

    static func detect() -> PasteCandidate {
        let pb = UIPasteboard.general
        if let img = pb.image, let data = img.jpegData(compressionQuality: 0.85) { return PasteCandidate(kind: .image(data)) }
        if let url = pb.url { return PasteCandidate(kind: .url(url.absoluteString)) }
        if let s = pb.string, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return PasteCandidate(kind: .text(s)) }
        return PasteCandidate(kind: .text(""))
    }
}
struct TypeSelectionView: View {
    @Binding var selectedType: ItemType
    
    @Environment(\.colorScheme) private var colorScheme

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CONTENT TYPE")
                .font(.subheadline)
                .fontWeight(.bold)
                .tracking(1.2)
                .foregroundColor(DesignSystem.primaryText(colorScheme))

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(ItemType.allCases) { type in
                    TypeSelectionCard(
                        type: type,
                        isSelected: selectedType == type
                    ) {
                        selectedType = type
                    }
                }
            }
        }
    }
}

struct TypeSelectionCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let type: ItemType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: type.systemImage)
                    .font(.title)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : DesignSystem.primaryText(colorScheme))

                Text(type.displayName)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : DesignSystem.primaryText(colorScheme))

                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? DesignSystem.accent(colorScheme) : DesignSystem.cardBackground(colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? DesignSystem.accent(colorScheme) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.18), value: isSelected)
    }
}

// Optional type selector for Add flow (no default selection)
struct AddTypeSelectionView: View {
    @Binding var selectedType: ItemType?
    
    @Environment(\.colorScheme) private var colorScheme

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CONTENT TYPE")
                .font(.subheadline)
                .fontWeight(.bold)
                .tracking(1.2)
                .foregroundColor(DesignSystem.primaryText(colorScheme))

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(ItemType.allCases) { type in
                    TypeSelectionCard(
                        type: type,
                        isSelected: selectedType == type
                    ) {
                        selectedType = type
                    }
                }
            }
        }
    }
}

struct ContentInputView: View {
    let selectedType: ItemType?
    @Binding var content: String
    @Binding var selectedImageData: Data?
    @Binding var selectedAudioData: Data?
    
    @Environment(\.colorScheme) private var colorScheme

    @State private var showingTextInput = false
    @State private var showingURLInput = false
    @State private var showingVoiceRecorder = false
    // SwiftUI PhotosPicker state
    @State private var photoPickerItem: PhotosPickerItem? = nil
    @State private var isLoadingImage = false
    @State private var tempText = ""
    @State private var tempURL = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // If no type chosen yet, show a hint
            if selectedType == nil {
                Text("Choose a content type to get started")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Per-type, optimized actions
            switch selectedType ?? .text {
            case .text:
                Text("CONTENT")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .tracking(1.2)
                    .foregroundColor(DesignSystem.primaryText(colorScheme))
                    .padding(.top, 8)
                Button {
                    tempText = content
                    showingTextInput = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.pencil")
                        Text("Write text")
                        Spacer()
                    }
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background(RoundedRectangle(cornerRadius: 12).fill(DesignSystem.cardBackground(colorScheme)))
                }

            case .link:
                Text("CONTENT")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .tracking(1.2)
                    .foregroundColor(DesignSystem.primaryText(colorScheme))
                    .padding(.top, 8)
                Button {
                    tempURL = content
                    showingURLInput = true
                } label: {
                    HStack {
                        Image(systemName: "link")
                        Text("Enter URL")
                        Spacer()
                    }
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background(RoundedRectangle(cornerRadius: 12).fill(DesignSystem.cardBackground(colorScheme)))
                }

            case .photo:
                Text("CONTENT")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .tracking(1.2)
                    .foregroundColor(DesignSystem.primaryText(colorScheme))
                    .padding(.top, 8)
                PhotosPicker(selection: $photoPickerItem, matching: .images, preferredItemEncoding: .automatic) {
                    HStack {
                        Image(systemName: "photo.fill.on.rectangle.fill")
                            .font(.title3)
                            .fontWeight(.medium)
                        Text(isLoadingImage ? "Loading…" : (selectedImageData == nil ? "Choose from Library" : "Replace Photo"))
                        Spacer()
                    }
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background(RoundedRectangle(cornerRadius: 12).fill(DesignSystem.cardBackground(colorScheme)))
                }
                .disabled(isLoadingImage)
                if let data = selectedImageData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

            case .voice:
                // Open recorder sheet
                Button {
                    showingVoiceRecorder = true
                } label: {
                    HStack {
                        Image(systemName: "mic")
                            .font(.title3)
                            .fontWeight(.medium)
                        Text("Record Voice Note")
                        Spacer()
                    }
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background(RoundedRectangle(cornerRadius: 12).fill(DesignSystem.cardBackground(colorScheme)))
                }
            }

            // Content preview where it makes sense
            if !content.isEmpty, selectedType == .text || selectedType == .link || selectedType == .voice {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preview")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    Text(content)
                        .font(.body)
                        .padding(12)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                }
            }
        }
        .sheet(isPresented: $showingTextInput) {
            TextInputSheet(text: $tempText) {
                content = tempText
            }
        }
        .sheet(isPresented: $showingURLInput) {
            URLInputSheet(url: $tempURL) {
                content = tempURL
            }
        }
        .sheet(isPresented: $showingVoiceRecorder) {
            VoiceRecorderSheet { audioURL, duration in
                if let data = try? Data(contentsOf: audioURL) {
                    selectedAudioData = data
                }
                content = duration > 0 ? "Voice note (\(formatDuration(duration)))" : ""
            }
        }
        // Auto-open the best input for the selected type
        .onChange(of: selectedType) { newType in
            guard let newType else { return }
            switch newType {
            case .photo:
                // For PhotosPicker, user taps the button; no programmatic open
                break
            case .link:
                if let s = UIPasteboard.general.string, let url = URL(string: s), url.scheme != nil {
                    tempURL = s
                } else {
                    tempURL = content
                }
                showingURLInput = true
            case .text:
                tempText = content
                showingTextInput = true
            case .voice:
                showingVoiceRecorder = true
            }
        }
        // Load selected image data from PhotosPicker
        .onChange(of: photoPickerItem) { newItem in
            guard let newItem else { return }
            isLoadingImage = true
            Task {
                defer { isLoadingImage = false }
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        selectedImageData = data
                        if content.isEmpty { content = "" }
                    }
                }
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

struct BucketSelectionView: View {
    @Binding var selectedBucket: BucketType
    
    @Environment(\.colorScheme) private var colorScheme

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("STACK")
                .font(.subheadline)
                .fontWeight(.bold)
                .tracking(1.2)
                .foregroundColor(DesignSystem.primaryText(colorScheme))
                .padding(.top, 8)

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(BucketType.allCases.filter { $0 != .inbox }) { bucket in
                    BucketCard(bucket: bucket, isSelected: selectedBucket == bucket) {
                        selectedBucket = bucket
                    }
                }
            }
        }
    }
}

struct BucketCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let bucket: BucketType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            action()
        }) {
            HStack(spacing: 12) {
                Text(bucket.emoji)
                    .font(.title2)

                Text(bucket.displayName)
                    .font(.headline)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundColor(isSelected ? .white : DesignSystem.primaryText(colorScheme))

                Spacer()
                // Always reserve space for the checkmark to avoid truncation on select
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .opacity(isSelected ? 1 : 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? bucket.color : DesignSystem.cardBackground(colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? bucket.color : Color.clear, lineWidth: 2)
            )
            // Remove scale effect to prevent layout jump that truncates labels
            .adaptiveColoredShadow(bucket.color, colorScheme, isActive: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.18), value: isSelected)
    }
}

// Optional bucket picker for Add flow (no default selection)
private struct AddBucketSelectionView: View {
    @Binding var selectedBucket: BucketType?
    
    @Environment(\.colorScheme) private var colorScheme
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("STACK")
                .font(.subheadline)
                .fontWeight(.bold)
                .tracking(1.2)
                .foregroundColor(DesignSystem.primaryText(colorScheme))
                .padding(.top, 8)

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(BucketType.allCases.filter { $0 != .inbox }) { bucket in
                    BucketCard(bucket: bucket, isSelected: selectedBucket == bucket) {
                        selectedBucket = bucket
                    }
                }
            }
        }
    }
}

// MARK: - Inbox Views
struct InboxItemsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedItemForCategorization: StashItem?
    @State private var selectedItemForViewing: StashItem?
    @State private var showAddModal = false
    @State private var showSettings = false
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \StashItem.createdAt, ascending: false)],
        predicate: NSPredicate(format: "bucket == %@ AND isProcessed == NO", "inbox"),
        animation: .default
    ) private var inboxItems: FetchedResults<StashItem>
    
    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 20)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                if inboxItems.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)

                        Text("No items to sort")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Screenshots you take will appear here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button {
                            showAddModal = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add from Library")
                            }
                            .font(.headline)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        Button {
                            showSettings = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "questionmark.circle")
                                Text("Learn how to capture")
                            }
                        }
                        .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 100)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(inboxItems, id: \.id) { item in
                            InboxItemCard(item: item) {
                                selectedItemForViewing = item
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Inbox")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $selectedItemForViewing) { item in
            ItemDetailView(item: item)
        }
        .sheet(isPresented: $showAddModal) {
            AddItemModalView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(onRequestOnboarding: {})
        }
    }
}

struct InboxItemCard: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var dataController: DataController
    let item: StashItem
    let onTap: () -> Void
    @State private var showingDeleteAlert = false
    @State private var showImageViewer = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Type icon and timestamp
                HStack {
                    Image(systemName: itemTypeIcon)
                        .font(.title3)
                        .foregroundColor(itemTypeColor)
                    
                    Spacer()
                    
                    if let createdAt = item.createdAt {
                        Text(createdAt, format: .dateTime.hour().minute())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Image preview (if available)
                if let imageView = imagePreview {
                    imageView
                        .frame(height: 100)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Content preview (smart)
                Text(ItemInsights.smartDescription(for: item))
                    .font(.subheadline)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.primary)

                // Tiny tags
                if !ItemInsights.tags(for: item).isEmpty {
                    HStack(spacing: 6) {
                        ForEach(ItemInsights.tags(for: item), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(DesignSystem.cardBackground(colorScheme))
                                .clipShape(Capsule())
                        }
                    }
                }

                // Soft source caption
                if let caption = ItemInsights.softCaption(for: item) {
                    Text(caption)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Optional hint
                if let hint = ItemInsights.hint(for: item) {
                    Text(hint)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Type label
                Text(item.type?.capitalized ?? "Unknown")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(itemTypeColor.opacity(0.1))
                    .foregroundColor(itemTypeColor)
                    .clipShape(Capsule())
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(DesignSystem.cardBackground(colorScheme))
                    .adaptiveLightShadow(colorScheme)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(opacityForAge)
        .contextMenu {
            // Move To submenu
            Menu("Move To") {
                ForEach(BucketType.allCases, id: \.self) { bucket in
                    Button(bucket.displayName) {
                        moveItem(to: bucket)
                    }
                }
            }

            // Mark processed toggle
            Button(item.isProcessed ? "Mark Unreviewed" : "Mark Reviewed") {
                toggleProcessed()
            }

            // Copy content
            if let url = item.url, !url.isEmpty {
                Button("Copy URL") { UIPasteboard.general.string = url }
            } else if let text = item.ocrText, !text.isEmpty {
                Button("Copy Text") { UIPasteboard.general.string = text }
            }

            // Image-specific
            if hasImage {
                Button("View Fullscreen") { showImageViewer = true }
                Button("Save to Photos") { saveImageToPhotos() }
            }

            // Destructive
            Button(role: .destructive) { showingDeleteAlert = true } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .alert("Delete Item", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteItem()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this item? This action cannot be undone.")
        }
        .fullScreenCover(isPresented: $showImageViewer) {
            if let uiImage = largeUIImage {
                FullscreenImageViewer(uiImage: uiImage)
            }
        }
    }
    
    private var itemTypeIcon: String {
        switch item.type {
        case "screenshot": return "camera.viewfinder"
        case "link": return "link"
        case "voice": return "waveform"
        case "text": return "text.alignleft"
        case "photo": return "photo"
        default: return "doc"
        }
    }
    
    private var itemTypeColor: Color {
        switch item.type {
        case "screenshot": return .blue
        case "link": return DesignSystem.accent(colorScheme)
        case "voice": return .orange
        case "text": return .green
        case "photo": return .red
        default: return .gray
        }
    }
    
    private var opacityForAge: Double {
        guard let created = item.createdAt else { return 1.0 }
        let hours = Date().timeIntervalSince(created) / 3600.0
        if hours > 72 { return 0.6 }
        if hours > 24 { return 0.8 }
        return 1.0
    }

    // Thumbnail generator
    private var imagePreview: AnyView? {
        guard (item.type == "screenshot" || item.type == "photo"),
              let data = item.content,
              let uiImage = UIImage(data: data) else { return nil }
        return AnyView(
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        )
    }

    private var hasImage: Bool {
        (item.type == "screenshot" || item.type == "photo") && item.content != nil
    }

    private var largeUIImage: UIImage? {
        guard hasImage, let data = item.content else { return nil }
        return UIImage(data: data)
    }

    private func moveItem(to bucket: BucketType) {
        guard bucket.rawValue != item.bucket else { return }
        withAnimation {
            item.bucket = bucket.rawValue
            item.isProcessed = bucket != .inbox
            item.updatedAt = Date()
            dataController.save()
        }
    }

    private func toggleProcessed() {
        withAnimation {
            item.isProcessed.toggle()
            item.updatedAt = Date()
            dataController.save()
        }
    }

    private func saveImageToPhotos() {
        guard let uiImage = largeUIImage else { return }
        UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
    }

    private func deleteItem() {
        withAnimation {
            viewContext.delete(item)
            dataController.save()
        }
    }
}

struct ItemCategorizationModal: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var dataController: DataController
    
    let item: StashItem
    @State private var selectedBucket: BucketType = .inbox
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // Item preview
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Item Preview")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 12) {
                            if let imageView = imagePreview {
                                imageView
                                    .frame(width: 48, height: 48)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                Image(systemName: itemTypeIcon)
                                    .font(.title2)
                                    .foregroundColor(itemTypeColor)
                                    .frame(width: 40, height: 40)
                                    .background(itemTypeColor.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.type?.capitalized ?? "Unknown")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(contentPreview)
                                    .font(.subheadline)
                                    .lineLimit(2)
                                    .foregroundColor(.secondary)
                                
                                if let createdAt = item.createdAt {
                                    Text(createdAt, format: .dateTime.day().month().hour().minute())
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(16)
                        .background(DesignSystem.cardBackground(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Bucket selection
                    BucketSelectionView(selectedBucket: $selectedBucket)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle("Categorize Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.accent(colorScheme))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Move") {
                        moveItem()
                    }
                    .foregroundColor(selectedBucket != BucketType(rawValue: item.bucket ?? "") ? .blue : .gray)
                    .disabled(selectedBucket == BucketType(rawValue: item.bucket ?? ""))
                }
            }
        }
        .onAppear {
            selectedBucket = BucketType(rawValue: item.bucket ?? "inbox") ?? .inbox
        }
    }
    
    private var itemTypeIcon: String {
        switch item.type {
        case "screenshot": return "camera.viewfinder"
        case "link": return "link"
        case "voice": return "waveform"
        case "text": return "text.alignleft"
        case "photo": return "photo"
        default: return "doc"
        }
    }
    
    private var itemTypeColor: Color {
        switch item.type {
        case "screenshot": return .blue
        case "link": return DesignSystem.accent(colorScheme)
        case "voice": return .orange
        case "text": return .green
        case "photo": return .red
        default: return .gray
        }
    }
    
    private var contentPreview: String {
        if let ocrText = item.ocrText, !ocrText.isEmpty {
            return ocrText
        } else if let url = item.url, !url.isEmpty {
            return url
        } else {
            switch item.type {
            case "screenshot": return "Screenshot captured"
            case "photo": return "Photo captured" 
            case "voice": return "Voice recording"
            case "link": return "Link captured"
            case "text": return "Text content"
            default: return "Content captured"
            }
        }
    }
    
    private var imagePreview: AnyView? {
        guard (item.type == "screenshot" || item.type == "photo"),
              let data = item.content,
              let uiImage = UIImage(data: data) else { return nil }
        return AnyView(
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        )
    }
    
    private func moveItem() {
        withAnimation {
            item.bucket = selectedBucket.rawValue
            item.isProcessed = selectedBucket != .inbox
            item.updatedAt = Date()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            dataController.save()
            dismiss()
        }
    }
}

// MARK: - Stack Items View
struct BucketItemsView: View {
    @Environment(\.dismiss) private var dismiss
    let bucket: Bucket
    @Binding var selectedItemForCategorization: StashItem?
    @State private var selectedItemForViewing: StashItem?
    @State private var showingQuickAdd = false
    @State private var didJustEmpty = false
    
    @FetchRequest private var bucketItems: FetchedResults<StashItem>
    
    init(bucket: Bucket, selectedItemForCategorization: Binding<StashItem?>) {
        self.bucket = bucket
        self._selectedItemForCategorization = selectedItemForCategorization
        
        self._bucketItems = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \StashItem.createdAt, ascending: false)],
            predicate: NSPredicate(format: "bucket == %@", bucket.systemName ?? ""),
            animation: .default
        )
    }
    
    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 20)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                if bucketItems.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: bucket.icon ?? "folder")
                            .font(.system(size: 60))
                            .foregroundColor(bucketColor)

                        Text(emptyTitle)
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text(emptySubtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button(action: { showingQuickAdd = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(bucketColor)
                                Text("Add to \(bucketDisplayName)")
                                    .font(.headline)
                                    .foregroundColor(bucketColor)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(bucketColor.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    .scaleEffect(didJustEmpty ? 1.03 : 1.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: didJustEmpty)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 100)
                } else {
                    VStack(spacing: 16) {
                        // Add + button for skip functionality
                        HStack {
                            Button(action: {
                                showingQuickAdd = true
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(bucketColor)
                                    Text("Add Item to \(bucketDisplayName)")
                                        .font(.headline)
                                        .foregroundColor(bucketColor)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(bucketColor.opacity(0.1))
                                .cornerRadius(12)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(bucketItems, id: \.id) { item in
                                BucketItemCard(item: item) {
                                    selectedItemForViewing = item
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            .navigationTitle(bucketDisplayName)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $selectedItemForViewing) { item in
            ItemDetailView(item: item)
        }
        .sheet(isPresented: $showingQuickAdd) {
            if let bucketType = BucketType(rawValue: bucket.systemName ?? "") {
                QuickAddModalView(targetBucket: bucketType)
            }
        }
        .onChange(of: bucketItems.count) { newValue in
            if newValue == 0 {
                playSwoosh()
                didJustEmpty = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { didJustEmpty = false }
            }
        }
    }
    
    private var bucketDisplayName: String {
        bucket.customName ?? bucket.systemName?.capitalized ?? "Unknown"
    }

    private var emptyTitle: String {
        switch bucket.systemName ?? "" {
        case "work": return "No work items yet"
        case "shopping": return "No saved products"
        case "ideas": return "No inspiration saved"
        case "personal": return "No personal items"
        case "inbox": return "No items to sort"
        default: return "Nothing here yet"
        }
    }

    private var emptySubtitle: String {
        switch bucket.systemName ?? "" {
        case "work": return "Try taking a screenshot of an email or Slack message"
        case "shopping": return "Screenshot items you want to buy"
        case "ideas": return "Capture articles, designs, or quotes"
        case "personal": return "Save memes, posts, or memories"
        case "inbox": return "Screenshots you take will appear here"
        default: return "Add something to get started"
        }
    }
    
    private var bucketColor: Color {
        switch bucket.colorName {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "red": return .red
        case "yellow": return .yellow
        case "teal": return .teal
        default: return .gray
        }
    }
}

private func playSwoosh() {
    // Use a system sound as a lightweight swoosh-like cue
    let soundID: SystemSoundID = 1108 // subtle system sound
    AudioServicesPlaySystemSound(soundID)
}

struct BucketItemCard: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var dataController: DataController
    let item: StashItem
    let onTap: () -> Void
    @State private var showingDeleteAlert = false
    @State private var showImageViewer = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Type icon and timestamp
                HStack {
                    Image(systemName: itemTypeIcon)
                        .font(.title3)
                        .foregroundColor(itemTypeColor)
                    
                    Spacer()
                    
                    if let createdAt = item.createdAt {
                        Text(createdAt, format: .dateTime.hour().minute())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Image preview (if available)
                if let imageView = imagePreview {
                    imageView
                        .frame(height: 100)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Content preview (smart)
                Text(ItemInsights.smartDescription(for: item))
                    .font(.subheadline)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.primary)

                // Status and type
                if !ItemInsights.tags(for: item).isEmpty {
                    HStack(spacing: 6) {
                        ForEach(ItemInsights.tags(for: item), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(DesignSystem.cardBackground(colorScheme))
                                .clipShape(Capsule())
                        }
                    }
                }
                if let caption = ItemInsights.softCaption(for: item) {
                    Text(caption)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text(item.type?.capitalized ?? "Unknown")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(itemTypeColor.opacity(0.1))
                        .foregroundColor(itemTypeColor)
                        .clipShape(Capsule())
                    
                    Spacer()
                    
                    if item.isProcessed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(DesignSystem.cardBackground(colorScheme))
                    .adaptiveLightShadow(colorScheme)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Menu("Move To") {
                ForEach(BucketType.allCases, id: \.self) { bucket in
                    Button(bucket.displayName) { moveItem(to: bucket) }
                }
            }

            Button(item.isProcessed ? "Mark Unreviewed" : "Mark Reviewed") { toggleProcessed() }

            if let url = item.url, !url.isEmpty {
                Button("Copy URL") { UIPasteboard.general.string = url }
            } else if let text = item.ocrText, !text.isEmpty {
                Button("Copy Text") { UIPasteboard.general.string = text }
            }

            if hasImage {
                Button("View Fullscreen") { showImageViewer = true }
                Button("Save to Photos") { saveImageToPhotos() }
            }

            Button(role: .destructive) { showingDeleteAlert = true } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .alert("Delete Item", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) { deleteItem() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this item? This action cannot be undone.")
        }
        .fullScreenCover(isPresented: $showImageViewer) {
            if let uiImage = largeUIImage {
                FullscreenImageViewer(uiImage: uiImage)
            }
        }
    }
    
    private var itemTypeIcon: String {
        switch item.type {
        case "screenshot": return "camera.viewfinder"
        case "link": return "link"
        case "voice": return "waveform"
        case "text": return "text.alignleft"
        case "photo": return "photo"
        default: return "doc"
        }
    }
    
    private var itemTypeColor: Color {
        switch item.type {
        case "screenshot": return .blue
        case "link": return DesignSystem.accent(colorScheme)
        case "voice": return .orange
        case "text": return .green
        case "photo": return .red
        default: return .gray
        }
    }
    
    private var contentPreview: String {
        if let ocrText = item.ocrText, !ocrText.isEmpty {
            return ocrText
        } else if let url = item.url, !url.isEmpty {
            return url
        } else {
            switch item.type {
            case "screenshot": return "Screenshot captured"
            case "photo": return "Photo captured" 
            case "voice": return "Voice recording"
            case "link": return "Link captured"
            case "text": return "Text content"
            default: return "Content captured"
            }
        }
    }

    // Thumbnail generator
    private var imagePreview: AnyView? {
        guard (item.type == "screenshot" || item.type == "photo"),
              let data = item.content,
              let uiImage = UIImage(data: data) else { return nil }
        return AnyView(
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        )
    }

    private var hasImage: Bool {
        (item.type == "screenshot" || item.type == "photo") && item.content != nil
    }

    private var largeUIImage: UIImage? {
        guard hasImage, let data = item.content else { return nil }
        return UIImage(data: data)
    }

    private func moveItem(to bucket: BucketType) {
        guard bucket.rawValue != item.bucket else { return }
        withAnimation {
            item.bucket = bucket.rawValue
            item.isProcessed = bucket != .inbox
            item.updatedAt = Date()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            dataController.save()
        }
    }

    private func toggleProcessed() {
        withAnimation {
            item.isProcessed.toggle()
            item.updatedAt = Date()
            dataController.save()
        }
    }

    private func saveImageToPhotos() {
        guard let uiImage = largeUIImage else { return }
        UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
    }

    private func deleteItem() {
        withAnimation {
            viewContext.delete(item)
            dataController.save()
        }
    }
}

// MARK: - Updated BucketGridView
struct UpdatedBucketGridView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Bucket.createdAt, ascending: true)],
        animation: .default
    ) private var buckets: FetchedResults<Bucket>
    
    @Binding var selectedBucketForEditing: Bucket?
    @Binding var showingInboxView: Bool
    @Binding var selectedBucketForViewing: Bucket?
    
    private let columns = [
        GridItem(.adaptive(minimum: 168, maximum: 168), spacing: 20)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(buckets.filter { ($0.systemName ?? "") != "inbox" }, id: \.id) { bucket in
                UpdatedBucketCardView(
                    bucket: bucket,
                    selectedBucketForEditing: $selectedBucketForEditing,
                    showingInboxView: $showingInboxView,
                    selectedBucketForViewing: $selectedBucketForViewing
                )
            }
        }
        .padding(.horizontal, UI.inset)
        .padding(.bottom, UI.gapL)
    }
}

struct UpdatedBucketCardView: View {
    let bucket: Bucket
    @EnvironmentObject var dataController: DataController
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    @Binding var selectedBucketForEditing: Bucket?
    @Binding var showingInboxView: Bool
    @Binding var selectedBucketForViewing: Bucket?
    
    @FetchRequest private var items: FetchedResults<StashItem>
    @FetchRequest private var unprocessedItems: FetchedResults<StashItem>
    
    init(bucket: Bucket, selectedBucketForEditing: Binding<Bucket?>, showingInboxView: Binding<Bool>, selectedBucketForViewing: Binding<Bucket?>) {
        self.bucket = bucket
        self._selectedBucketForEditing = selectedBucketForEditing
        self._showingInboxView = showingInboxView
        self._selectedBucketForViewing = selectedBucketForViewing
        
        self._items = FetchRequest(
            sortDescriptors: [],
            predicate: NSPredicate(format: "bucket == %@", bucket.systemName ?? "")
        )
        
        self._unprocessedItems = FetchRequest(
            sortDescriptors: [],
            predicate: NSPredicate(format: "bucket == %@ AND isProcessed == NO", bucket.systemName ?? "")
        )
    }
    
    @State private var animateCount = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: bucket.icon ?? "folder")
                    .font(.title3)
                    .foregroundColor(DesignSystem.enhancedIconColor(cardColor, colorScheme))
                Text(displayName)
                    .font(.subheadline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .foregroundColor(DesignSystem.primaryText(colorScheme))
                Spacer()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 100)
        .background(
            Group {
                if colorScheme == .dark {
                    // Dark mode: no gradients, just white outline
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.22), lineWidth: 1)
                        )
                        .adaptiveStrongShadow(colorScheme)
                } else {
                    // Light mode: liquid glass
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            // Subtle glass stroke
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(colors: [Color.white.opacity(0.6), Color.white.opacity(0.2)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing),
                                    lineWidth: 1
                                )
                        )
                        .overlay(
                            // Bucket color accent border (very light)
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(cardColor.opacity(0.15), lineWidth: 1)
                        )
                        .overlay(
                            // Sheen highlight
                            RoundedRectangle(cornerRadius: 16)
                                .fill(LinearGradient(colors: [Color.white.opacity(0.22), Color.clear],
                                                     startPoint: .topLeading,
                                                     endPoint: .bottomTrailing))
                                .blendMode(.overlay)
                        )
                        .adaptiveStrongShadow(colorScheme)
                }
            }
        )
        // No numeric badges or checkmark badges per latest spec
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if isInboxBucket {
                showingInboxView = true
            } else {
                selectedBucketForViewing = bucket
            }
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            selectedBucketForEditing = bucket
        } onPressingChanged: { pressing in
            withAnimation(.easeInOut(duration: 0.2)) {
                isPressed = pressing
            }
        }
        .onChange(of: items.count) { _ in
            animateCount = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { animateCount = false }
        }
    }
    
    private var isInboxBucket: Bool {
        bucket.systemName == "inbox"
    }
    
    private var displayName: String {
        bucket.customName ?? bucket.systemName?.capitalized ?? "Unknown"
    }
    
    private var cardColor: Color {
        switch bucket.colorName {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "red": return .red
        case "yellow": return .yellow
        case "teal": return .teal
        default: return .gray
        }
    }

    private var statsLabel: String {
        let itemCount = items.count
        let breakdown = unprocessedItems.count > 0 ? "\(unprocessedItems.count) to review" : "all reviewed ✓"
        return "\(itemCount) items: \(breakdown)"
    }
    
    // MARK: - Visual State Helpers
    @State private var pulse = true
    // Reduced noise: remove last updated / overdue flags
}

// MARK: - Input Sheets
struct TextInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Binding var text: String
    @State private var editingText: String = ""
    let onSave: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(DesignSystem.accent(colorScheme).opacity(0.12))
                        Image(systemName: "square.and.pencil")
                    .foregroundColor(DesignSystem.accent(colorScheme))
                    }
                    .frame(width: 36, height: 36)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("New Note")
                            .font(.headline)
                        Text("Write anything. Keep it short or long.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top)

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(DesignSystem.cardBackground(colorScheme))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )

                    TextEditor(text: $editingText)
                        .padding(12)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)

                    if editingText.isEmpty {
                        Text("Start typing…")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 18)
                    }
                }
                .frame(minHeight: 180)
                .padding(.horizontal)

                HStack {
                    Button {
                        if let s = UIPasteboard.general.string {
                            editingText += (editingText.isEmpty ? "" : "\n") + s
                        }
                    } label: {
                        Label("Paste", systemImage: "doc.on.clipboard")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        editingText = ""
                    } label: {
                        Label("Clear", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)

                    Spacer()
                    Text("\(editingText.count) chars")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                Spacer(minLength: 10)
            }
            .navigationTitle("Add Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        text = editingText
                        onSave()
                        dismiss()
                    } label: {
                        Text("Save")
                            .fontWeight(.semibold)
                    }
                    .disabled(editingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            editingText = text
        }
    }
}

struct URLInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var url: String
    @State private var editingURL: String = ""
    let onSave: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Enter URL or paste from clipboard")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top)
                
                TextField("https://example.com", text: $editingURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .padding(.horizontal)
                
                Button(action: pasteFromClipboard) {
                    HStack {
                        Image(systemName: "doc.on.clipboard")
                        Text("Paste from Clipboard")
                    }
                    .foregroundColor(.blue)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Add Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        url = editingURL
                        onSave()
                        dismiss()
                    }
                    .disabled(editingURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            editingURL = url
        }
    }
    
    private func pasteFromClipboard() {
        if let clipboardString = UIPasteboard.general.string {
            editingURL = clipboardString
        }
    }
}

// MARK: - Voice Recorder
struct VoiceRecorderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let onFinish: (URL, TimeInterval) -> Void

    @State private var session = AVAudioSession.sharedInstance()
    @State private var recorder: AVAudioRecorder?
    @State private var isRecording = false
    @State private var currentTime: TimeInterval = 0
    @State private var meterLevel: Float = 0
    @State private var timer: Timer?
    @State private var recordingURL: URL = FileManager.default.temporaryDirectory.appendingPathComponent("voice_\(UUID().uuidString).m4a")

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Title + subtitle
                VStack(spacing: 6) {
                    Text("Record Voice Note")
                        .font(.title3).fontWeight(.semibold)
                    Text(isRecording ? "Recording…" : "Tap to start recording")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Simple meter
                ZStack {
                    Capsule()
                        .fill(DesignSystem.cardBackground(colorScheme))
                        .frame(height: 20)
                    GeometryReader { geo in
                        let width = max(6, CGFloat((meterLevel + 160) / 160) * geo.size.width)
                        Capsule()
                            .fill(isRecording ? Color.red : Color.gray)
                            .frame(width: width, height: 20)
                    }
                    .frame(height: 20)
                }
                .padding(.horizontal)

                // Timer label
                Text(formatDuration(currentTime))
                    .font(.system(size: 32, weight: .medium, design: .monospaced))

                // Big record/pause button
                Button(action: toggleRecording) {
                    ZStack {
                        Circle().fill(isRecording ? Color.red : DesignSystem.accent(colorScheme))
                        Image(systemName: isRecording ? "pause.fill" : "mic.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 36, weight: .bold))
                    }
                    .frame(width: 88, height: 88)
                    .shadow(color: (isRecording ? Color.red : DesignSystem.accent(colorScheme)).opacity(0.4), radius: 8, x: 0, y: 6)
                }

                // Stop/Save
                Button(action: stopAndSave) {
                    Text("Save Recording")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue))
                        .foregroundColor(.white)
                        .padding(.horizontal)
                }
                .disabled(!fileExists)

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        cleanup()
                        dismiss()
                    }
                }
            }
        }
        .onAppear(perform: configureSession)
        .onDisappear(perform: cleanup)
    }

    private var fileExists: Bool { FileManager.default.fileExists(atPath: recordingURL.path) }

    private func configureSession() {
        do {
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
            try session.setActive(true)
            session.requestRecordPermission { _ in }
        } catch { }
    }

    private func toggleRecording() {
        if isRecording {
            pause()
        } else {
            start()
        }
    }

    private func start() {
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        do {
            recorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            recorder?.isMeteringEnabled = true
            recorder?.record()
            isRecording = true
            startTimer()
        } catch {
            isRecording = false
        }
    }

    private func pause() {
        recorder?.pause()
        isRecording = false
        stopTimer()
    }

    private func stopAndSave() {
        recorder?.stop()
        isRecording = false
        stopTimer()
        onFinish(recordingURL, currentTime)
        dismiss()
    }

    private func startTimer() {
        currentTime = 0
        meterLevel = -160
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recorder?.updateMeters()
            meterLevel = recorder?.averagePower(forChannel: 0) ?? -160
            currentTime = recorder?.currentTime ?? currentTime
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func cleanup() {
        recorder?.stop()
        recorder = nil
        stopTimer()
        try? session.setActive(false)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// Removed ImagePickerSheet in favor of direct PHPicker

// Direct PHPicker wrapper to open the system photo library immediately
import PhotosUI
struct PhotoLibraryPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoLibraryPicker
        init(_ parent: PhotoLibraryPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            // Dismiss the picker promptly; we'll handle data via callbacks
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider else {
                parent.onCancel()
                return
            }
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    DispatchQueue.main.async {
                        if let image = object as? UIImage {
                            self.parent.onImage(image)
                        } else {
                            self.parent.onCancel()
                        }
                    }
                }
            } else {
                parent.onCancel()
            }
        }
    }
}

// MARK: - Settings & Onboarding (inlined for target inclusion)
import Photos
import UserNotifications

struct SettingsView: View {
    let onRequestOnboarding: () -> Void

    @State private var photosStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @State private var notificationsStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Capture Tips")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Take screenshots to auto-capture into Inbox", systemImage: "camera.viewfinder")
                        Label("Use the + to add photos, links, text, or voice", systemImage: "plus.circle")
                        Label("Long-press items to move them between buckets", systemImage: "hand.point.up.left")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }

                Section(header: Text("Permissions")) {
                    HStack {
                        Label("Photos", systemImage: "photo")
                        Spacer()
                        Text(statusText(for: photosStatus))
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { requestPhotosAccess() }

                    HStack {
                        Label("Notifications", systemImage: "bell")
                        Spacer()
                        Text(statusText(for: notificationsStatus))
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { requestNotifications() }
                }

                Section(header: Text("Onboarding")) {
                    Button { onRequestOnboarding() } label: {
                        Label("Re-run Onboarding", systemImage: "sparkles")
                    }
                }

                Section(header: Text("About")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Stash")
                            .font(.headline)
                        Text("Capture everything. Deal with it later.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
        }
        .onAppear { refreshNotificationStatus() }
    }

    private func dismiss() { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
    private func statusText(for status: PHAuthorizationStatus) -> String {
        switch status { case .authorized: return "Allowed"; case .limited: return "Limited"; case .denied: return "Denied"; case .restricted: return "Restricted"; case .notDetermined: return "Not Determined"; @unknown default: return "Unknown" }
    }
    private func statusText(for status: UNAuthorizationStatus) -> String {
        switch status { case .authorized, .provisional, .ephemeral: return "Allowed"; case .denied: return "Denied"; case .notDetermined: return "Not Determined"; @unknown default: return "Unknown" }
    }
    private func requestPhotosAccess() { PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in DispatchQueue.main.async { photosStatus = newStatus } } }
    private func refreshNotificationStatus() { UNUserNotificationCenter.current().getNotificationSettings { s in DispatchQueue.main.async { notificationsStatus = s.authorizationStatus } } }
    private func requestNotifications() { UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in refreshNotificationStatus() } }
}

struct OnboardingView: View {
    let onDone: () -> Void
    @State private var selection = 0
    var body: some View {
        ZStack(alignment: .topTrailing) {
            TabView(selection: $selection) {
                OnboardingPage(systemImage: "tray", title: "Inbox First", subtitle: "Screenshots and quick captures land in Inbox so you can organize later.").tag(0)
                OnboardingPage(systemImage: "square.and.arrow.down.on.square.fill", title: "+ to Capture", subtitle: "Add Photos, Links, Text, or Voice with one tap.").tag(1)
                OnboardingPage(systemImage: "folder.fill", title: "Stacks", subtitle: "Move items into Work, Shopping, Ideas, or Personal.").tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))

            Button(action: onDone) { Text("Skip").padding(12) }
        }
        .overlay(alignment: .bottom) {
            HStack {
                if selection > 0 { Button("Back") { withAnimation { selection -= 1 } }.buttonStyle(.bordered) }
                Spacer()
                Button(selection == 2 ? "Done" : "Next") { if selection < 2 { withAnimation { selection += 1 } } else { onDone() } }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}
private struct OnboardingPage: View {
    @Environment(\.colorScheme) private var colorScheme
    let systemImage: String; let title: String; let subtitle: String
    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 40)
            Image(systemName: systemImage).font(.system(size: 80)).foregroundColor(DesignSystem.accent(colorScheme))
            Text(title).font(.title).fontWeight(.semibold)
            Text(subtitle).font(.body).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
            Spacer()
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, DataController().container.viewContext)
        .environmentObject(DataController())
}
// MARK: - Recently Added (Collapsed)
struct RecentlyAddedSection: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @FetchRequest private var recentItems: FetchedResults<StashItem>
    let onOpenGroup: (RecentGroup) -> Void

    init(onOpenGroup: @escaping (RecentGroup) -> Void) {
        self.onOpenGroup = onOpenGroup
        _recentItems = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \StashItem.createdAt, ascending: false)],
            predicate: NSPredicate(value: true),
            animation: .default
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !recentItems.isEmpty {
                Text("Recently Added")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.primaryText(colorScheme))
                    .padding(.horizontal, UI.inset)
                    .padding(.top, UI.gapS)

                RecentlyAddedCarousel(
                    groups: collapseByType(Array(recentItems)),
                    onOpen: onOpenGroup
                )
                .padding(.bottom, UI.gapM)
            }
        }
    }
}

// MARK: - Recent Group Browser
private struct GroupItemsSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let group: RecentGroup
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: StashItem?

    private let photoColumns = [GridItem(.adaptive(minimum: 110), spacing: 10)]

    var body: some View {
        NavigationView {
            Group {
                switch group.type {
                case .photo:
                    ScrollView {
                        LazyVGrid(columns: photoColumns, spacing: 10) {
                            ForEach(group.items, id: \.id) { item in
                                if let data = item.content, let ui = UIImage(data: data) {
                                    Button {
                                        selectedItem = item
                                    } label: {
                                        Image(uiImage: ui)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(height: 110)
                                            .clipped()
                                            .overlay(alignment: .bottomLeading) {
                                                if let created = item.createdAt {
                                                    Text(created, style: .time)
                                                        .font(.caption2)
                                                        .padding(.horizontal, 4)
                                                        .padding(.vertical, 2)
                                                        .background(Color.black.opacity(0.5))
                                                        .foregroundColor(.white)
                                                        .clipShape(Capsule())
                                                        .padding(6)
                                                }
                                            }
                                    }
                                    .buttonStyle(.plain)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                        .padding(12)
                    }
                case .link, .text, .voice:
                    List {
                        ForEach(group.items, id: \.id) { item in
                            Button {
                                selectedItem = item
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: iconName)
                                        .foregroundColor(accentColor)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(title)
                                            .font(.subheadline).fontWeight(.semibold)
                                        Text(ItemInsights.smartDescription(for: item))
                                            .font(.footnote)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                    Spacer()
                                    if let created = item.createdAt {
                                        Text(created, style: .time)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Recent \(titlePlural) (\(group.items.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Close") { dismiss() } }
            }
        }
        .sheet(item: $selectedItem) { item in
            ItemDetailView(item: item)
        }
    }

    private var title: String {
        switch group.type { case .photo: return "Photo"; case .link: return "Link"; case .text: return "Text"; case .voice: return "Voice" }
    }
    private var titlePlural: String { title + "s" }
    private var iconName: String {
        switch group.type { case .photo: return "photo"; case .link: return "link"; case .text: return "text.alignleft"; case .voice: return "waveform" }
    }
    private var accentColor: Color {
        switch group.type { case .photo: return .red; case .link: return DesignSystem.accent(colorScheme); case .text: return .green; case .voice: return .orange }
    }
}
