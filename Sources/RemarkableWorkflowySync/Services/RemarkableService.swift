import Foundation
import Alamofire
import SwiftyJSON
import Crypto

final class RemarkableService: ObservableObject, @unchecked Sendable {
    private var bearerToken: String?
    private var storageHost: String?

    // API Endpoints
    private let authURL = "https://webapp-production-dot-remarkable-production.appspot.com"
    private let serviceDiscoveryURL = "https://service-manager-production-dot-remarkable-production.appspot.com"
    private let defaultStorageURL = "https://document-storage-production-dot-remarkable-production.appspot.com"

    /// Initialize with an optional bearer token
    /// - Parameter bearerToken: The bearer token from a previous registration. If nil, will try to load from:
    ///   1. AppSettings (remarkableDeviceToken)
    ///   2. Local file storage (~/.remarkable-token)
    init(bearerToken: String? = nil) {
        if let token = bearerToken, !token.isEmpty {
            self.bearerToken = token
        } else {
            // Try to load from AppSettings first, then from file
            let settings = AppSettings.load()
            if !settings.remarkableDeviceToken.isEmpty && settings.remarkableDeviceToken.count > 8 {
                // This is a bearer token (not an 8-char registration code)
                self.bearerToken = settings.remarkableDeviceToken
            } else {
                // Fallback to file-based token storage
                self.bearerToken = loadSavedToken()
            }
        }
    }

    /// Check if we have a valid bearer token (not a registration code)
    var hasBearerToken: Bool {
        guard let token = bearerToken else { return false }
        // Bearer tokens are JWT-like and much longer than 8 characters
        return token.count > 8
    }
    
    /// Register a new device with an 8-character code from my.remarkable.com
    func registerDevice(code: String) async throws -> String {
        guard code.count == 8 else {
            throw RemarkableError.invalidToken("Registration code must be exactly 8 characters. Get one from https://my.remarkable.com/device/connect/desktop")
        }
        
        let url = "https://webapp-production-dot-remarkable-production.appspot.com/token/json/2/device/new"
        let deviceID = generateDeviceID()
        
        let requestBody: [String: Any] = [
            "code": code,
            "deviceDesc": "desktop-windows", // Use desktop-windows as per RemarkableAPI
            "deviceID": deviceID
        ]
        
        print("🔄 Registering device with code: \(code)")
        print("📡 Request URL: \(url)")
        print("🆔 Device ID: \(deviceID)")
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody, options: [])
            
