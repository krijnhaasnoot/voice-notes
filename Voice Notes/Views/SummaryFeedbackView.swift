import SwiftUI

// MARK: - Summary Feedback Buttons

struct SummaryFeedbackButtons: View {
    let recording: Recording
    @ObservedObject private var feedbackService = SummaryFeedbackService.shared
    @State private var selectedFeedback: FeedbackType? = nil
    @State private var showingFeedbackSheet = false
    @State private var feedbackText = ""
    @State private var isSubmitting = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Thumbs Up Button
            Button(action: {
                submitFeedback(.thumbsUp)
            }) {
                Image(systemName: selectedFeedback == .thumbsUp ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .font(.system(size: 18))
                    .foregroundColor(selectedFeedback == .thumbsUp ? .green : .secondary)
                    .frame(width: 44, height: 32)
                    .background(selectedFeedback == .thumbsUp ? Color.green.opacity(0.1) : Color.clear)
                    .cornerRadius(8)
                    .scaleEffect(isSubmitting && selectedFeedback == .thumbsUp ? 0.95 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isSubmitting)
            }
            .buttonStyle(.plain)
            .disabled(isSubmitting)
            
            // Thumbs Down Button  
            Button(action: {
                // Provide immediate haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedFeedback = .thumbsDown
                    showingFeedbackSheet = true
                }
            }) {
                Image(systemName: selectedFeedback == .thumbsDown ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .font(.system(size: 18))
                    .foregroundColor(selectedFeedback == .thumbsDown ? .red : .secondary)
                    .frame(width: 44, height: 32)
                    .background(selectedFeedback == .thumbsDown ? Color.red.opacity(0.1) : Color.clear)
                    .cornerRadius(8)
                    .scaleEffect(isSubmitting && selectedFeedback == .thumbsDown ? 0.95 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isSubmitting)
            }
            .buttonStyle(.plain)
            .disabled(isSubmitting)
            
            if isSubmitting {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .sheet(isPresented: $showingFeedbackSheet) {
            FeedbackDetailSheet(
                recording: recording,
                onSubmit: { feedback in
                    // Close sheet first, then submit feedback
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingFeedbackSheet = false
                    }
                    
                    // Submit feedback after a small delay to allow sheet to close
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        submitFeedback(.thumbsDown, userFeedback: feedback)
                    }
                },
                onCancel: {
                    // Close sheet with animation
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingFeedbackSheet = false
                        
                        // Reset selection if user cancels thumbs down
                        if let existingFeedback = feedbackService.feedbackHistory.first(where: { $0.recordingId == recording.id }) {
                            selectedFeedback = existingFeedback.feedbackType
                        } else {
                            selectedFeedback = nil
                        }
                    }
                }
            )
        }
        .onAppear {
            // Check if feedback was already given for this recording
            if let existingFeedback = feedbackService.feedbackHistory.first(where: { $0.recordingId == recording.id }) {
                selectedFeedback = existingFeedback.feedbackType
            }
        }
    }
    
    private func submitFeedback(_ type: FeedbackType, userFeedback: String? = nil) {
        guard let summary = recording.summary, !summary.isEmpty else {
            print("❌ SummaryFeedback: No summary available for feedback")
            return
        }
        
        // Prevent multiple submissions
        guard !isSubmitting else {
            print("⚠️ SummaryFeedback: Already submitting, ignoring duplicate tap")
            return
        }
        
        // Immediate UI feedback
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedFeedback = type
            isSubmitting = true
        }
        
        // Provide haptic feedback immediately
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Submit feedback asynchronously without blocking UI
        Task { @MainActor in
            defer {
                // Always reset isSubmitting state
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSubmitting = false
                }
            }
            
            // Remove any existing feedback for this recording
            feedbackService.feedbackHistory.removeAll { $0.recordingId == recording.id }
            
            // Submit the new feedback - this will handle analytics in background
            feedbackService.submitFeedback(
                recordingId: recording.id,
                summaryText: summary,
                feedbackType: type,
                userFeedback: userFeedback,
                recording: recording
            )
            
            print("✅ SummaryFeedback: Successfully submitted \(type.rawValue) feedback")
        }
    }
}

