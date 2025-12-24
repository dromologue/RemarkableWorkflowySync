import Foundation
import Alamofire
import SwiftyJSON
import Crypto

final class RemarkableService: ObservableObject, @unchecked Sendable {
    private let deviceToken: String
    private var userToken: String?
    private let baseURL = "https://document-storage-production-dot-remarkable-production.appspot.com"
    
    init(deviceToken: String) {
        self.deviceToken = deviceToken
    }
    
    func authenticate() async throws {
        let authURL = "https://webapp-production-dot-remarkable-production.appspot.com/token/json/2/user/new"
        
        let parameters: [String: Any] = [
            "deviceDesc": "desktop-macos",
            "deviceID": generateDeviceID()
        ]
        
        let response = try await AF.request(
            authURL,
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: ["Authorization": "Bearer \(deviceToken)"]
        ).serializingData().value
        
        let json = try JSON(data: response)
        
        guard let token = json["token"].string else {
            throw RemarkableError.authenticationFailed
        }
        
        self.userToken = token
    }
    
    func fetchDocuments() async throws -> [RemarkableDocument] {
        guard let userToken = userToken else {
            try await authenticate()
            return try await fetchDocuments()
        }
        
        let documentsURL = "\(baseURL)/document-storage/json/2/docs"
        
        let response = try await AF.request(
            documentsURL,
            method: .get,
            headers: ["Authorization": "Bearer \(userToken)"]
        ).serializingData().value
        
        let json = try JSON(data: response)
        
        var documents: [RemarkableDocument] = []
        
        for (_, item) in json {
            if let document = parseDocument(from: item) {
                documents.append(document)
            }
        }
        
        return documents.sorted { $0.lastModified > $1.lastModified }
    }
    
    func downloadDocument(id: String) async throws -> Data {
        guard let userToken = userToken else {
            try await authenticate()
            return try await downloadDocument(id: id)
        }
        
        let downloadURL = "\(baseURL)/document-storage/json/2/docs/\(id)/download"
        
        let response = try await AF.request(
            downloadURL,
            method: .get,
            headers: ["Authorization": "Bearer \(userToken)"]
        ).serializingData().value
        
        return response
    }
    
    func getDocumentMetadata(id: String) async throws -> JSON {
        guard let userToken = userToken else {
            try await authenticate()
            return try await getDocumentMetadata(id: id)
        }
        
        let metadataURL = "\(baseURL)/document-storage/json/2/docs/\(id)"
        
        let response = try await AF.request(
            metadataURL,
            method: .get,
            headers: ["Authorization": "Bearer \(userToken)"]
        ).serializingData().value
        
        return try JSON(data: response)
    }
    
    private func parseDocument(from json: JSON) -> RemarkableDocument? {
        guard let id = json["ID"].string,
              let name = json["VissibleName"].string,
              let type = json["Type"].string,
              let modifiedClient = json["ModifiedClient"].string else {
            return nil
        }
        
        let formatter = ISO8601DateFormatter()
        let lastModified = formatter.date(from: modifiedClient) ?? Date()
        
        let size = json["SizeBytes"].intValue
        let parentId = json["Parent"].string
        
        return RemarkableDocument(
            id: id,
            name: name,
            type: type,
            lastModified: lastModified,
            size: size,
            parentId: (parentId?.isEmpty == false) ? parentId : nil
        )
    }
    
    private func generateDeviceID() -> String {
        let uuid = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        return String(uuid.prefix(32))
    }
}

enum RemarkableError: Error, LocalizedError {
    case authenticationFailed
    case invalidResponse
    case documentNotFound
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "Failed to authenticate with Remarkable service"
        case .invalidResponse:
            return "Received invalid response from Remarkable service"
        case .documentNotFound:
            return "Document not found"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}