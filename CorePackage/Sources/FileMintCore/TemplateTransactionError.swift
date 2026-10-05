import Foundation
public enum TemplateTransactionError: Error, Equatable, LocalizedError {
    case recoveryRequired, staleReview, cleanupPending
    public var errorDescription: String? {
        switch self {
        case .recoveryRequired: TemplateWorkflowText.recoveryNeeded.text(.english)
        case .staleReview: TemplateWorkflowText.staleReview.text(.english)
        case .cleanupPending: TemplateWorkflowText.cleanupPending.text(.english)
        }
    }
}