// MARK: - Feedback Detail Sheet

struct FeedbackDetailSheet: View {
    let recording: Recording
    let onSubmit: (String?) -> Void
    let onCancel: () -> Void
    
    @State private var feedbackText = ""
    @State private var selectedIssues: Set<FeedbackIssue> = []
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "hand.thumbsdown.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.red.opacity(0.8))
                    
                    VStack(spacing: 8) {
                        Text("Help us improve")
                            .font(.poppins.title2)
                            .fontWeight(.semibold)
                        
                        Text("What could we do better with this summary?")
                            .font(.poppins.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 32)
                .padding(.horizontal, 24)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Quick Issue Selection
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Common issues:")
                                .font(.poppins.headline)
                                .fontWeight(.semibold)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 12) {
                                ForEach(FeedbackIssue.allCases, id: \.self) { issue in
                                    IssueChip(
                                        issue: issue,
                                        isSelected: selectedIssues.contains(issue),
                                        onTap: {
                                            if selectedIssues.contains(issue) {
                                                selectedIssues.remove(issue)
                                            } else {
                                                selectedIssues.insert(issue)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                        
                        // Additional Feedback
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Additional details (optional):")
                                .font(.poppins.headline)
                                .fontWeight(.semibold)
                            
                            ZStack(alignment: .topLeading) {
                                TextEditor(text: $feedbackText)
                                    .focused($isTextFieldFocused)
                                    .font(.poppins.body)
                                    .padding(12)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                    .frame(minHeight: 120)
                                
                                if feedbackText.isEmpty && !isTextFieldFocused {
                                    Text("Tell us what specific improvements would help...")
                                        .font(.poppins.body)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 16)
                                        .padding(.top, 20)
                                        .allowsHitTesting(false)
                                }
                            }
                        }
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.secondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        let combinedFeedback = buildCombinedFeedback()
                        onSubmit(combinedFeedback.isEmpty ? nil : combinedFeedback)
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    private func buildCombinedFeedback() -> String {
        var components: [String] = []
        
        if !selectedIssues.isEmpty {
            let issueTexts = selectedIssues.map { $0.description }
            components.append("Issues: " + issueTexts.joined(separator: ", "))
        }
        
        if !feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            components.append("Details: " + feedbackText.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        return components.joined(separator: " | ")
    }
}

// MARK: - Feedback Issues

enum FeedbackIssue: String, CaseIterable {
    case tooLong = "too_long"
    case tooShort = "too_short"
    case missedKeyPoints = "missed_key_points"
    case inaccurate = "inaccurate"
    case wrongTone = "wrong_tone"
    case poorStructure = "poor_structure"
    case irrelevantInfo = "irrelevant_info"
    case confusing = "confusing"
    
    var displayName: String {
        switch self {
        case .tooLong: return "Too long"
        case .tooShort: return "Too short"
        case .missedKeyPoints: return "Missed key points"
        case .inaccurate: return "Inaccurate"
        case .wrongTone: return "Wrong tone"
        case .poorStructure: return "Poor structure"
        case .irrelevantInfo: return "Irrelevant info"
        case .confusing: return "Confusing"
        }
    }
    
    var description: String {
        switch self {
        case .tooLong: return "Summary is too lengthy"
        case .tooShort: return "Summary lacks sufficient detail"
        case .missedKeyPoints: return "Important information was omitted"
        case .inaccurate: return "Contains incorrect information"
        case .wrongTone: return "Tone doesn't match the content"
        case .poorStructure: return "Poor organization or structure"
        case .irrelevantInfo: return "Includes irrelevant information"
        case .confusing: return "Difficult to understand"
        }
    }
}

// MARK: - Issue Chip Component

struct IssueChip: View {
    let issue: FeedbackIssue
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(issue.displayName)
                .font(.poppins.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}