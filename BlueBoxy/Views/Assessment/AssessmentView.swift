import SwiftUI

struct AssessmentView: View {
    @StateObject private var viewModel = AssessmentViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingExitConfirmation = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Enhanced progress bar
                AssessmentProgressBar(
                    progress: viewModel.progress,
                    currentQuestion: viewModel.currentQuestionIndex + 1,
                    totalQuestions: viewModel.questions.count
                )
                
                // Main content based on assessment flow
                Group {
                    switch viewModel.assessmentFlow {
                    case .initial:
                        AssessmentWelcomeView(onStart: {
                            viewModel.startAssessment()
                        })
                    case .inProgress:
                        if let currentQuestion = viewModel.currentQuestion {
                            AssessmentQuestionView(
                                question: currentQuestion,
                                questionIndex: viewModel.currentQuestionIndex,
                                totalQuestions: viewModel.questions.count,
                                response: viewModel.responses[currentQuestion.id],
                                onResponseChanged: { response in
                                    viewModel.selectAnswer(response)
                                }
                            )
                        } else {
                            LoadingView(message: "Loading questions...", style: .fullScreen)
                        }
                    case .completed:
                        AssessmentCompletedView(
                            insight: viewModel.personalityInsight,
                            onSubmit: {
                                Task {
                                    await viewModel.submitAssessment()
                                }
                            },
                            isSubmitting: viewModel.submissionState.isLoading
                        )
                    case .submitted:
                        AssessmentSubmittedView(onDone: {
                            dismiss()
                        })
                    }
                }
                
                // Navigation controls
                if viewModel.assessmentFlow == .inProgress {
                    AssessmentNavigationControls(
                        canGoBack: viewModel.currentQuestionIndex > 0,
                        canProceed: viewModel.canProceed(),
                        canSkip: viewModel.currentQuestion?.isOptional == true,
                        questionsRemaining: viewModel.questionsRemaining,
                        onPrevious: { viewModel.previousQuestion() },
                        onNext: { viewModel.nextQuestion() },
                        onSkip: { viewModel.skipQuestion() }
                    )
                }
            }
            .navigationTitle("Personality Assessment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if viewModel.assessmentFlow == .inProgress && !viewModel.responses.isEmpty {
                            showingExitConfirmation = true
                        } else {
                            dismiss()
                        }
                    }
                }
            }
            .alert("Exit Assessment", isPresented: $showingExitConfirmation) {
                Button("Keep Going", role: .cancel) { }
                Button("Save & Exit") {
                    Task {
                        await viewModel.saveProgress()
                        dismiss()
                    }
                }
                Button("Exit Without Saving", role: .destructive) {
                    dismiss()
                }
            } message: {
                Text("You're \(Int(viewModel.progress * 100))% complete. Would you like to save your progress?")
            }
            .alert("Submission Error", isPresented: .constant(viewModel.submissionState.isFailed)) {
                Button("Retry") {
                    Task {
                        await viewModel.submitAssessment()
                    }
                }
                Button("Cancel") { }
            } message: {
                if case .failed(let error) = viewModel.submissionState {
                    Text(error.localizedDescription)
                }
            }
        }
        .task {
            // Try to restore previous progress
            if await viewModel.loadProgress() {
                viewModel.assessmentFlow = .inProgress
            }
        }
    }
}

// MARK: - Progress Bar

struct AssessmentProgressBar: View {
    let progress: Double
    let currentQuestion: Int
    let totalQuestions: Int
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Question \(currentQuestion) of \(totalQuestions)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(Int(progress * 100))% Complete")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
            }
            .padding(.horizontal)
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .scaleEffect(y: 2, anchor: .center)
                .animation(.easeInOut(duration: 0.3), value: progress)
        }
        .padding(.bottom, 8)
    }
}

// MARK: - Welcome View

