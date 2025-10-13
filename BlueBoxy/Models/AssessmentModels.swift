import Foundation
import SwiftUI

// MARK: - Assessment Question

struct AssessmentQuestion: Codable, Identifiable, Hashable {
    let id: String
    let text: String
    let subtitle: String?
    let type: QuestionType
    let options: [AssessmentOption]
    let category: String
    let priority: Priority
    let tags: [String]
    let isOptional: Bool
    let minimumSelections: Int
    let maximumSelections: Int?
    let scaleMin: Int?
    let scaleMax: Int?
    let scaleLabels: [Int: String]?
    let conditionalLogic: ConditionalLogic?
    let validationRules: [ValidationRule]?
    
    init(
        id: String,
        text: String,
        subtitle: String? = nil,
        type: QuestionType,
        options: [AssessmentOption] = [],
        category: String,
        priority: Priority = .medium,
        tags: [String] = [],
        isOptional: Bool = false,
        minimumSelections: Int = 1,
        maximumSelections: Int? = nil,
        scaleMin: Int? = nil,
        scaleMax: Int? = nil,
        scaleLabels: [Int: String]? = nil,
        conditionalLogic: ConditionalLogic? = nil,
        validationRules: [ValidationRule]? = nil
    ) {
        self.id = id
        self.text = text
        self.subtitle = subtitle
        self.type = type
        self.options = options
        self.category = category
        self.priority = priority
        self.tags = tags
        self.isOptional = isOptional
        self.minimumSelections = minimumSelections
        self.maximumSelections = maximumSelections
        self.scaleMin = scaleMin
        self.scaleMax = scaleMax
        self.scaleLabels = scaleLabels
        self.conditionalLogic = conditionalLogic
        self.validationRules = validationRules
    }
    
    enum QuestionType: String, Codable, CaseIterable {
        case singleChoice = "single_choice"
        case multipleChoice = "multiple_choice"
        case scale = "scale"
        case ranking = "ranking"
        case textInput = "text_input"
        
        var displayName: String {
            switch self {
            case .singleChoice: return "Choose One"
            case .multipleChoice: return "Choose Multiple"
            case .scale: return "Rate on Scale"
            case .ranking: return "Rank Options"
            case .textInput: return "Open Response"
            }
        }
        
        var icon: String {
            switch self {
            case .singleChoice: return "circle"
            case .multipleChoice: return "checkmark.square"
            case .scale: return "slider.horizontal.3"
            case .ranking: return "list.number"
            case .textInput: return "text.cursor"
            }
        }
    }
    
    enum Priority: String, Codable, CaseIterable {
        case high, medium, low
        
        var sortOrder: Int {
            switch self {
            case .high: return 0
            case .medium: return 1
            case .low: return 2
            }
        }
    }
}

// MARK: - Assessment Option

struct AssessmentOption: Codable, Identifiable, Hashable {
    let id: String
    let text: String
    let subtitle: String?
    let weight: [String: Int] // Personality trait weights
    let icon: String?
    let isExclusive: Bool // If selected, deselects other options
    let followUpQuestionIds: [String]? // Changed from [AssessmentQuestion] to avoid recursion
    
    init(
        id: String,
        text: String,
        subtitle: String? = nil,
        weight: [String: Int] = [:],
        icon: String? = nil,
        isExclusive: Bool = false,
        followUpQuestionIds: [String]? = nil
    ) {
        self.id = id
        self.text = text
        self.subtitle = subtitle
        self.weight = weight
        self.icon = icon
        self.isExclusive = isExclusive
        self.followUpQuestionIds = followUpQuestionIds
    }
}

// MARK: - Assessment Response

struct AssessmentResponse: Codable, Hashable {
    let questionId: String
    let selectedOptions: [String] // Option IDs
    let rankedOptions: [String] // For ranking questions
    let scaleValue: Int? // For scale questions
    let textValue: String? // For text input
    let timestamp: Date
    let confidence: Double? // How confident the user is in their answer
    
    init(
        questionId: String,
        selectedOptions: [String] = [],
        rankedOptions: [String] = [],
        scaleValue: Int? = nil,
        textValue: String? = nil,
        confidence: Double? = nil
    ) {
        self.questionId = questionId
        self.selectedOptions = selectedOptions
        self.rankedOptions = rankedOptions
        self.scaleValue = scaleValue
        self.textValue = textValue
        self.timestamp = Date()
        self.confidence = confidence
    }
}

