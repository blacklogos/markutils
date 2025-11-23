import Foundation

class AIService {
    static let shared = AIService()
    
    private init() {}
    
    enum SlideTemplate: String, CaseIterable {
        case consulting = "Consulting"
        case sales = "Sales"
        case marketing = "Marketing"
    }
    
    func generateSlideDeck(from text: String, template: SlideTemplate) async throws -> String {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_500_000_000)
        
        let title = text.components(separatedBy: .newlines).first ?? "Presentation"
        
        var content = ""
        switch template {
        case .consulting:
            content = """
            # Slide 1: Executive Summary
            - **Situation**: \(title)
            - **Complication**: Current approach lacks scalability.
            - **Resolution**: Implement proposed solution.
            
            # Slide 2: Key Findings
            - Finding 1: Efficiency up by 20%
            - Finding 2: Cost reduction potential
            - Finding 3: Market alignment
            
            # Slide 3: Recommendation
            - Strategic Pivot
            - Timeline: Q3-Q4
            """
        case .sales:
            content = """
            # Slide 1: The Problem
            - You are facing: \(title)
            - It's costing you time and money.
            
            # Slide 2: Our Solution
            - Seamless integration
            - 10x ROI
            - Trusted by industry leaders
            
            # Slide 3: Next Steps
            - Pilot program
            - Onboarding next week
            """
        case .marketing:
            content = """
            # Slide 1: Campaign Vision
            - **Theme**: \(title)
            - **Goal**: Maximize engagement.
            
            # Slide 2: Target Audience
            - Gen Z & Millennials
            - Tech-savvy professionals
            
            # Slide 3: Channels
            - Social Media (Instagram, LinkedIn)
            - Email Newsletter
            - Influencer Partnerships
            """
        }
        
        return """
        \(content)
        
        (Generated with \(template.rawValue) Template ✨)
        """
    }
    
    // Legacy methods (kept for compatibility if needed, or can be removed)
    func summarize(_ text: String) async throws -> String {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        let lines = text.components(separatedBy: .newlines)
        let bulletPoints = lines.prefix(3).map { "- \($0)" }.joined(separator: "\n")
        
        return """
        **Summary:**
        \(bulletPoints)
        
        (AI Generated)
        """
    }
    
    func fixGrammar(_ text: String) async throws -> String {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        return text + "\n\n(Grammar fixed by AI ✨)"
    }
    
    func makeProfessional(_ text: String) async throws -> String {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        return "Dear Team,\n\n" + text + "\n\nBest regards,\n[Your Name]"
    }
}
