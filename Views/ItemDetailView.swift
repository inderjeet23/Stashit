import SwiftUI
import UIKit
import AVFoundation
import LinkPresentation
import SafariServices

struct ItemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var dataController: DataController
    
    let item: StashItem
    @State private var selectedBucket: BucketType = .inbox
    @State private var showingDeleteAlert = false
    @State private var showImageViewer = false
    @State private var showConfetti = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Media/Content Display Area (hero)
                    mediaDisplaySection
                        .padding(.horizontal, 16)

                    // Primary action: quick bucket picker
                    bucketPickerSection
                        .padding(.horizontal, 12)

                    // Compact details and detected text
                    contentDetailsSection
                        .padding(.horizontal, 16)

                    // Smart Actions Section
                    smartActionsSection
                        .padding(.horizontal, 16)

                    // Rich Metadata Panel
                    richMetadataSection
                        .padding(.horizontal, 16)

                    // Timeline & Context
                    timelineContextSection
                        .padding(.horizontal, 16)

                    // Organization Tools
                    organizationToolsSection
                        .padding(.horizontal, 16)

                    // Smart Insights
                    smartInsightsSection
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                }
            }
            .navigationTitle("Item Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                // Less prominent actions moved into a menu
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if hasImage { Button("Save to Photos") { saveImageToPhotos() } }
                        if let link = item.url, URL(string: link) != nil {
                            Button("Open Link") { openLinkInApp() }
                            Button("Share Link") { shareLink() }
                        }
                        if item.type == "voice", item.content != nil {
                            Button("Share Audio") { shareAudio() }
                        }
                        if item.type == "text", let text = item.ocrText, !text.isEmpty {
                            Button("Copy Text") { UIPasteboard.general.string = text }
                            Button("Share Text") { shareText() }
                        }
                        Button(role: .destructive) { showingDeleteAlert = true } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                // Quick access Save action when a bucket is chosen
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedBucket != .inbox {
                        Button("Save") { dismiss() }
                            .foregroundColor(bucketColor)
                            .fontWeight(.semibold)
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if let prev = previousBucket, showUndoToast {
                    HStack(spacing: 12) {
                        Text("Moved to \(selectedBucket.displayName)")
                            .font(.caption)
                        Button("Undo") { undoMove(to: prev) }
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 16)
                }
            }
            .overlay(
                Group { if showConfetti { ConfettiView().ignoresSafeArea() } }
            )
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
        .onAppear {
            selectedBucket = BucketType(rawValue: item.bucket ?? "inbox") ?? .inbox
        }
        // Safari + Share presentations
        .sheet(isPresented: $showSafari) {
            if let url = safariURL {
                SafariView(url: url)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
    }
    
    // MARK: - Media Display Section
    @ViewBuilder
    private var mediaDisplaySection: some View {
        Group {
            if let uiImage = largeUIImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { showImageViewer = true }
                    .gesture(swipeGesture)
            } else if item.type == "voice", let data = item.content {
                VoicePlayerView(audioData: data)
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
            } else if item.type == "link", let urlString = item.url, let url = URL(string: urlString) {
                LinkRichPreview(url: url)
                    .frame(height: 240)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { safariURL = url; showSafari = true }
            } else if item.type == "text", let text = item.ocrText, !text.isEmpty {
                ScrollView {
                    Text(text)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 200)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.systemGray4)))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                        .frame(maxWidth: .infinity)
                        .frame(height: 240)
                    VStack(spacing: 12) {
                        Image(systemName: itemTypeIcon)
                            .font(.system(size: 44))
                            .foregroundColor(itemTypeColor)
                        Text(mediaDisplayText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .adaptiveStrongShadow(colorScheme)
        .contextMenu {
            Menu("Move To") {
                ForEach(BucketType.allCases, id: \.self) { bucket in
                    Button(bucket.displayName) { moveItemToBucket(bucket) }
                }
            }
            if hasImage { Button("Save to Photos") { saveImageToPhotos() } }
            Button(role: .destructive) { showingDeleteAlert = true } label: { Label("Delete", systemImage: "trash") }
        }
    }
    
    // MARK: - Content Details Section
    @ViewBuilder
    private var contentDetailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Compact metadata row
            HStack(spacing: 8) {
                Text(item.type?.capitalized ?? "Unknown")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(itemTypeColor.opacity(0.1))
                    .foregroundColor(itemTypeColor)
                    .clipShape(Capsule())

                if let createdAt = item.createdAt {
                    Text(createdAt, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(item.bucket?.capitalized ?? "Inbox")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(bucketColor.opacity(0.1))
                    .foregroundColor(bucketColor)
                    .clipShape(Capsule())
            }

            // Detected text or URL preview (quiet)
            if let detected = detectedSummary {
                Text("Detected: \(detected)")
                    .font(.callout)
                    .foregroundColor(.primary)
                    .lineLimit(3)
            }

            if let caption = ItemInsights.softCaption(for: item) {
                Text(caption)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if let hint = ItemInsights.hint(for: item) {
                Text(hint)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Bucket Picker Section (Primary action)
    @ViewBuilder
    private var bucketPickerSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(BucketType.allCases, id: \.self) { bucket in
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        moveItemToBucket(bucket)
                    }) {
                        VStack(spacing: 6) {
                            Text(bucket.emoji).font(.title2)
                            Text(bucket.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(selectedBucket == bucket ? bucket.color.opacity(0.2) : Color(.systemGray6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(selectedBucket == bucket ? bucket.color : Color.clear, lineWidth: 2)
                        )
                        .foregroundColor(.primary)
                        .scaleEffect(selectedBucket == bucket ? 1.05 : 1.0)
                        .shadow(color: selectedBucket == bucket ? bucket.color.opacity(0.25) : .clear, radius: selectedBucket == bucket ? 6 : 0, x: 0, y: selectedBucket == bucket ? 4 : 0)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Smart Actions Section
    @ViewBuilder
    private var smartActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(smartActions, id: \.title) { action in
                    SmartActionButton(action: action)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.systemGray5), lineWidth: 1))
    }

    // MARK: - Rich Metadata Section
    @ViewBuilder
    private var richMetadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                // Auto-generated tags
                if !autoTags.isEmpty {
                    HStack {
                        Text("Tags:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 6) {
                            ForEach(autoTags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(.systemBlue).opacity(0.1))
                                    .foregroundColor(.blue)
                                    .clipShape(Capsule())
                            }
                        }
                        Spacer()
                    }
                }
                
                // Enhanced content analysis
                if let analysis = contentAnalysis {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(analysis, id: \.key) { item in
                            HStack {
                                Text(item.key)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(item.value)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.systemGray5), lineWidth: 1))
    }

    // MARK: - Timeline & Context Section
    @ViewBuilder
    private var timelineContextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timeline")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                TimelineItem(
                    title: "Created",
                    time: item.createdAt ?? Date(),
                    icon: "plus.circle.fill",
                    color: .green
                )
                
                if let updatedAt = item.updatedAt, updatedAt != item.createdAt {
                    TimelineItem(
                        title: "Last Updated",
                        time: updatedAt,
                        icon: "pencil.circle.fill",
                        color: .blue
                    )
                }
                
                if item.isProcessed {
                    TimelineItem(
                        title: "Organized",
                        time: item.updatedAt ?? Date(),
                        icon: "checkmark.circle.fill",
                        color: .orange
                    )
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.systemGray5), lineWidth: 1))
    }

    // MARK: - Organization Tools Section
    @State private var personalNotes: String = ""
    @State private var showingReminderPicker = false
    
    @ViewBuilder
    private var organizationToolsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Organization")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                // Personal Notes
                VStack(alignment: .leading, spacing: 6) {
                    Text("Personal Notes")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("Add your notes...", text: $personalNotes, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                }
                
                // Quick organization actions
                HStack(spacing: 12) {
                    OrganizationButton(
                        title: "Set Reminder",
                        icon: "bell.fill",
                        color: .orange
                    ) {
                        showingReminderPicker = true
                    }
                    
                    OrganizationButton(
                        title: "Mark Important",
                        icon: item.confidence > 0.8 ? "star.fill" : "star",
                        color: .yellow
                    ) {
                        toggleImportance()
                    }
                    
                    OrganizationButton(
                        title: "Archive",
                        icon: "archivebox.fill",
                        color: .gray
                    ) {
                        archiveItem()
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.systemGray5), lineWidth: 1))
        .sheet(isPresented: $showingReminderPicker) {
            ReminderPickerView(item: item)
        }
    }

    // MARK: - Smart Insights Section
    @ViewBuilder
    private var smartInsightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Smart Insights")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                ForEach(smartInsights, id: \.title) { insight in
                    InsightCard(insight: insight)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.systemGray5), lineWidth: 1))
    }
    
    // (Bottom overlay removed to declutter; primary actions moved near hero image and toolbar)
    
    // MARK: - Computed Properties
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
    
    private var bucketColor: Color {
        switch item.bucket {
        case "work": return .blue
        case "shopping": return .green
        case "ideas": return .orange
        case "personal": return .purple
        case "inbox": return .gray
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
    
    private var mediaDisplayText: String {
        switch item.type {
        case "screenshot": return "Screenshot"
        case "photo": return "Photo"
        case "voice": return "Voice Recording"
        case "link": return "Link Preview"
        case "text": return "Text Content"
        default: return "Preview"
        }
    }

    private var largeUIImage: UIImage? {
        guard (item.type == "screenshot" || item.type == "photo"),
              let data = item.content,
              let uiImage = UIImage(data: data) else { return nil }
        return uiImage
    }
    
    // MARK: - Actions
    private func moveItemToBucket(_ bucket: BucketType) {
        guard bucket.rawValue != item.bucket else { return }
        
        withAnimation {
            previousBucket = BucketType(rawValue: item.bucket ?? "inbox")
            item.bucket = bucket.rawValue
            item.isProcessed = bucket != .inbox
            item.updatedAt = Date()
            
            dataController.save()
            selectedBucket = bucket
            showUndoToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation { showUndoToast = false }
            }
            if item.isProcessed { triggerCompletionCelebration() }
        }
    }

    private func triggerCompletionCelebration() {
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
        withAnimation(.spring()) { showConfetti = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { showConfetti = false }
        }
    }
    
    private func deleteItem() {
        withAnimation {
            viewContext.delete(item)
            dataController.save()
            dismiss()
        }
    }

    // MARK: - Gestures & Helpers
    @State private var showUndoToast = false
    @State private var previousBucket: BucketType? = nil

    private func undoMove(to bucket: BucketType) {
        moveItemToBucket(bucket)
        withAnimation { showUndoToast = false }
    }
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                guard abs(value.translation.width) > 40 else { return }
                if value.translation.width < 0 { moveToNextBucket() } else { moveToPreviousBucket() }
            }
    }

    private func moveToNextBucket() {
        let all = BucketType.allCases
        guard let idx = all.firstIndex(of: selectedBucket) else { return }
        let next = all[(idx + 1) % all.count]
        moveItemToBucket(next)
    }

    private func moveToPreviousBucket() {
        let all = BucketType.allCases
        guard let idx = all.firstIndex(of: selectedBucket) else { return }
        let prev = all[(idx - 1 + all.count) % all.count]
        moveItemToBucket(prev)
    }

    private var hasImage: Bool {
        (item.type == "screenshot" || item.type == "photo") && item.content != nil
    }

    private func saveImageToPhotos() {
        guard let uiImage = largeUIImage else { return }
        UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
    }

    private var detectedSummary: String? {
        if let text = item.ocrText, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return text }
        if let url = item.url, !url.isEmpty { return url }
        return nil
    }

    // MARK: - Share / Open helpers
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var showSafari = false
    @State private var safariURL: URL?

    private func openLinkInApp() {
        guard let s = item.url, let url = URL(string: s) else { return }
        safariURL = url
        showSafari = true
    }

    private func shareLink() {
        guard let s = item.url, let url = URL(string: s) else { return }
        shareItems = [url]
        showShareSheet = true
    }

    private func shareText() {
        guard let text = item.ocrText, !text.isEmpty else { return }
        shareItems = [text]
        showShareSheet = true
    }

    private func shareAudio() {
        guard let data = item.content else { return }
        let url = exportToTemp(data: data, suggestedName: "voice_\(item.id?.uuidString ?? UUID().uuidString).m4a")
        shareItems = [url]
        showShareSheet = true
    }

    private func exportToTemp(data: Data, suggestedName: String) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(suggestedName)
        try? data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Smart Actions Computed Properties
    private var smartActions: [SmartAction] {
        var actions: [SmartAction] = []
        
        // Context-aware actions based on item type
        switch item.type {
        case "screenshot", "photo":
            if hasImage {
                actions.append(SmartAction(title: "Save to Photos", icon: "square.and.arrow.down", color: .blue) {
                    saveImageToPhotos()
                })
                actions.append(SmartAction(title: "Extract Text", icon: "doc.text.viewfinder", color: .green) {
                    // TODO: Implement OCR extraction
                })
            }
        case "link":
            if let urlString = item.url, let url = URL(string: urlString) {
                actions.append(SmartAction(title: "Open Link", icon: "safari", color: .blue) {
                    openLinkInApp()
                })
                actions.append(SmartAction(title: "Share Link", icon: "square.and.arrow.up", color: .green) {
                    shareLink()
                })
            }
        case "text":
            if let text = item.ocrText, !text.isEmpty {
                actions.append(SmartAction(title: "Copy Text", icon: "doc.on.doc", color: .blue) {
                    UIPasteboard.general.string = text
                })
                actions.append(SmartAction(title: "Translate", icon: "globe", color: .orange) {
                    // TODO: Implement translation
                })
            }
        case "voice":
            if item.content != nil {
                actions.append(SmartAction(title: "Share Audio", icon: "square.and.arrow.up", color: .blue) {
                    shareAudio()
                })
                actions.append(SmartAction(title: "Transcribe", icon: "waveform.and.microphone", color: .green) {
                    // TODO: Implement transcription
                })
            }
        default:
            break
        }
        
        // Universal actions
        actions.append(SmartAction(title: "Duplicate", icon: "plus.square.on.square", color: .purple) {
            duplicateItem()
        })
        
        return Array(actions.prefix(6)) // Limit to 6 actions
    }

    private var autoTags: [String] {
        return ItemInsights.tags(for: item)
    }

    private var contentAnalysis: [(key: String, value: String)]? {
        var analysis: [(key: String, value: String)] = []
        
        // File size for images/audio
        if let data = item.content {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB]
            formatter.countStyle = .file
            analysis.append(("Size", formatter.string(fromByteCount: Int64(data.count))))
        }
        
        // Text analysis
        if let text = item.ocrText, !text.isEmpty {
            analysis.append(("Word Count", "\(text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count)"))
            
            let readingTime = max(1, text.count / 200) // ~200 words per minute
            analysis.append(("Reading Time", "\(readingTime) min"))
        }
        
        // URL analysis
        if let urlString = item.url, let url = URL(string: urlString) {
            if let host = url.host {
                analysis.append(("Source", host.replacingOccurrences(of: "www.", with: "")))
            }
        }
        
        return analysis.isEmpty ? nil : analysis
    }

    private var smartInsights: [SmartInsight] {
        var insights: [SmartInsight] = []
        
        // Duplicate detection
        // TODO: Implement duplicate detection logic
        
        // Content suggestions
        if let text = item.ocrText {
            if text.localizedCaseInsensitiveContains("recipe") && item.bucket != "personal" {
                insights.append(SmartInsight(
                    title: "Recipe Detected",
                    description: "This looks like a recipe. Consider moving it to Personal bucket.",
                    icon: "fork.knife",
                    color: .orange,
                    actionTitle: "Move to Personal"
                ) {
                    moveItemToBucket(.personal)
                })
            }
            
            if text.localizedCaseInsensitiveContains("price") || text.localizedCaseInsensitiveContains("$") {
                if item.bucket != "shopping" {
                    insights.append(SmartInsight(
                        title: "Product Information",
                        description: "Contains pricing info. Consider moving to Shopping bucket.",
                        icon: "cart",
                        color: .green,
                        actionTitle: "Move to Shopping"
                    ) {
                        moveItemToBucket(.shopping)
                    })
                }
            }
        }
        
        // Time-based insights
        if let created = item.createdAt {
            let daysSince = Calendar.current.dateComponents([.day], from: created, to: Date()).day ?? 0
            if daysSince > 7 && !item.isProcessed {
                insights.append(SmartInsight(
                    title: "Organize This Item",
                    description: "This item has been in your inbox for \(daysSince) days.",
                    icon: "tray.and.arrow.down",
                    color: .blue,
                    actionTitle: nil,
                    action: nil
                ))
            }
        }
        
        return insights
    }

    // MARK: - Action Methods
    private func duplicateItem() {
        let context = dataController.container.viewContext
        
        let duplicate = StashItem(context: context)
        duplicate.id = UUID()
        duplicate.type = item.type
        duplicate.bucket = "inbox"
        duplicate.createdAt = Date()
        duplicate.updatedAt = Date()
        duplicate.isProcessed = false
        duplicate.userCorrectedBucket = false
        duplicate.confidence = 0.0
        duplicate.content = item.content
        duplicate.url = item.url
        duplicate.ocrText = item.ocrText
        
        dataController.save()
        
        let impact = UINotificationFeedbackGenerator()
        impact.notificationOccurred(.success)
    }

    private func toggleImportance() {
        withAnimation {
            item.confidence = item.confidence > 0.8 ? 0.5 : 1.0
            item.updatedAt = Date()
            dataController.save()
        }
    }

    private func archiveItem() {
        withAnimation {
            // TODO: Implement archive functionality
            let impact = UINotificationFeedbackGenerator()
            impact.notificationOccurred(.success)
        }
    }
}
 