// MARK: - Conditional Logic

struct ConditionalLogic: Codable, Hashable {
    let type: LogicType
    let condition: Condition
    
    indirect enum LogicType: Codable, Hashable {
        case skipNext
        case jumpTo(questionId: String)
        case addQuestionId(String) // Changed from addQuestion(AssessmentQuestion) to avoid recursion
        case modifyWeight(trait: String, multiplier: Double)
    }
    
    struct Condition: Codable, Hashable {
        let field: String // "selectedOptions", "scaleValue", etc.
        let comparisonOperator: ComparisonOperator
        let value: ConditionValue
    }
    
    enum ComparisonOperator: String, Codable {
        case equals = "=="
        case notEquals = "!="
        case contains = "contains"
        case greaterThan = ">"
        case lessThan = "<"
        case greaterThanOrEqual = ">="
        case lessThanOrEqual = "<="
    }
    
    enum ConditionValue: Codable, Hashable {
        case string(String)
        case int(Int)
        case array([String])
        case bool(Bool)
    }
    
    func conditionMet(for response: AssessmentResponse) -> Bool {
        switch (condition.field, condition.comparisonOperator, condition.value) {
        case ("selectedOptions", .contains, .string(let value)):
            return response.selectedOptions.contains(value)
        case ("selectedOptions", .equals, .array(let values)):
            return response.selectedOptions == values
        case ("scaleValue", .equals, .int(let value)):
            return response.scaleValue == value
        case ("scaleValue", .greaterThan, .int(let value)):
            return (response.scaleValue ?? 0) > value
        case ("scaleValue", .lessThan, .int(let value)):
            return (response.scaleValue ?? 0) < value
        default:
            return false
        }
    }
}

// MARK: - Validation Rules

struct ValidationRule: Codable, Hashable {
    let type: ValidationType
    let parameter: ValidationParameter?
    let errorMessage: String
    
    enum ValidationType: String, Codable {
        case required
        case minLength
        case maxLength
        case minSelections
        case maxSelections
        case pattern // For regex validation
    }
    
    enum ValidationParameter: Codable, Hashable {
        case int(Int)
        case string(String)
    }
    
    func isValid(for response: AssessmentResponse) -> Bool {
        switch type {
        case .required:
            return !response.selectedOptions.isEmpty || 
                   response.scaleValue != nil || 
                   !(response.textValue?.isEmpty ?? true)
        case .minSelections:
            if case .int(let min) = parameter {
                return response.selectedOptions.count >= min
            }
            return true
        case .maxSelections:
            if case .int(let max) = parameter {
                return response.selectedOptions.count <= max
            }
            return true
        case .minLength:
            if case .int(let min) = parameter {
                return (response.textValue?.count ?? 0) >= min
            }
            return true
        case .maxLength:
            if case .int(let max) = parameter {
                return (response.textValue?.count ?? 0) <= max
            }
            return true
        case .pattern:
            // Regex validation would be implemented here
            return true
        }
    }
}

// MARK: - Enhanced Personality Calculator

struct PersonalityCalculator {
    static func calculateInsight(from responses: [String: AssessmentResponse]) -> PersonalityInsight {
        var traitScores: [String: Double] = [
            "thoughtful": 0,
            "practical": 0,
            "emotional": 0,
            "independent": 0,
            "social": 0,
            "adventurous": 0,
            "nurturing": 0,
            "direct": 0
        ]
        
        // Calculate base scores from responses
        for (_, response) in responses {
            // This would be more sophisticated in a real implementation
            // incorporating the option weights and question priorities
            
            for optionId in response.selectedOptions {
                // Look up the option and apply its weights
                // This is simplified - in reality, you'd need to match
                // the option ID back to its weight values
                
                if let scaleValue = response.scaleValue {
                    // Apply scale-based scoring
                    if scaleValue <= 2 {
                        traitScores["adventurous", default: 0] += 2
                        traitScores["direct", default: 0] += 1
                    } else if scaleValue >= 4 {
                        traitScores["thoughtful", default: 0] += 2
                        traitScores["practical", default: 0] += 1
                    }
                }
            }
        }
        
        // Normalize scores
        let totalScore = traitScores.values.reduce(0, +)
        if totalScore > 0 {
            for key in traitScores.keys {
                traitScores[key] = (traitScores[key, default: 0] / totalScore) * 100
            }
        }
        
        // Determine primary and secondary traits
        let sortedTraits = traitScores.sorted { $0.value > $1.value }
        let primaryTrait = sortedTraits.first?.key ?? "thoughtful"
        let secondaryTrait = sortedTraits.count > 1 ? sortedTraits[1].key : nil
        
        // Generate personality type and insights
        let personalityType = generatePersonalityType(primary: primaryTrait, secondary: secondaryTrait)
        let insights = generateInsights(for: primaryTrait, secondary: secondaryTrait, scores: traitScores)
        
        return PersonalityInsight(
            description: insights.joined(separator: " "),
            loveLanguage: determineLoveLanguage(from: responses),
            communicationStyle: determineCommunicationStyle(from: responses),
            idealActivities: generateIdealActivities(from: responses, traits: traitScores),
            stressResponse: determineStressResponse(from: responses)
        )
    }
    
