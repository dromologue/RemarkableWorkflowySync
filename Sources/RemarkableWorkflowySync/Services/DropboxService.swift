import Foundation
import Alamofire
import SwiftyJSON

final class DropboxService: @unchecked Sendable {
    private let accessToken: String
    private let baseURL = "https://api.dropboxapi.com/2"
    private let contentURL = "https://content.dropboxapi.com/2"
    
    init(accessToken: String) {
        self.accessToken = accessToken
    }
    
    func validateConnection() async throws -> Bool {
        let url = "\(baseURL)/users/get_current_account"
        
        // Dropbox API expects null body, not JSON content
        let response = try await AF.request(
            url,
            method: .post,
            headers: [
                "Authorization": "Bearer \(accessToken)"
            ]
        ).serializingData().value
        
        let json = try JSON(data: response)
        return json["account_id"].exists()
    }
    
    func getAccountInfo() async throws {
        let url = "\(baseURL)/users/get_current_account"
        
        // Dropbox API expects null body, not JSON
        let response = try await AF.request(
            url,
            method: .post,
            headers: [
                "Authorization": "Bearer \(accessToken)"
            ]
        ).serializingData().value
        
        let json = try JSON(data: response)
        guard json["account_id"].exists() else {
            throw DropboxError.authenticationFailed
        }
    }
    
    func uploadFile(data: Data, fileName: String, path: String = "/") async throws -> String {
        let fullPath = path.hasSuffix("/") ? path + fileName : "\(path)/\(fileName)"
        let uploadURL = "\(contentURL)/files/upload"
        
        let uploadArgs: [String: Any] = [
            "path": fullPath,
            "mode": "add",
            "autorename": true,
            "mute": false
        ]
        
        guard let uploadArgsData = try? JSONSerialization.data(withJSONObject: uploadArgs),
              let uploadArgsString = String(data: uploadArgsData, encoding: .utf8) else {
            throw DropboxError.invalidRequest
        }
        
        let response = try await AF.upload(
            data,
            to: uploadURL,
            method: .post,
            headers: [
                "Authorization": "Bearer \(accessToken)",
                "Dropbox-API-Arg": uploadArgsString,
                "Content-Type": "application/octet-stream"
            ]
        ).serializingData().value
        
        let json = try JSON(data: response)
        
        guard let filePath = json["path_display"].string else {
            throw DropboxError.uploadFailed
        }
        
        return try await createShareableLink(path: filePath)
    }
    
    private func createShareableLink(path: String) async throws -> String {
        let shareURL = "\(baseURL)/sharing/create_shared_link_with_settings"
        
        let shareArgs: [String: Any] = [
            "path": path,
            "settings": [
                "requested_visibility": "public",
                "audience": "public",
                "access": "viewer"
            ]
        ]
        
        let response = try await AF.request(
            shareURL,
            method: .post,
            parameters: shareArgs,
            encoding: JSONEncoding.default,
            headers: [
                "Authorization": "Bearer \(accessToken)",
                "Content-Type": "application/json"
            ]
        ).serializingData().value
        
        let json = try JSON(data: response)
        
        if let shareableURL = json["url"].string {
            return convertToDirectLink(shareableURL)
        } else if let error = json["error"][".tag"].string, error == "shared_link_already_exists" {
            return try await getExistingShareableLink(path: path)
        } else {
            throw DropboxError.shareLinkFailed
        }
    }
    
    private func getExistingShareableLink(path: String) async throws -> String {
        let listURL = "\(baseURL)/sharing/list_shared_links"
        
        let listArgs: [String: Any] = [
            "path": path,
            "direct_only": true
        ]
        
        let response = try await AF.request(
            listURL,
            method: .post,
            parameters: listArgs,
            encoding: JSONEncoding.default,
            headers: [
                "Authorization": "Bearer \(accessToken)",
                "Content-Type": "application/json"
            ]
        ).serializingData().value
        
        let json = try JSON(data: response)
        
        if let links = json["links"].array,
           let firstLink = links.first,
           let shareableURL = firstLink["url"].string {
            return convertToDirectLink(shareableURL)
        }
        
        throw DropboxError.shareLinkFailed
    }
    
    private func convertToDirectLink(_ shareableURL: String) -> String {
        return shareableURL.replacingOccurrences(of: "?dl=0", with: "?dl=1")
    }
    
    func deleteFile(path: String) async throws {
        let deleteURL = "\(baseURL)/files/delete_v2"
        
        let deleteArgs: [String: Any] = [
            "path": path
        ]
        
        let response = try await AF.request(
            deleteURL,
            method: .post,
            parameters: deleteArgs,
            encoding: JSONEncoding.default,
            headers: [
                "Authorization": "Bearer \(accessToken)",
                "Content-Type": "application/json"
            ]
        ).serializingData().value
        
        let json = try JSON(data: response)
        
        if json["error"].exists() {
            throw DropboxError.deleteFailed
        }
    }
    
    func listFiles(path: String = "/") async throws -> [DropboxFile] {
        let listURL = "\(baseURL)/files/list_folder"
        
        let listArgs: [String: Any] = [
            "path": path == "/" ? "" : path,
            "recursive": false,
            "include_media_info": false,
            "include_deleted": false
        ]
        
        let response = try await AF.request(
            listURL,
            method: .post,
            parameters: listArgs,
            encoding: JSONEncoding.default,
            headers: [
                "Authorization": "Bearer \(accessToken)",
                "Content-Type": "application/json"
            ]
        ).serializingData().value
        
        let json = try JSON(data: response)
        
        guard let entries = json["entries"].array else {
            throw DropboxError.listFailed
        }
        
        var files: [DropboxFile] = []
        
        for entry in entries {
            if let file = parseDropboxFile(from: entry) {
                files.append(file)
            }
        }
        
        return files
    }
    
    private func parseDropboxFile(from json: JSON) -> DropboxFile? {
        guard let tag = json[".tag"].string,
              let name = json["name"].string,
              let pathDisplay = json["path_display"].string else {
            return nil
        }
        
        let isFolder = tag == "folder"
        let size = json["size"].int64Value
        
        let dateFormatter = ISO8601DateFormatter()
        let modifiedDate = json["client_modified"].string.flatMap { dateFormatter.date(from: $0) }
        
        return DropboxFile(
            name: name,
            path: pathDisplay,
            isFolder: isFolder,
            size: size,
            lastModified: modifiedDate
        )
    }
}

struct DropboxFile {
    let name: String
    let path: String
    let isFolder: Bool
    let size: Int64
    let lastModified: Date?
}

enum DropboxError: Error, LocalizedError {
    case invalidRequest
    case uploadFailed
    case shareLinkFailed
    case deleteFailed
    case listFailed
    case authenticationFailed
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Invalid request to Dropbox API"
        case .uploadFailed:
            return "Failed to upload file to Dropbox"
        case .shareLinkFailed:
            return "Failed to create shareable link"
        case .deleteFailed:
            return "Failed to delete file from Dropbox"
        case .listFailed:
            return "Failed to list files from Dropbox"
        case .authenticationFailed:
            return "Dropbox authentication failed"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}