// MARK: - Fullscreen Viewer
struct FullscreenImageViewer: View {
    let uiImage: UIImage
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.black.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(12)
            }
        }
        .onTapGesture { dismiss() }
    }
}

#Preview {
    let context = DataController().container.viewContext
    let sampleItem = StashItem(context: context)
    sampleItem.id = UUID()
    sampleItem.type = "screenshot"
    sampleItem.bucket = "inbox"
    sampleItem.createdAt = Date()
    sampleItem.ocrText = "Sample screenshot text content that would normally be extracted from the image"
    
    return ItemDetailView(item: sampleItem)
        .environmentObject(DataController())
}


// Lightweight confetti emitter for completion feedback
import UIKit
struct ConfettiView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(x: UIScreen.main.bounds.midX, y: -10)
        emitter.emitterShape = .line
        emitter.emitterSize = CGSize(width: UIScreen.main.bounds.width, height: 1)
        emitter.emitterCells = [makeCell("🎉"), makeCell("✨"), makeCell("✅")]
        view.layer.addSublayer(emitter)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { emitter.birthRate = 0 }
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
    private func makeCell(_ emoji: String) -> CAEmitterCell {
        let c = CAEmitterCell()
        c.birthRate = 6; c.lifetime = 4; c.velocity = 160; c.velocityRange = 60
        c.emissionLongitude = .pi; c.emissionRange = .pi/6
        c.spin = 3.5; c.spinRange = 4; c.scale = 0.6; c.scaleRange = 0.3
        c.contents = image(from: emoji).cgImage
        return c
    }
    private func image(from text: String) -> UIImage {
        let size = CGSize(width: 24, height: 24)
        let r = UIGraphicsImageRenderer(size: size)
        return r.image { _ in (text as NSString).draw(at: .zero, withAttributes: [.font: UIFont.systemFont(ofSize: 24)]) }
    }
}