    private static func generatePersonalityType(primary: String, secondary: String?) -> String {
        let combinations: [String: [String: String]] = [
            "thoughtful": [
                "emotional": "Empathetic Analyzer",
                "practical": "Strategic Harmonizer",
                "nurturing": "Caring Contemplator",
                "social": "Reflective Connector",
                "default": "Thoughtful Harmonizer"
            ],
            "practical": [
                "nurturing": "Supportive Helper",
                "thoughtful": "Strategic Planner",
                "direct": "Results-Oriented Partner",
                "default": "Practical Supporter"
            ],
            "emotional": [
                "nurturing": "Heart-Centered Caregiver",
                "social": "Expressive Communicator",
                "thoughtful": "Sensitive Listener",
                "default": "Emotional Connector"
            ],
            "adventurous": [
                "social": "Social Explorer",
                "independent": "Free-Spirited Adventurer",
                "practical": "Action-Oriented Partner",
                "default": "Adventure Seeker"
            ],
            "nurturing": [
                "emotional": "Compassionate Supporter",
                "practical": "Caring Helper",
                "thoughtful": "Gentle Guide",
                "default": "Nurturing Caregiver"
            ],
            "social": [
                "adventurous": "Outgoing Explorer",
                "emotional": "Warm Connector",
                "nurturing": "Social Caregiver",
                "default": "Social Butterfly"
            ],
            "independent": [
                "thoughtful": "Self-Reliant Thinker",
                "practical": "Autonomous Achiever",
                "adventurous": "Independent Explorer",
                "default": "Independent Thinker"
            ],
            "direct": [
                "practical": "Straightforward Problem-Solver",
                "emotional": "Honest Communicator",
                "nurturing": "Direct Caregiver",
                "default": "Direct Communicator"
            ]
        ]
        
        if let secondary = secondary,
           let primaryCombinations = combinations[primary],
           let combinedType = primaryCombinations[secondary] {
            return combinedType
        }
        
        return combinations[primary]?["default"] ?? "Unique Individual"
    }
    
    private static func generateInsights(for primary: String, secondary: String?, scores: [String: Double]) -> [String] {
        var insights: [String] = []
        
        let primaryScore = scores[primary, default: 0]
        
        // Primary trait insight
        switch primary {
        case "thoughtful":
            insights.append("You are someone who values deep reflection and meaningful connections.")
        case "practical":
            insights.append("You approach relationships with a focus on tangible actions and helpful solutions.")
        case "emotional":
            insights.append("You lead with your heart and prioritize emotional connection and understanding.")
        case "nurturing":
            insights.append("You naturally care for others and find fulfillment in supporting your partner.")
        case "social":
            insights.append("You thrive on social connections and enjoy sharing experiences with others.")
        case "adventurous":
            insights.append("You bring energy and excitement to your relationships through new experiences.")
        case "independent":
            insights.append("You value personal space and autonomy while maintaining deep connections.")
        case "direct":
            insights.append("You communicate clearly and honestly, preferring straightforward interactions.")
        default:
            insights.append("You have a unique combination of relationship strengths.")
        }
        
        // Secondary trait insight
        if let secondary = secondary, scores[secondary, default: 0] > 15 {
            switch secondary {
            case "thoughtful":
                insights.append("You also bring thoughtful consideration to your relationship decisions.")
            case "practical":
                insights.append("You balance this with a practical approach to solving problems together.")
            case "emotional":
                insights.append("You combine this with strong emotional awareness and empathy.")
            case "nurturing":
                insights.append("You also have a caring, supportive nature that strengthens your bond.")
            case "social":
                insights.append("You enjoy connecting with others and building a wider social circle.")
            case "adventurous":
                insights.append("You like to keep things interesting with new experiences and spontaneity.")
            case "independent":
                insights.append("You maintain your sense of self while being deeply connected to your partner.")
            case "direct":
                insights.append("You communicate with honesty and clarity in your relationship.")
            default:
                break
            }
        }
        
        return insights
    }
    