            var request = URLRequest(url: URL(string: url)!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            let response = try await AF.request(request).serializingData().value
            
            // The response should be the token as plain text, not JSON
            if let tokenString = String(data: response, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                if tokenString.isEmpty || tokenString.contains("error") || tokenString.contains("<html") {
                    throw RemarkableError.apiError("Invalid response from registration: \(tokenString.prefix(100))")
                }
                
                print("✅ Registration successful, token received")

                self.bearerToken = tokenString
                saveToken(tokenString)
                saveBearerTokenToSettings(tokenString)

                // Discover storage endpoint after registration
                try await discoverStorageEndpoint()

                return tokenString
            } else {
                // Fallback: try parsing as JSON
                let json = try JSON(data: response)
                
                if let token = json["token"].string ?? json["bearerToken"].string ?? json.string {
                    print("✅ Registration successful via JSON, token received")

                    self.bearerToken = token
                    saveToken(token)
                    saveBearerTokenToSettings(token)
                    try await discoverStorageEndpoint()
                    return token
                }
                
                if let error = json["error"].string {
                    throw RemarkableError.apiError("Registration failed: \(error)")
                }
                
                throw RemarkableError.apiError("Unknown response format: \(String(data: response, encoding: .utf8) ?? "unable to decode")")
            }
            
        } catch let error as RemarkableError {
            print("❌ Registration failed: \(error.localizedDescription)")
            throw error
        } catch {
            print("❌ Registration network error: \(error.localizedDescription)")
            throw RemarkableError.networkError(error.localizedDescription)
        }
    }
    
    /// Refresh the bearer token
    func refreshToken() async throws -> String {
        guard let currentToken = bearerToken else {
            throw RemarkableError.authenticationFailed
        }
        
        let url = "\(authURL)/token/json/2/user/new"
        
        let response = try await AF.request(
            url,
            method: .post,
            headers: [
                "Authorization": "Bearer \(currentToken)",
                "Content-Type": "application/json"
            ]
        ).serializingData().value
        
        let json = try JSON(data: response)
        
        guard let newToken = json["token"].string ?? json["bearerToken"].string else {
            throw RemarkableError.authenticationFailed
        }
        
        self.bearerToken = newToken
        saveToken(newToken)
        return newToken
    }
    
    /// Discover the storage endpoint for API calls
    private func discoverStorageEndpoint() async throws {
        guard let token = bearerToken else {
            throw RemarkableError.authenticationFailed
        }
        
        let url = "\(serviceDiscoveryURL)/service/json/1/document-storage"
        
        do {
            let response = try await AF.request(
                url,
                method: .get,
                headers: ["Authorization": "Bearer \(token)"]
            ).serializingData().value
            
            let json = try JSON(data: response)
            
            if let status = json["Status"].string, status == "OK",
               let host = json["Host"].string {
                self.storageHost = "https://\(host)"
            } else {
                // Use default if discovery fails
                self.storageHost = defaultStorageURL
            }
        } catch {
            // Use default storage URL if discovery fails
            self.storageHost = defaultStorageURL
        }
    }
    
    /// Validate that we have a valid bearer token
    func validateConnection() async throws -> Bool {
        guard bearerToken != nil else {
            return false
        }
        
        do {
            // Try to fetch documents as a validation check
            _ = try await fetchDocuments()
            return true
        } catch {
            // If unauthorized, try to refresh token
            if case RemarkableError.authenticationFailed = error {
                do {
                    _ = try await refreshToken()
                    return true
                } catch {
                    return false
                }
            }
            return false
        }
    }
    
    func fetchDocuments() async throws -> [RemarkableDocument] {
        guard let token = bearerToken else {
            throw RemarkableError.authenticationFailed
        }
        
        let storageURL = storageHost ?? defaultStorageURL
        let documentsURL = "\(storageURL)/document-storage/json/2/docs"
        
        let response = try await AF.request(
            documentsURL,
            method: .get,
            headers: ["Authorization": "Bearer \(token)"]
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
    
    /// Fetch folder structure with documents organized hierarchically
    func fetchFolderStructure() async throws -> [RemarkableFolder] {
        guard let token = bearerToken else {
            throw RemarkableError.authenticationFailed
        }
        
        let storageURL = storageHost ?? defaultStorageURL
        let documentsURL = "\(storageURL)/document-storage/json/2/docs"
        
        let response = try await AF.request(
            documentsURL,
            method: .get,
            headers: ["Authorization": "Bearer \(token)"]
        ).serializingData().value
        
        let json = try JSON(data: response)
        
        var allItems: [JSON] = []
        for (_, item) in json {
            allItems.append(item)
        }
        
        return buildFolderStructure(from: allItems)
    }
    
    func downloadDocument(id: String) async throws -> Data {
        guard let token = bearerToken else {
            throw RemarkableError.authenticationFailed
        }
        
        let storageURL = storageHost ?? defaultStorageURL
        
        // First get the blob URL
        let blobURLRequest = "\(storageURL)/document-storage/json/2/docs/\(id)/blob"
        
        let blobResponse = try await AF.request(
            blobURLRequest,
            method: .get,
            headers: ["Authorization": "Bearer \(token)"]
        ).serializingData().value
        
        let blobJson = try JSON(data: blobResponse)
        guard let blobURL = blobJson["url"].string else {
            throw RemarkableError.invalidResponse
        }
        
        // Download from the blob URL
        let response = try await AF.request(blobURL).serializingData().value
        return response
    }
    
    func getDocumentMetadata(id: String) async throws -> JSON {
        guard let token = bearerToken else {
            throw RemarkableError.authenticationFailed
        }
        
        let storageURL = storageHost ?? defaultStorageURL
        let metadataURL = "\(storageURL)/document-storage/json/2/docs/\(id)"
        
        let response = try await AF.request(
            metadataURL,
            method: .get,
            headers: ["Authorization": "Bearer \(token)"]
        ).serializingData().value
        
        return try JSON(data: response)
    }
    
    /// Delete a document or folder
    func deleteDocument(id: String) async throws {
        guard let token = bearerToken else {
            throw RemarkableError.authenticationFailed
        }
        
        let storageURL = storageHost ?? defaultStorageURL
        let deleteURL = "\(storageURL)/document-storage/json/2/delete"
        
        let parameters: [[String: Any]] = [[
            "ID": id,
            "Version": 1
        ]]
        
        let jsonData = try JSONSerialization.data(withJSONObject: parameters, options: [])
        
        var request = URLRequest(url: URL(string: deleteURL)!)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        _ = try await AF.request(request).serializingData().value
    }
    
    /// Upload a PDF document
    func uploadPDF(data: Data, name: String, parentId: String? = nil) async throws -> String {
        guard let token = bearerToken else {
            throw RemarkableError.authenticationFailed
        }
        
        let storageURL = storageHost ?? defaultStorageURL
        let documentId = UUID().uuidString.lowercased()
        
        // Step 1: Request upload URL
        let uploadRequestURL = "\(storageURL)/document-storage/json/2/upload/request"
        let uploadParams: [[String: Any]] = [[
            "ID": documentId,
            "Type": "DocumentType",
            "Version": 1
        ]]
        
        let uploadJsonData = try JSONSerialization.data(withJSONObject: uploadParams, options: [])
        
        var uploadRequest = URLRequest(url: URL(string: uploadRequestURL)!)
        uploadRequest.httpMethod = "PUT"
        uploadRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        uploadRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        uploadRequest.httpBody = uploadJsonData
        
        let uploadResponse = try await AF.request(uploadRequest).serializingData().value
        
        let uploadJson = try JSON(data: uploadResponse)
        guard let uploadURL = uploadJson[0]["BlobURLPut"].string else {
            throw RemarkableError.apiError("Failed to get upload URL")
        }
        
        // Step 2: Upload the PDF
        _ = try await AF.upload(data, to: uploadURL, method: .put).serializingData().value
        
        // Step 3: Update metadata
        let updateStatusURL = "\(storageURL)/document-storage/json/2/upload/update-status"
        let metadataParams: [[String: Any]] = [[
            "ID": documentId,
            "Parent": parentId ?? "",
            "VissibleName": name,
            "Type": "DocumentType",
            "Version": 1,
            "ModifiedClient": ISO8601DateFormatter().string(from: Date())
        ]]
        
        let metadataJsonData = try JSONSerialization.data(withJSONObject: metadataParams, options: [])
        
        var metadataRequest = URLRequest(url: URL(string: updateStatusURL)!)
        metadataRequest.httpMethod = "PUT"
        metadataRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        metadataRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        metadataRequest.httpBody = metadataJsonData
        
        _ = try await AF.request(metadataRequest).serializingData().value
        
        return documentId
    }
    
    /// Create a folder/collection
    func createFolder(name: String, parentId: String? = nil) async throws -> String {
        guard let token = bearerToken else {
            throw RemarkableError.authenticationFailed
        }
        
        let storageURL = storageHost ?? defaultStorageURL
        let folderId = UUID().uuidString.lowercased()
        
        // Step 1: Request upload URL for folder creation
        let uploadRequestURL = "\(storageURL)/document-storage/json/2/upload/request"
        let uploadParams: [[String: Any]] = [[
            "ID": folderId,
            "Type": "CollectionType",
            "Version": 1
        ]]
        
        let uploadJsonData = try JSONSerialization.data(withJSONObject: uploadParams, options: [])
        
        var uploadRequest = URLRequest(url: URL(string: uploadRequestURL)!)
        uploadRequest.httpMethod = "PUT"
        uploadRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        uploadRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        uploadRequest.httpBody = uploadJsonData
        
        let uploadResponse = try await AF.request(uploadRequest).serializingData().value
        let uploadJson = try JSON(data: uploadResponse)
        
        guard uploadJson[0]["Success"].bool == true else {
            throw RemarkableError.apiError("Failed to initiate folder creation")
        }
        
        // Step 2: Update metadata to create the folder
        let updateStatusURL = "\(storageURL)/document-storage/json/2/upload/update-status"
        let metadataParams: [[String: Any]] = [[
            "ID": folderId,
            "Parent": parentId ?? "",
            "VissibleName": name,
            "Type": "CollectionType",
            "Version": 1,
            "ModifiedClient": ISO8601DateFormatter().string(from: Date())
        ]]
        
        let metadataJsonData = try JSONSerialization.data(withJSONObject: metadataParams, options: [])
        
        var metadataRequest = URLRequest(url: URL(string: updateStatusURL)!)
        metadataRequest.httpMethod = "PUT"
        metadataRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        metadataRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        metadataRequest.httpBody = metadataJsonData
        
        _ = try await AF.request(metadataRequest).serializingData().value
        
        return folderId
    }
    
    private func buildFolderStructure(from items: [JSON]) -> [RemarkableFolder] {
        // Parse all items into documents and folders
        var documents: [RemarkableDocument] = []
        var folderData: [String: (name: String, parentId: String?)] = [:]
        
        for item in items {
            guard let id = item["ID"].string,
                  let name = item["VissibleName"].string,
                  let type = item["Type"].string else {
                continue
            }
            
            let parentId = item["Parent"].string
            let cleanParentId = (parentId?.isEmpty == false) ? parentId : nil
            
            if type == "CollectionType" {
                // This is a folder
                folderData[id] = (name: name, parentId: cleanParentId)
            } else if let document = parseDocument(from: item) {
                // This is a document
                documents.append(document)
            }
        }
        
        // Build folder hierarchy
        var folderMap: [String: RemarkableFolder] = [:]
        
        // Create all folders first
        for (folderId, folderInfo) in folderData {
            let folder = RemarkableFolder(
                id: folderId,
                name: folderInfo.name,
                parentId: folderInfo.parentId,
                children: [],
                documents: []
            )
            folderMap[folderId] = folder
        }
        
        // Organize documents into their parent folders
        for document in documents {
            if let parentId = document.parentId,
               var parentFolder = folderMap[parentId] {
                parentFolder.documents.append(document)
                folderMap[parentId] = parentFolder
            }
        }
        
        // Build parent-child relationships for folders
        var rootFolders: [RemarkableFolder] = []
        
        for (_, folder) in folderMap {
            if let parentId = folder.parentId,
               var parentFolder = folderMap[parentId] {
                parentFolder.children.append(folder)
                folderMap[parentId] = parentFolder
            } else {
                // This is a root folder
                rootFolders.append(folder)
            }
        }
        
        // Update the folderMap with the built hierarchy
        for rootFolder in rootFolders {
            updateFolderInMap(&folderMap, folder: rootFolder)
        }
        
        // Create a root folder for documents without a parent folder
        let documentsWithoutParent = documents.filter { document in
            document.parentId == nil || folderMap[document.parentId!] == nil
        }
        
        if !documentsWithoutParent.isEmpty || rootFolders.isEmpty {
            let rootFolder = RemarkableFolder(
                id: "root",
                name: "My Files",
                parentId: nil,
                children: rootFolders,
                documents: documentsWithoutParent
            )
            return [rootFolder]
        }
        
        return rootFolders.sorted { $0.name < $1.name }
    }
    
    private func updateFolderInMap(_ folderMap: inout [String: RemarkableFolder], folder: RemarkableFolder) {
        var updatedFolder = folder
        
        // Update children recursively
        for (index, child) in folder.children.enumerated() {
            if let updatedChild = folderMap[child.id] {
                updatedFolder.children[index] = updatedChild
                updateFolderInMap(&folderMap, folder: updatedChild)
            }
        }
        
        folderMap[folder.id] = updatedFolder
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
        // Use a persistent device ID
        if let savedDeviceID = UserDefaults.standard.string(forKey: "RemarkableDeviceID") {
            return savedDeviceID
        }
        
        let deviceID = UUID().uuidString
        UserDefaults.standard.set(deviceID, forKey: "RemarkableDeviceID")
        return deviceID
    }
    
    private func saveToken(_ token: String) {
        let tokenPath = getTokenPath()
        try? token.write(to: tokenPath, atomically: true, encoding: .utf8)
    }

    private func loadSavedToken() -> String? {
        let tokenPath = getTokenPath()
        return try? String(contentsOf: tokenPath, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func getTokenPath() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent(".remarkable-token")
    }

    /// Save the bearer token to AppSettings for persistence across app launches
    private func saveBearerTokenToSettings(_ token: String) {
        var settings = AppSettings.load()
        settings.remarkableDeviceToken = token
        settings.save()
        print("📝 Bearer token saved to AppSettings")
    }
}

enum RemarkableError: Error, LocalizedError, Equatable {
    case authenticationFailed
    case invalidResponse
    case documentNotFound
    case networkError(String)
    case invalidToken(String)
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "Failed to authenticate with Remarkable service. You may need to register with a new code."
        case .invalidResponse:
            return "Received invalid response from Remarkable service"
        case .documentNotFound:
            return "Document not found"
        case .invalidToken(let message):
            return message
        case .networkError(let message):
            return "Network error: \(message)"
        case .apiError(let message):
            return "API Error: \(message)"
        }
    }
}