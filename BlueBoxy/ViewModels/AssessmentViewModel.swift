import Foundation
import SwiftUI
import Combine

@MainActor
final class AssessmentViewModel: ObservableObject {
    @Published var currentQuestionIndex = 0
    @Published var responses: [String: AssessmentResponse] = [:]
    @Published var personalityInsight: PersonalityInsight?
    @Published var submissionState: Loadable<AssessmentSavedResponse> = .idle
    @Published var questions: [AssessmentQuestion] = []
    @Published var assessmentFlow: AssessmentFlow = .initial
    @Published var progress: Double = 0.0
    @Published var isLoading = false
    
    private let apiClient: APIClient
    private let cacheManager = CacheManager.shared
    
    // Assessment configuration
    private let assessmentConfig = AssessmentConfiguration()
    
    init(apiClient: APIClient = APIClient.shared) {
        self.apiClient = apiClient
        Task {
            await loadAssessmentQuestions()
        }
    }
    
    // MARK: - Public Methods
    
    func startAssessment() {
        resetAssessment()
        assessmentFlow = .inProgress
        updateProgress()
    }
    
    func selectAnswer(_ response: AssessmentResponse) {
        guard currentQuestionIndex < questions.count else { return }
        let question = questions[currentQuestionIndex]
        responses[question.id] = response
        
        // Check for conditional logic
        if let conditionalLogic = question.conditionalLogic {
            processConditionalLogic(conditionalLogic, response: response)
        }
        
        updateProgress()
    }
    