    private static func determineLoveLanguage(from responses: [String: AssessmentResponse]) -> String {
        // Analyze love language question specifically
        if let loveResponse = responses["love_language"] {
            let options = loveResponse.rankedOptions.isEmpty ? loveResponse.selectedOptions : loveResponse.rankedOptions
            if let primary = options.first {
                switch primary {
                case "words": return "Words of Affirmation"
                case "touch": return "Physical Touch"
                case "acts": return "Acts of Service"
                case "time": return "Quality Time"
                case "gifts": return "Receiving Gifts"
                default: return "Quality Time"
                }
            }
        }
        return "Quality Time" // Default
    }
    
    private static func generateLoveLanguageDescription(from responses: [String: AssessmentResponse]) -> String {
        let loveLanguage = determineLoveLanguage(from: responses)
        
        switch loveLanguage {
        case "Words of Affirmation":
            return "You feel most loved when your partner expresses appreciation and affection through spoken and written words. Compliments, encouragement, and verbal recognition mean the world to you."
        case "Physical Touch":
            return "Physical closeness and touch are essential for you to feel connected and loved. Hand-holding, hugs, and other forms of appropriate physical affection help you feel secure in your relationship."
        case "Acts of Service":
            return "You feel most appreciated when your partner does helpful things for you. Actions speak louder than words, and you value when your partner lightens your load or takes care of tasks."
        case "Quality Time":
            return "You feel most connected when you have your partner's undivided attention. Meaningful conversations and shared activities without distractions are what make you feel truly valued."
        case "Receiving Gifts":
            return "Thoughtful gifts and gestures show you that your partner was thinking about you. It's not about the cost, but the thought and effort that went into choosing something special for you."
        default:
            return "You appreciate multiple ways of expressing and receiving love, which makes you adaptable in relationships."
        }
    }
    
    private static func determineCommunicationStyle(from responses: [String: AssessmentResponse]) -> String {
        if let commResponse = responses["communication_style"] {
            if let primary = commResponse.selectedOptions.first {
                switch primary {
                case "immediate": return "Direct and Immediate"
                case "process": return "Thoughtful and Reflective"
                case "written": return "Analytical and Structured"
                case "actions": return "Action-Oriented"
                default: return "Balanced Communicator"
                }
            }
        }
        return "Balanced Communicator"
    }
    
    private static func generateCommunicationAnalysis(from responses: [String: AssessmentResponse]) -> String {
        let style = determineCommunicationStyle(from: responses)
        
        switch style {
        case "Direct and Immediate":
            return "You prefer to address issues head-on and value immediate, honest communication. You work best with partners who can engage in real-time discussions and appreciate your straightforward approach."
        case "Thoughtful and Reflective":
            return "You need time to process your thoughts and feelings before engaging in important conversations. You communicate best when given space to reflect and organize your thoughts first."
        case "Analytical and Structured":
            return "You prefer to organize your thoughts in writing or through structured approaches before verbal communication. You excel at clear, well-thought-out discussions."
        case "Action-Oriented":
            return "You often express yourself better through actions than words. You prefer to show rather than tell, and you appreciate when partners recognize your non-verbal communication."
        default:
            return "You adapt your communication style based on the situation and your partner's needs, showing flexibility in how you express yourself."
        }
    }
    
    private static func determineStressResponse(from responses: [String: AssessmentResponse]) -> String {
        if let stressResponse = responses["stress_response"] {
            if let primary = stressResponse.selectedOptions.first {
                switch primary {
                case "listen": return "Seek Emotional Support"
                case "solve": return "Focus on Problem-Solving"
                case "space": return "Need Independent Processing"
                case "distract": return "Seek Comfort and Distraction"
                default: return "Balanced Stress Response"
                }
            }
        }
        return "Balanced Stress Response"
    }
    