struct AssessmentWelcomeView: View {
    let onStart: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(.blue.opacity(0.1))
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 50))
                            .foregroundStyle(.blue)
                    }
                    
                    VStack(spacing: 12) {
                        Text("Discover Your Relationship Style")
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text("Get personalized insights to strengthen your connection")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    AssessmentFeatureRow(
                        icon: "heart.fill",
                        title: "Understand Your Love Language",
                        description: "Learn how you best give and receive love"
                    )
                    
                    AssessmentFeatureRow(
                        icon: "bubble.left.and.bubble.right.fill",
                        title: "Communication Insights",
                        description: "Discover your natural communication patterns"
                    )
                    
                    AssessmentFeatureRow(
                        icon: "lightbulb.fill",
                        title: "Personalized Recommendations",
                        description: "Get activities and tips tailored to your style"
                    )
                    
                    AssessmentFeatureRow(
                        icon: "clock.fill",
                        title: "Takes 5-7 Minutes",
                        description: "Quick but comprehensive personality assessment"
                    )
                }
                
                VStack(spacing: 12) {
                    Button("Start Assessment") {
                        onStart()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    
                    Text("Your responses are private and secure")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 24)
        }
    }
}

struct AssessmentFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Question View

struct AssessmentQuestionView: View {
    let question: AssessmentQuestion
    let questionIndex: Int
    let totalQuestions: Int
    let response: AssessmentResponse?
    let onResponseChanged: (AssessmentResponse) -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Question header
                VStack(spacing: 16) {
                    HStack {
                        Text(question.category.capitalized)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(.blue.opacity(0.1))
                            .cornerRadius(12)
                        
                        if question.isOptional {
                            Text("Optional")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(.orange.opacity(0.1))
                                .cornerRadius(12)
                        }
                        
                        Spacer()
                    }
                    
                    VStack(spacing: 12) {
                        Text(question.text)
                            .font(.title3)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                        
                        if let subtitle = question.subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Question input based on type
                Group {
                    switch question.type {
                    case .singleChoice:
                        SingleChoiceQuestion(
                            question: question,
                            selectedOption: response?.selectedOptions.first,
                            onSelectionChanged: { optionId in
                                let newResponse = AssessmentResponse(
                                    questionId: question.id,
                                    selectedOptions: [optionId]
                                )
                                onResponseChanged(newResponse)
                            }
                        )
                    case .multipleChoice:
                        MultipleChoiceQuestion(
                            question: question,
                            selectedOptions: Set(response?.selectedOptions ?? []),
                            onSelectionChanged: { selectedOptions in
                                let newResponse = AssessmentResponse(
                                    questionId: question.id,
                                    selectedOptions: Array(selectedOptions)
                                )
                                onResponseChanged(newResponse)
                            }
                        )
                    case .scale:
                        ScaleQuestion(
                            question: question,
                            selectedValue: response?.scaleValue,
                            onValueChanged: { value in
                                let newResponse = AssessmentResponse(
                                    questionId: question.id,
                                    scaleValue: value
                                )
                                onResponseChanged(newResponse)
                            }
                        )
                    case .ranking:
                        RankingQuestion(
                            question: question,
                            rankedOptions: response?.rankedOptions ?? [],
                            onRankingChanged: { rankedOptions in
                                let newResponse = AssessmentResponse(
                                    questionId: question.id,
                                    rankedOptions: rankedOptions
                                )
                                onResponseChanged(newResponse)
                            }
                        )
                    case .textInput:
                        TextInputQuestion(
                            question: question,
                            textValue: response?.textValue ?? "",
                            onTextChanged: { text in
                                let newResponse = AssessmentResponse(
                                    questionId: question.id,
                                    textValue: text
                                )
                                onResponseChanged(newResponse)
                            }
                        )
                    }
                }
            }
            .padding(.vertical, 24)
        }
    }
}

// MARK: - Question Type Components

struct SingleChoiceQuestion: View {
    let question: AssessmentQuestion
    let selectedOption: String?
    let onSelectionChanged: (String) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(question.options, id: \.id) { option in
                Button {
                    onSelectionChanged(option.id)
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: selectedOption == option.id ? "largecircle.fill.circle" : "circle")
                            .font(.title2)
                            .foregroundStyle(selectedOption == option.id ? .blue : .gray)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.text)
                                .font(.body)
                                .fontWeight(.medium)
                                .multilineTextAlignment(.leading)
                            
