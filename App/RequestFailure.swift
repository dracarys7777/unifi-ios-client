import Foundation
import FirebaseAI

/// Only allowlisted categories leave this formatter. Never display or log
/// backend descriptions: they can contain prompts, URLs, identifiers or tokens.
enum RequestFailure {
    static func message(for error: Error) -> String {
        if let generation = error as? GenerateContentError {
            switch generation {
            case .internalError(let underlying), .promptImageContentError(let underlying):
                return message(for: underlying)
            case .promptBlocked:
                return "Request blocked by the model's content filters. Try rephrasing your message. [PROMPT_BLOCKED]"
            case .responseStoppedEarly:
                return "The model stopped before completing its reply. [RESPONSE_STOPPED]"
            }
        }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            switch ns.code {
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                return "No network connection. Reconnect and retry. [NETWORK]"
            case NSURLErrorTimedOut:
                return "The request timed out. Retry once. [TIMEOUT]"
            case NSURLErrorCancelled:
                return "Request cancelled. [CANCELLED]"
            default:
                return "A network or secure-connection error occurred. [NETWORK]"
            }
        }
        // Inspect in memory, but never return the original payload.
        let description = String(reflecting: error) + " " + ns.localizedDescription
        return message(forDiagnosticText: description)
    }

    static func message(forDiagnosticText text: String) -> String {
        let upper = text.uppercased()
        func contains(_ token: String) -> Bool {
            upper.range(of: "(?<![A-Z0-9_])" + token + "(?![A-Z0-9_])",
                        options: .regularExpression) != nil
        }
        if contains("SERVICE_DISABLED") {
            return "A required Google API is disabled. Check Firebase AI Logic and the Vertex API in the project's API console. [SERVICE_DISABLED]"
        }
        if contains("API_KEY_SERVICE_BLOCKED") || contains("API_KEY_INVALID") {
            return "Google rejected the Firebase API key or its API restrictions. Check the registered app and enabled APIs. [API_KEY_REJECTED]"
        }
        if contains("BILLING_DISABLED") || contains("BILLING_NOT_ENABLED") {
            return "Billing is not enabled for this Google project. [BILLING_DISABLED]"
        }
        if upper.contains("APP CHECK") || upper.contains("APPCHECK") || upper.contains("APP_CHECK") || upper.contains("APP ATTEST") {
            return "App Check verification failed. Check Firebase App Check registration, Apple Team ID, and production App Attest configuration. [APP_CHECK]"
        }
        if contains("UNAUTHENTICATED") {
            return "Google rejected authentication. Sign out and sign back in, then verify Firebase authentication settings. [UNAUTHENTICATED]"
        }
        if contains("PERMISSION_DENIED") {
            return "Google denied access. Check API-key restrictions, App Check, billing, and model permissions. [PERMISSION_DENIED]"
        }
        if contains("NOT_FOUND") {
            return "The model was not found at this location, or this project cannot access it. Verify the exact model ID and region. [NOT_FOUND]"
        }
        if contains("RESOURCE_EXHAUSTED") {
            return "The model's quota or capacity was exceeded. Check Google Cloud quotas and retry later. [RESOURCE_EXHAUSTED]"
        }
        if contains("INVALID_ARGUMENT") {
            return "Google rejected a request setting. Check the model ID, region and supported system instructions. [INVALID_ARGUMENT]"
        }
        if contains("UNAVAILABLE") {
            return "The model service is temporarily unavailable. Retry later. [UNAVAILABLE]"
        }
        return "Request failed without a recognized error category. Check Firebase and Google Cloud diagnostics for this attempt. [UNCLASSIFIED]"
    }
}