    private static func generateStressAnalysis(from responses: [String: AssessmentResponse]) -> String {
        let response = determineStressResponse(from: responses)
        
        switch response {
        case "Seek Emotional Support":
            return "When stressed, you benefit most from having someone listen without judgment and validate your feelings. You process stress through emotional connection and understanding."
        case "Focus on Problem-Solving":
            return "You prefer to tackle stress head-on by identifying solutions and taking action. You work best with partners who can help brainstorm solutions or take practical steps to resolve issues."
        case "Need Independent Processing":
            return "You handle stress best when given space to work through challenges on your own initially. You value partners who respect your need for independence during difficult times."
        case "Seek Comfort and Distraction":
            return "You cope with stress through emotional support and activities that help you step back from the problem. You appreciate partners who can provide comfort and help shift your focus when needed."
        default:
            return "You have a flexible approach to managing stress, adapting your needs based on the situation and drawing on multiple coping strategies."
        }
    }
    
    private static func determineConflictResolution(from responses: [String: AssessmentResponse]) -> String {
        if let conflictResponse = responses["conflict_resolution"] {
            if let primary = conflictResponse.selectedOptions.first {
                switch primary {
                case "address": return "Direct Confrontation"
                case "cool_down": return "Reflective Approach"
                case "understand": return "Empathetic Resolution"
                case "compromise": return "Collaborative Problem-Solving"
                default: return "Balanced Approach"
                }
            }
        }
        return "Balanced Approach"
    }
    
    private static func generateIdealActivities(from responses: [String: AssessmentResponse], traits: [String: Double]) -> [String] {
        var activities: [String] = []
        
        // Base activities on dominant traits
        let sortedTraits = traits.sorted { $0.value > $1.value }
        
        for (trait, score) in sortedTraits.prefix(3) where score > 10 {
            switch trait {
            case "thoughtful":
                activities.append("Deep conversation over dinner")
                activities.append("Museum or art gallery visits")
                activities.append("Reading together")
            case "practical":
                activities.append("Working on home projects together")
                activities.append("Planning future goals")
                activities.append("Learning new skills")
            case "emotional":
                activities.append("Romantic dates with personal touches")
                activities.append("Sharing feelings and dreams")
                activities.append("Creating meaningful traditions")
            case "adventurous":
                activities.append("Trying new restaurants or activities")
                activities.append("Outdoor adventures")
                activities.append("Spontaneous day trips")
            case "social":
                activities.append("Hosting friends for dinner")
                activities.append("Going to social events together")
                activities.append("Double dates with other couples")
            case "nurturing":
                activities.append("Cooking meals together")
                activities.append("Caring for pets or plants together")
                activities.append("Volunteering as a couple")
            case "independent":
                activities.append("Parallel activities in the same space")
                activities.append("Supporting each other's individual hobbies")
                activities.append("Taking turns choosing activities")
            default:
                break
            }
        }
        
        // Also consider specific activity preferences from responses
        if let activityResponse = responses["ideal_activities"] {
            for optionId in activityResponse.selectedOptions {
                switch optionId {
                case "quiet_dinner":
                    activities.append("Intimate dinner conversations")
                case "adventure":
                    activities.append("Adventure sports or exploration")
                case "social":
                    activities.append("Group gatherings and parties")
                case "project":
                    activities.append("Collaborative projects and goals")
                case "nature":
                    activities.append("Hiking and outdoor activities")
                case "cultural":
                    activities.append("Cultural events and learning experiences")
                default:
                    break
                }
            }
        }
        
        return Array(Set(activities)).prefix(8).map { $0 }
    }
    