                            if let subtitle = option.subtitle {
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.regularMaterial)
                            .stroke(selectedOption == option.id ? .blue : .clear, lineWidth: 2)
                    )
                    .scaleEffect(selectedOption == option.id ? 1.02 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: selectedOption)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal)
    }
}

struct MultipleChoiceQuestion: View {
    let question: AssessmentQuestion
    let selectedOptions: Set<String>
    let onSelectionChanged: (Set<String>) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(question.options, id: \.id) { option in
                Button {
                    var newSelection = selectedOptions
                    if selectedOptions.contains(option.id) {
                        newSelection.remove(option.id)
                    } else {
                        // Check maximum selections
                        if let maxSelections = question.maximumSelections,
                           selectedOptions.count >= maxSelections {
                            return
                        }
                        newSelection.insert(option.id)
                    }
                    onSelectionChanged(newSelection)
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: selectedOptions.contains(option.id) ? "checkmark.square.fill" : "square")
                            .font(.title2)
                            .foregroundStyle(selectedOptions.contains(option.id) ? .blue : .gray)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.text)
                                .font(.body)
                                .fontWeight(.medium)
                                .multilineTextAlignment(.leading)
                            
                            if let subtitle = option.subtitle {
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Material.regularMaterial)
                            .stroke(selectedOptions.contains(option.id) ? .blue : .clear, lineWidth: 2)
                    )
                    .scaleEffect(selectedOptions.contains(option.id) ? 1.02 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: selectedOptions)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Selection guidance
            VStack(spacing: 4) {
                if let maxSelections = question.maximumSelections {
                    Text("Select up to \(maxSelections) options")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if selectedOptions.count > 0 {
                    Text("\(selectedOptions.count) selected")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(.horizontal)
    }
}

struct ScaleQuestion: View {
    let question: AssessmentQuestion
    let selectedValue: Int?
    let onValueChanged: (Int) -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Scale labels if available
            if let scaleLabels = question.scaleLabels {
                VStack(spacing: 16) {
                    ForEach(Array(scaleLabels.keys.sorted()), id: \.self) { key in
                        if let label = scaleLabels[key] {
                            HStack {
                                Text("\(key)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.blue)
                                    .frame(width: 20)
                                
                                Text(label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Spacer()
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            // Scale buttons
            HStack(spacing: 12) {
                let minValue = question.scaleMin ?? 1
                let maxValue = question.scaleMax ?? 5
                
                ForEach(minValue...maxValue, id: \.self) { value in
                    Button {
                        onValueChanged(value)
                    } label: {
                        Text("\(value)")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(selectedValue == value ? .white : .primary)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(selectedValue == value ? .blue : Color.gray.opacity(0.3))
                            )
                            .scaleEffect(selectedValue == value ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: selectedValue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
            
            // Current selection
            if let selectedValue = selectedValue {
                Text("Selected: \(selectedValue)")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
    }
}

struct RankingQuestion: View {
    let question: AssessmentQuestion
    let rankedOptions: [String]
    let onRankingChanged: ([String]) -> Void
    
    @State private var draggedItem: String?
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Drag to reorder by preference")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                ForEach(Array(rankedOptions.enumerated()), id: \.element) { index, optionId in
                    if let option = question.options.first(where: { $0.id == optionId }) {
                        RankingOptionRow(
                            option: option,
                            rank: index + 1,
                            isDragging: draggedItem == optionId
                        )
                        .onDrag {
                            draggedItem = optionId
                            return NSItemProvider(object: optionId as NSString)
                        }
                        .onDrop(of: [.text], delegate: RankingDropDelegate(
                            item: optionId,
                            items: rankedOptions,
                            onReorder: onRankingChanged
                        ))
                    }
                }
                
                // Unranked options
                ForEach(question.options.filter { !rankedOptions.contains($0.id) }, id: \.id) { option in
                    UnrankedOptionRow(option: option)
                        .onTapGesture {
                            onRankingChanged(rankedOptions + [option.id])
                        }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct RankingOptionRow: View {
    let option: AssessmentOption
    let rank: Int
    let isDragging: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(.blue))
            
            Text(option.text)
                .font(.body)
                .fontWeight(.medium)
            
            Spacer()
            
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isDragging ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
        )
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isDragging)
    }
}

struct UnrankedOptionRow: View {
    let option: AssessmentOption
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.quaternary)
                .frame(width: 24, height: 24)
                .overlay(
                    Text("+")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                )
            
            Text(option.text)
                .font(.body)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary.opacity(0.3))
                .stroke(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [5]))
        )
    }
}

struct RankingDropDelegate: DropDelegate {
    let item: String
    let items: [String]
    let onReorder: ([String]) -> Void
    
    func performDrop(info: DropInfo) -> Bool {
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggedItem = info.itemProviders(for: [.text]).first?.suggestedName,
              draggedItem != item,
              let fromIndex = items.firstIndex(of: draggedItem),
              let toIndex = items.firstIndex(of: item) else { return }
        
        var newItems = items
        newItems.move(fromOffsets: IndexSet([fromIndex]), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        onReorder(newItems)
    }
}

struct TextInputQuestion: View {
    let question: AssessmentQuestion
    let textValue: String
    let onTextChanged: (String) -> Void
    
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            TextField("Your answer...", text: Binding(
                get: { textValue },
                set: { onTextChanged($0) }
            ), axis: .vertical)
            .textFieldStyle(AuthTextFieldStyle(isFocused: isTextFieldFocused, validationState: .valid))
            .lineLimit(3...8)
            .focused($isTextFieldFocused)
            .padding(.horizontal)
            
            if !textValue.isEmpty {
                Text("\(textValue.count) characters")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
    }
}

// MARK: - Navigation Controls

struct AssessmentNavigationControls: View {
    let canGoBack: Bool
    let canProceed: Bool
    let canSkip: Bool
    let questionsRemaining: Int
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            if questionsRemaining > 0 {
                HStack {
                    Text("\(questionsRemaining) question\(questionsRemaining == 1 ? "" : "s") remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    if canSkip {
                        Button("Skip") {
                            onSkip()
                        }
                        .font(.caption)
                        .foregroundStyle(.orange)
                    }
                }
                .padding(.horizontal)
            }
            
            HStack(spacing: 16) {
                if canGoBack {
                    Button("Previous") {
                        onPrevious()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(maxWidth: .infinity)
                }
                
                Button(questionsRemaining > 0 ? "Next" : "Complete") {
                    onNext()
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: .infinity)
                .disabled(!canProceed)
            }
            .padding()
        }
    }
}

// MARK: - Completion Views

struct AssessmentCompletedView: View {
    let insight: PersonalityInsight?
    let onSubmit: () -> Void
    let isSubmitting: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.green)
                    
                    Text("Assessment Complete!")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let insight = insight {
                        VStack(spacing: 12) {
                            Text("Your Relationship Style")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            Text(insight.loveLanguage)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .padding()
                                .background(.blue.opacity(0.1))
                                .foregroundStyle(.blue)
                                .cornerRadius(12)
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("What happens next?")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        NextStepRow(number: 1, text: "Save your personality profile")
                        NextStepRow(number: 2, text: "Get personalized activity recommendations")
                        NextStepRow(number: 3, text: "Receive tailored relationship insights")
                        NextStepRow(number: 4, text: "Unlock AI-powered suggestions")
                    }
                }
                .padding()
                .background(.blue.opacity(0.05))
                .cornerRadius(16)
                
                Button("Save Results") {
                    onSubmit()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isSubmitting)
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 24)
        }
    }
}

struct NextStepRow: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(.blue))
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct AssessmentSubmittedView: View {
    let onDone: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 20) {
                Image(systemName: "sparkles")
                    .font(.system(size: 80))
                    .foregroundStyle(.yellow)
                
                Text("All Set!")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Your personality profile has been saved. You'll now receive personalized recommendations!")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Continue") {
                onDone()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
    }
}

#Preview {
    AssessmentView()
}