    func nextQuestion() {
        if currentQuestionIndex < questions.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentQuestionIndex += 1
            }
        } else {
            completeAssessment()
        }
        updateProgress()
    }
    
    func previousQuestion() {
        if currentQuestionIndex > 0 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentQuestionIndex -= 1
            }
        }
        updateProgress()
    }
    
    func skipQuestion() {
        guard currentQuestion?.isOptional == true else { return }
        nextQuestion()
    }
    
    func canProceed() -> Bool {
        guard currentQuestionIndex < questions.count else { return false }
        let question = questions[currentQuestionIndex]
        
        if question.isOptional {
            return true
        }
        
        guard let response = responses[question.id] else { return false }
        
        switch question.type {
        case .multipleChoice, .singleChoice:
            return !response.selectedOptions.isEmpty
        case .scale:
            return response.scaleValue != nil
        case .textInput:
            return !(response.textValue?.isEmpty ?? true)
        case .ranking:
            return response.rankedOptions.count >= question.minimumSelections
        }
    }
    
    func isComplete() -> Bool {
        return assessmentFlow == .completed
    }
    
    var currentQuestion: AssessmentQuestion? {
        guard currentQuestionIndex < questions.count else { return nil }
        return questions[currentQuestionIndex]
    }
    
    var questionsRemaining: Int {
        return max(0, questions.count - currentQuestionIndex - 1)
    }
    
    // MARK: - Private Methods
    
    private func loadAssessmentQuestions() async {
        isLoading = true
        
        // Try to load from cache first
        if let cachedQuestions = await cacheManager.load(
            for: CacheKey.assessmentQuestions,
            type: [AssessmentQuestion].self
        ) {
            questions = cachedQuestions
            isLoading = false
            return
        }
        
        // Load from network
        do {
            let questionsResponse: AssessmentQuestionsResponse = try await apiClient.request(.assessmentQuestions())
            questions = questionsResponse.questions
            
            // Cache for future use
            await cacheManager.save(
                questions,
                for: CacheKey.assessmentQuestions,
                strategy: .hybrid(expiration: 86400) // 24 hours
            )
            
        } catch {
            // Fallback to local questions
            questions = createDefaultQuestions()
        }
        
        isLoading = false
    }
    
    private func createDefaultQuestions() -> [AssessmentQuestion] {
        return [
            AssessmentQuestion(
                id: "communication_style",
                text: "How do you prefer to communicate with your partner during important conversations?",
                subtitle: "Think about times when you need to discuss something meaningful or resolve an issue.",
                type: .singleChoice,
                options: [
                    AssessmentOption(id: "immediate", text: "I like to talk through everything immediately", weight: ["direct": 3, "emotional": 1]),
                    AssessmentOption(id: "process", text: "I need time to process before discussing", weight: ["thoughtful": 3, "independent": 2]),
                    AssessmentOption(id: "written", text: "I prefer to write things out first", weight: ["thoughtful": 2, "practical": 1]),
                    AssessmentOption(id: "actions", text: "I communicate better through actions than words", weight: ["practical": 3, "nurturing": 2])
                ],
                category: "communication",
                priority: .high,
                tags: ["core", "communication"]
            ),
            
            AssessmentQuestion(
                id: "conflict_resolution",
                text: "When you and your partner have a disagreement, what's your typical first response?",
                subtitle: "Consider your natural instinct, not what you think you should do.",
                type: .singleChoice,
                options: [
                    AssessmentOption(id: "address", text: "Address it head-on right away", weight: ["direct": 3, "emotional": 1]),
                    AssessmentOption(id: "cool_down", text: "Take a break to cool down first", weight: ["thoughtful": 2, "independent": 2]),
                    AssessmentOption(id: "understand", text: "Try to understand their perspective first", weight: ["emotional": 3, "nurturing": 2]),
                    AssessmentOption(id: "compromise", text: "Focus on finding a middle ground", weight: ["practical": 3, "social": 1])
                ],
                category: "conflict_resolution",
                priority: .high,
                tags: ["core", "conflict"]
            ),
            
            AssessmentQuestion(
                id: "love_language",
                text: "How do you most naturally show love to your partner?",
                subtitle: "Think about what you do without being asked or prompted.",
                type: .ranking,
                options: [
                    AssessmentOption(id: "words", text: "Words of affirmation and compliments", weight: ["emotional": 2, "social": 1]),
                    AssessmentOption(id: "touch", text: "Physical touch and closeness", weight: ["nurturing": 3, "emotional": 1]),
                    AssessmentOption(id: "acts", text: "Acts of service and helpful gestures", weight: ["practical": 3, "nurturing": 1]),
                    AssessmentOption(id: "time", text: "Quality time and undivided attention", weight: ["thoughtful": 2, "emotional": 2]),
                    AssessmentOption(id: "gifts", text: "Thoughtful gifts and surprises", weight: ["thoughtful": 1, "practical": 1])
                ],
                category: "love_language",
                priority: .high,
                tags: ["core", "love_language"],
                minimumSelections: 2
            ),
            
            AssessmentQuestion(
                id: "stress_response",
                text: "When you're feeling overwhelmed or stressed, what do you need most from your partner?",
                subtitle: "Be honest about what actually helps you, not what sounds right.",
                type: .singleChoice,
                options: [
                    AssessmentOption(id: "listen", text: "Someone to listen and validate my feelings", weight: ["emotional": 3, "nurturing": 1]),
                    AssessmentOption(id: "solve", text: "Practical help solving the problem", weight: ["practical": 3, "direct": 1]),
                    AssessmentOption(id: "space", text: "Space to work through it myself", weight: ["independent": 3, "thoughtful": 1]),
                    AssessmentOption(id: "distract", text: "Distraction and emotional support", weight: ["social": 2, "nurturing": 2])
                ],
                category: "stress_management",
                priority: .high,
                tags: ["support", "stress"]
            ),
            
            AssessmentQuestion(
                id: "ideal_activities",
                text: "What sounds like your ideal way to spend quality time with your partner?",
                subtitle: "Choose what genuinely excites you, not what you think you should want.",
                type: .multipleChoice,
                options: [
                    AssessmentOption(id: "quiet_dinner", text: "A quiet dinner at home with deep conversation", weight: ["thoughtful": 2, "emotional": 1]),
                    AssessmentOption(id: "adventure", text: "An adventure or trying something new together", weight: ["adventurous": 3, "social": 1]),
                    AssessmentOption(id: "social", text: "A social gathering with friends", weight: ["social": 3, "adventurous": 1]),
                    AssessmentOption(id: "project", text: "Working on a project or goal together", weight: ["practical": 3, "thoughtful": 1]),
                    AssessmentOption(id: "nature", text: "Outdoor activities in nature", weight: ["adventurous": 2, "independent": 1]),
                    AssessmentOption(id: "cultural", text: "Museums, theater, or cultural events", weight: ["thoughtful": 2, "social": 1])
                ],
                category: "activities",
                priority: .medium,
                tags: ["preferences", "activities"],
                maximumSelections: 3
            ),
            
            AssessmentQuestion(
                id: "decision_making",
                text: "When making important relationship decisions, you prefer to:",
                subtitle: "Think about big decisions like moving, finances, or major changes.",
                type: .scale,
                category: "decision_style",
                priority: .medium,
                tags: ["decision_making"],
                scaleMin: 1,
                scaleMax: 5,
                scaleLabels: [
                    1: "Decide quickly and adjust as needed",
                    3: "Balance gut feeling with some research",
                    5: "Research thoroughly and analyze all options"
                ]
            ),
            
            AssessmentQuestion(
                id: "social_energy",
                text: "After a long week, your ideal Friday night is:",
                subtitle: "Choose what would actually recharge you the most.",
                type: .singleChoice,
                options: [
                    AssessmentOption(id: "home_quiet", text: "Staying home quietly with just your partner", weight: ["independent": 2, "thoughtful": 1]),
                    AssessmentOption(id: "small_group", text: "Having a few close friends over", weight: ["social": 2, "nurturing": 1]),
                    AssessmentOption(id: "go_out", text: "Going out to dinner or an event", weight: ["social": 3, "adventurous": 1]),
                    AssessmentOption(id: "active", text: "Doing something active or creative together", weight: ["adventurous": 2, "practical": 1])
                ],
                category: "social_preferences",
                priority: .low,
                tags: ["energy", "social"]
            ),
            
            AssessmentQuestion(
                id: "relationship_growth",
                text: "What area of your relationship would you most like to strengthen?",
                subtitle: "This will help us provide targeted insights and recommendations.",
                type: .singleChoice,
                options: [
                    AssessmentOption(id: "communication", text: "Communication and understanding", weight: ["emotional": 2, "thoughtful": 2]),
                    AssessmentOption(id: "intimacy", text: "Physical and emotional intimacy", weight: ["nurturing": 3, "emotional": 1]),
                    AssessmentOption(id: "shared_goals", text: "Working toward shared goals", weight: ["practical": 3, "thoughtful": 1]),
                    AssessmentOption(id: "fun", text: "Having more fun and spontaneity", weight: ["adventurous": 3, "social": 1]),
                    AssessmentOption(id: "support", text: "Supporting each other through challenges", weight: ["nurturing": 2, "practical": 2])
                ],
                category: "relationship_goals",
                priority: .medium,
                tags: ["goals", "improvement"]
            )
        ]
    }
    
    private func processConditionalLogic(_ logic: ConditionalLogic, response: AssessmentResponse) {
        // Implement conditional question logic
        switch logic.type {
        case .skipNext:
            if logic.conditionMet(for: response) {
                currentQuestionIndex += 1
            }
        case .jumpTo(let questionId):
            if logic.conditionMet(for: response),
               let targetIndex = questions.firstIndex(where: { $0.id == questionId }) {
                currentQuestionIndex = targetIndex - 1 // Will be incremented by nextQuestion()
            }
        case .addQuestionId(let questionId):
            if logic.conditionMet(for: response) {
                // This would need to be implemented based on your question lookup logic
                // For now, just log the questionId
                print("Should add question with ID: \(questionId)")
            }
        case .modifyWeight(let trait, let multiplier):
            if logic.conditionMet(for: response) {
                // This would modify the weight for future calculations
                print("Should modify weight for trait \(trait) by \(multiplier)")
            }
        }
    }
    
    private func completeAssessment() {
        withAnimation(.easeInOut(duration: 0.5)) {
            assessmentFlow = .completed
        }
        calculatePersonalityInsight()
    }
    
    private func calculatePersonalityInsight() {
        personalityInsight = PersonalityCalculator.calculateInsight(from: responses)
    }
    
    private func updateProgress() {
        let totalQuestions = Double(questions.count)
        let completedQuestions = Double(responses.count)
        progress = min(completedQuestions / totalQuestions, 1.0)
    }
    
    func submitAssessment() async {
        guard !responses.isEmpty else { return }
        
        if personalityInsight == nil {
            calculatePersonalityInsight()
        }
        
        submissionState = .loading()
        
        do {
            let request = AssessmentSubmissionRequest(
                responses: responses,
                personalityInsight: personalityInsight,
                completionTime: Date(),
                assessmentVersion: assessmentConfig.version
            )
            
            let response: AssessmentSavedResponse = try await apiClient.request(
                Endpoint(
                    path: "/api/assessment/submit",
                    method: .POST,
                    body: request,
                    requiresUser: true
                )
            )
            
            // Cache the results
            await cacheManager.save(
                personalityInsight,
                for: CacheKey.personalityInsight,
                strategy: .hybrid(expiration: 2592000) // 30 days
            )
            
            submissionState = .loaded(response)
            assessmentFlow = .submitted
            
        } catch {
            submissionState = .failed(ErrorMapper.map(error))
        }
    }
    
    func resetAssessment() {
        currentQuestionIndex = 0
        responses.removeAll()
        personalityInsight = nil
        submissionState = .idle
        assessmentFlow = .initial
        progress = 0.0
    }
    
    func saveProgress() async {
        let progressData = AssessmentProgress(
            currentQuestionIndex: currentQuestionIndex,
            responses: responses,
            timestamp: Date()
        )
        
        await cacheManager.save(
            progressData,
            for: CacheKey.assessmentProgress,
            strategy: .hybrid(expiration: 604800) // 7 days
        )
    }
    
    func loadProgress() async -> Bool {
        guard let progress = await cacheManager.load(
            for: CacheKey.assessmentProgress,
            type: AssessmentProgress.self
        ) else { return false }
        
        // Only restore if progress is recent (within 7 days)
        guard Date().timeIntervalSince(progress.timestamp) < 604800 else { return false }
        
        currentQuestionIndex = progress.currentQuestionIndex
        responses = progress.responses
        updateProgress()
        
        return true
    }
}

// MARK: - Supporting Types

enum AssessmentFlow {
    case initial
    case inProgress
    case completed
    case submitted
}

struct AssessmentConfiguration {
    let version = "1.0"
    let maxRetries = 3
    let timeoutInterval: TimeInterval = 30
}

struct AssessmentProgress: Codable {
    let currentQuestionIndex: Int
    let responses: [String: AssessmentResponse]
    let timestamp: Date
}

struct AssessmentSubmissionRequest: Codable {
    let responses: [String: AssessmentResponse]
    let personalityInsight: PersonalityInsight?
    let completionTime: Date
    let assessmentVersion: String
}

struct AssessmentQuestionsResponse: Codable {
    let questions: [AssessmentQuestion]
    let version: String
}

struct AssessmentSavedResponse: Codable {
    let id: String
    let personalityType: String
    let insights: [String]
    let recommendations: [String]
    let completedAt: Date
}

// MARK: - Extensions

extension CacheKey {
    static let assessmentQuestions = "assessment_questions"
    static let assessmentProgress = "assessment_progress"
    static let personalityInsight = "personality_insight"
}

extension Endpoint {
    static func assessmentQuestions() -> Endpoint {
        Endpoint(path: "/api/assessment/questions", method: .GET)
    }
}