// MARK: - Voice Player with Waveform
struct VoicePlayerView: View {
    @Environment(\.colorScheme) private var colorScheme
    let audioData: Data
    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var levels: [CGFloat] = Array(repeating: 0.05, count: 48)
    @State private var progress: Double = 0

    private let timer = Timer.publish(every: 0.06, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
            VStack(spacing: 16) {
                // Waveform bars
                GeometryReader { geo in
                    let barWidth: CGFloat = max(2, geo.size.width / CGFloat(levels.count * 2))
                    let maxHeight = geo.size.height
                    HStack(alignment: .center, spacing: barWidth) {
                        ForEach(levels.indices, id: \.self) { i in
                            let h = max(4, levels[i] * maxHeight)
                            Capsule()
                                .fill(isPlaying ? Color.orange : Color.gray)
                                .frame(width: barWidth, height: h)
                                .animation(.linear(duration: 0.06), value: levels)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Controls
                VStack(spacing: 8) {
                    // Scrubber
                    if let p = player {
                        Slider(value: Binding(
                            get: { progress },
                            set: { newVal in
                                progress = newVal
                                p.currentTime = newVal * p.duration
                            }
                        ), in: 0...1)
                    }
                    HStack(spacing: 16) {
                        Button(action: togglePlayback) {
                            let buttonColor = isPlaying ? Color.orange : (colorScheme == .dark ? Color.white : Color.black)
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Circle().fill(buttonColor))
                                .shadow(color: buttonColor.opacity(0.3), radius: 6, x: 0, y: 4)
                        }
                        if let p = player {
                            Text(timeLabel(current: p.currentTime, duration: p.duration))
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .padding(12)
        }
        .onAppear(perform: configurePlayer)
        .onReceive(timer) { _ in updateMeter() }
        .onDisappear { player?.stop() }
    }

    private func configurePlayer() {
        do {
            let p = try AVAudioPlayer(data: audioData)
            p.isMeteringEnabled = true
            p.prepareToPlay()
            player = p
        } catch {
            player = nil
        }
    }

    private func togglePlayback() {
        guard let p = player else { return }
        if isPlaying {
            p.pause()
            isPlaying = false
        } else {
            p.play()
            isPlaying = true
        }
    }

    private func updateMeter() {
        guard isPlaying, let p = player else { return }
        p.updateMeters()
        let power = p.averagePower(forChannel: 0) // -160...0 dB
        let linear = max(0, min(1, pow(10, power / 20)))
        let smoothed = CGFloat(0.6 * Double(linear) + 0.4 * Double(levels.last ?? 0.05))
        levels.append(smoothed)
        if levels.count > 48 { levels.removeFirst(levels.count - 48) }
        if p.isPlaying == false { isPlaying = false }
        progress = p.duration > 0 ? p.currentTime / p.duration : 0
    }

    private func timeLabel(current: TimeInterval, duration: TimeInterval) -> String {
        func fmt(_ t: TimeInterval) -> String {
            let m = Int(t) / 60
            let s = Int(t) % 60
            return String(format: "%d:%02d", m, s)
        }
        return "\(fmt(current)) / \(fmt(duration))"
    }
}

// MARK: - Link Rich Preview (LPLinkView)
struct LinkRichPreview: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> LPLinkView {
        let view = LPLinkView(url: url)
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
        let provider = LPMetadataProvider()
        provider.startFetchingMetadata(for: url) { metadata, _ in
            DispatchQueue.main.async { if let metadata { view.metadata = metadata } }
        }
        return view
    }
    func updateUIView(_ uiView: LPLinkView, context: Context) {}
}

// MARK: - Safari and Share wrappers
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Supporting View Components

struct SmartAction {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
}

struct SmartActionButton: View {
    let action: SmartAction
    
    var body: some View {
        Button(action: action.action) {
            VStack(spacing: 6) {
                Image(systemName: action.icon)
                    .font(.title2)
                    .foregroundColor(action.color)
                
                Text(action.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(action.color.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(action.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TimelineItem: View {
    let title: String
    let time: Date
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(time.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct OrganizationButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.1))
            )
            .foregroundColor(color)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SmartInsight {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let actionTitle: String?
    let action: (() -> Void)?
}

struct InsightCard: View {
    let insight: SmartInsight
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: insight.icon)
                .foregroundColor(insight.color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(insight.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            if let actionTitle = insight.actionTitle, let action = insight.action {
                Button(actionTitle, action: action)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(insight.color)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(insight.color.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(insight.color.opacity(0.2), lineWidth: 1)
        )
    }
}

struct ReminderPickerView: View {
    let item: StashItem
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate = Date().addingTimeInterval(3600) // 1 hour from now
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Set Reminder")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                DatePicker("Remind me at", selection: $selectedDate, in: Date()...)
                    .datePickerStyle(WheelDatePickerStyle())
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Set") {
                        // TODO: Implement reminder setting
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