    private static func generateCompatibilityTips(for primary: String, secondary: String?) -> [String] {
        var tips: [String] = []
        
        switch primary {
        case "thoughtful":
            tips.append("Give your partner time to process important decisions")
            tips.append("Engage in meaningful conversations regularly")
            tips.append("Respect their need for reflection before discussing serious topics")
        case "practical":
            tips.append("Show appreciation through helpful actions")
            tips.append("Focus on solving problems together rather than just discussing them")
            tips.append("Appreciate their efforts to make your life easier")
        case "emotional":
            tips.append("Prioritize emotional check-ins and validation")
            tips.append("Be patient with their need to process feelings")
            tips.append("Express your own emotions openly and honestly")
        case "nurturing":
            tips.append("Allow them to care for you and appreciate their efforts")
            tips.append("Show gratitude for the support they provide")
            tips.append("Take turns being the caregiver in the relationship")
        case "social":
            tips.append("Include friends and social activities in your relationship")
            tips.append("Understand their need for social connection")
            tips.append("Join them in social activities even if you're more introverted")
        case "adventurous":
            tips.append("Be open to trying new experiences together")
            tips.append("Plan surprises and spontaneous activities")
            tips.append("Support their need for variety and excitement")
        case "independent":
            tips.append("Respect their need for personal space and time")
            tips.append("Maintain your own interests and friendships")
            tips.append("Support each other's individual goals")
        case "direct":
            tips.append("Communicate clearly and honestly")
            tips.append("Address issues directly rather than avoiding them")
            tips.append("Appreciate their straightforward communication style")
        default:
            tips.append("Focus on understanding each other's unique communication style")
        }
        
        return tips
    }
    
    private static func generateGrowthAreas(from traitScores: [String: Double]) -> [String] {
        var growthAreas: [String] = []
        
        // Identify areas where scores are lower, suggesting potential growth opportunities
        let sortedTraits = traitScores.sorted { $0.value < $1.value }
        
        for (trait, score) in sortedTraits.prefix(2) where score < 15 {
            switch trait {
            case "emotional":
                growthAreas.append("Practice expressing emotions more openly")
            case "practical":
                growthAreas.append("Focus on taking concrete actions to support your partner")
            case "social":
                growthAreas.append("Engage more in social activities together")
            case "thoughtful":
                growthAreas.append("Take more time to reflect before making decisions")
            case "nurturing":
                growthAreas.append("Show care through small, consistent gestures")
            case "adventurous":
                growthAreas.append("Be more open to new experiences and spontaneity")
            case "independent":
                growthAreas.append("Balance togetherness with personal space")
            case "direct":
                growthAreas.append("Practice more straightforward communication")
            default:
                break
            }
        }
        
        return growthAreas
    }
    
    private static func generateRelationshipAdvice(for primaryTrait: String) -> String {
        switch primaryTrait {
        case "thoughtful":
            return "Focus on creating regular opportunities for deep, meaningful conversations. Your partner will appreciate your thoughtful approach to the relationship, so don't hesitate to share your reflections and insights about your connection."
        case "practical":
            return "Continue showing love through actions and helpful gestures. Your partner likely appreciates how you make their life easier, so keep finding practical ways to support them while also expressing your feelings verbally."
        case "emotional":
            return "Your emotional intelligence is a strength in your relationship. Continue to create safe spaces for emotional expression and help your partner feel comfortable sharing their deeper feelings with you."
        case "nurturing":
            return "Your caring nature is a gift to your relationship. Remember to also let your partner care for you sometimes, as this creates a healthy balance and allows them to feel needed and appreciated too."
        case "social":
            return "Use your social strengths to build a supportive community around your relationship. Include your partner in social activities and help them connect with others, while also ensuring you have quality one-on-one time together."
        case "adventurous":
            return "Keep bringing excitement and new experiences to your relationship. Your enthusiasm for trying new things can help prevent staleness, but also appreciate quiet moments together and your partner's need for stability."
        case "independent":
            return "Your self-reliance is healthy, but remember that interdependence strengthens relationships. Practice sharing your inner world with your partner and allow yourself to rely on them sometimes."
        case "direct":
            return "Your honest communication style is valuable, but remember to temper directness with kindness. Continue being straightforward about your needs while also being sensitive to how your partner receives information."
        default:
            return "Focus on leveraging your unique combination of strengths while remaining open to growing in areas that might not come as naturally to you."
        }
    }
    
    private static func calculateConfidenceScore(from responses: [String: AssessmentResponse]) -> Double {
        let confidenceScores = responses.values.compactMap { $0.confidence }
        guard !confidenceScores.isEmpty else { return 0.75 } // Default moderate confidence
        
        return confidenceScores.reduce(0, +) / Double(confidenceScores.count)
    }
}