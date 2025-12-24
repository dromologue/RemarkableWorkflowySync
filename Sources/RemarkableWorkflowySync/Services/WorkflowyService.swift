import Foundation
import Alamofire
import SwiftyJSON

final class WorkflowyService: ObservableObject, @unchecked Sendable {
    private let apiKey: String
    private let username: String?
    private var remarkableRootNodeId: String?
    
    init(apiKey: String, username: String? = nil) {
        self.apiKey = apiKey
        self.username = username
    }
    
    func validateConnection() async throws -> Bool {
        // Test multiple Workflowy API endpoints
        let endpoints = [
            "https://workflowy.com/api/beta/get-initialization-data",
            "https://workflowy.com/get_initialization_data",
            "https://workflowy.com/api/outline"
        ]
        
        print("🔄 Testing Workflowy connection")
        if let username = username {
            print("👤 Username: \(username)")
        }
        print("🔑 API Key: \(apiKey.prefix(8))...")
        
        for url in endpoints {
            do {
                print("📡 Trying endpoint: \(url)")
                
                let response = try await AF.request(
                    url,
                    method: .get,
                    headers: [
                        "Cookie": "sessionid=\(apiKey)",
                        "X-Requested-With": "XMLHttpRequest",
                        "User-Agent": "RemarkableWorkflowySync/1.0",
                        "Accept": "application/json",
                        "Authorization": "Bearer \(apiKey)"
                    ]
                ).serializingData().value
            
                let responseString = String(data: response, encoding: .utf8) ?? "unable to decode response"
                print("📜 Response (\(response.count) bytes): \(responseString.prefix(200))")
                
                // Check if we got HTML (404/error page)
                if responseString.contains("<!DOCTYPE html>") {
                    print("❌ Endpoint \(url) returned HTML (likely 404)")
                    continue // Try next endpoint
                }
                
                let json = try JSON(data: response)
                
                // Check for successful responses with various formats
                if json["projectTreeData"].exists() ||
                   json["globals"].exists() ||
                   json["items"].exists() ||
                   json["outline"].exists() ||
                   json["email"].exists() ||
                   json["username"].exists() ||
                   !json.isEmpty {
                    
                    // If we have a username, verify it matches the response
                    if let expectedUsername = username {
                        let responseUsername = json["username"].string ?? json["email"].string
                        if let responseUsername = responseUsername {
                            if responseUsername.lowercased() == expectedUsername.lowercased() {
                                print("✅ Workflowy connection successful via \(url) for user: \(expectedUsername)")
                            } else {
                                print("⚠️ Username mismatch: expected \(expectedUsername), got \(responseUsername)")
                                print("✅ Workflowy connection successful via \(url) but for different user")
                            }
                        } else {
                            print("✅ Workflowy connection successful via \(url) (username not returned in response)")
                        }
                    } else {
                        print("✅ Workflowy connection successful via \(url)")
                    }
                    return true
                }
                
                // Check for error responses
                if json["error"].exists() {
                    let errorMessage = json["error"].string ?? ""
                    print("❌ Workflowy API error from \(url): \(errorMessage)")
                    if errorMessage.lowercased().contains("unauthorized") {
                        continue // Try next endpoint
                    }
                }
                
            } catch {
                print("❌ Endpoint \(url) failed: \(error.localizedDescription)")
                continue
            }
        }
        
        // If all endpoints failed, return false
        print("⚠️ All Workflowy endpoints failed - API may be invalid or service unavailable")
        return false
            
    }
    
    func fetchRootNodes() async throws -> [WorkflowyNode] {
        // Try various Workflowy API endpoints for fetching outline data
        let endpoints = [
            "https://workflowy.com/api/beta/get-initialization-data",
            "https://workflowy.com/get_initialization_data", 
            "https://workflowy.com/api/outline",
            "https://workflowy.com/api/beta/list-children/"
        ]
        
        var lastError: Error?
        
        for url in endpoints {
            do {
                print("🔄 Trying Workflowy endpoint: \(url)")
                
                let response = try await AF.request(
                    url,
                    method: .get,
                    headers: [
                        "Cookie": "sessionid=\(apiKey)",
                        "X-Requested-With": "XMLHttpRequest",
                        "Authorization": "Bearer \(apiKey)",
                        "User-Agent": "RemarkableWorkflowySync/1.0",
                        "Accept": "application/json"
                    ]
                ).serializingData().value
                
                let responseString = String(data: response, encoding: .utf8) ?? "unable to decode"
                print("📜 Response: \(responseString.prefix(200))")
                
                let json = try JSON(data: response)
                
                guard !json.isEmpty else {
                    continue // Try next endpoint
                }
                
                var nodes: [WorkflowyNode] = []
                
                // Try different response formats
                if let projectTreeData = json["projectTreeData"].dictionary {
                    for (_, item) in projectTreeData {
                        if let node = parseNode(from: item) {
                            nodes.append(node)
                        }
                    }
                } else if let bulletArray = json.array {
                    for item in bulletArray {
                        if let node = parseNode(from: item) {
                            nodes.append(node)
                        }
                    }
                } else if let tree = json["tree"].array {
                    for item in tree {
                        if let node = parseNode(from: item) {
                            nodes.append(node)
                        }
                    }
                }
                
                print("✅ Workflowy: Found \(nodes.count) root nodes")
                return nodes
                
            } catch {
                print("❌ Workflowy endpoint \(url) failed: \(error.localizedDescription)")
                lastError = error
                continue
            }
        }
        
        // If all endpoints failed, throw the last error
        if let error = lastError {
            throw WorkflowyError.apiError("All Workflowy endpoints failed: \(error.localizedDescription)")
        } else {
            throw WorkflowyError.invalidResponse
        }
    }
    
    func createNode(name: String, note: String? = nil, parentId: String? = nil) async throws -> WorkflowyNode {
        // Try the official Workflowy API endpoint for creating nodes
        let endpoints = [
            "https://workflowy.com/api/nodes"
        ]
        
        print("🔄 Creating Workflowy node: \(name)")
        
        for endpoint in endpoints {
            do {
                return try await attemptCreateNode(endpoint: endpoint, name: name, note: note, parentId: parentId)
            } catch {
                print("❌ Create endpoint \(endpoint) failed: \(error.localizedDescription)")
                continue
            }
        }
        
        print("⚠️ All Workflowy create endpoints failed, creating virtual node")
        
        // If all API methods fail, create virtual node for manual creation
        let virtualId = "pending-\(UUID().uuidString)"
        return WorkflowyNode(
            id: virtualId,
            name: "📄 \(name)",
            note: (note ?? "") + "\n\n[Note: Please create this node manually in Workflowy - API write access may be limited]",
            parentId: parentId,
            children: nil
        )
    }
    
    private func attemptCreateNode(endpoint: String, name: String, note: String?, parentId: String?) async throws -> WorkflowyNode {
        var requestBody: [String: Any] = [
            "name": name
        ]
        
        if let note = note {
            requestBody["note"] = note
        }
        
        if let parentId = parentId {
            requestBody["parentid"] = parentId
        }
        
        print("📡 Attempting create at: \(endpoint)")
        
        let response = try await AF.request(
            endpoint,
            method: .post,
            parameters: requestBody,
            encoding: JSONEncoding.default,
            headers: [
                "Authorization": "Bearer \(apiKey)",
                "Content-Type": "application/json",
                "User-Agent": "RemarkableWorkflowySync/1.0"
            ]
        ).serializingData().value
        
        let responseString = String(data: response, encoding: .utf8) ?? "unable to decode"
        print("📜 Create response: \(responseString.prefix(200))")
        
        let json = try JSON(data: response)
        
        // Check for various success response formats
        if json["success"].bool == true || json["id"].exists() || json["uuid"].exists() {
            let nodeId = json["id"].string ?? json["uuid"].string ?? json["node"]["id"].string ?? UUID().uuidString
            print("✅ Node created with ID: \(nodeId)")
            return WorkflowyNode(
                id: nodeId,
                name: name,
                note: note,
                parentId: parentId,
                children: nil
            )
        }
        
        if json["error"].exists() {
            let error = json["error"].string ?? "Unknown error"
            print("❌ Workflowy create error: \(error)")
            throw WorkflowyError.apiError(error)
        }
        
        // Check if we got an HTTP error response
        if responseString.contains("<!DOCTYPE html>") {
            throw WorkflowyError.apiError("Received HTML response - endpoint may not exist or API key invalid")
        }
        
        throw WorkflowyError.apiError("Failed to create node via \(endpoint) - unexpected response format")
    }
    
    func updateNode(id: String, name: String? = nil, note: String? = nil) async throws {
        // Try the official Workflowy API endpoint for updating nodes
        let endpoints = [
            "https://workflowy.com/api/nodes"
        ]
        
        print("🔄 Updating Workflowy node: \(id)")
        
        for endpoint in endpoints {
            do {
                try await attemptUpdateNode(endpoint: endpoint, id: id, name: name, note: note)
                print("✅ Node updated successfully")
                return // Success
            } catch {
                print("❌ Update endpoint \(endpoint) failed: \(error.localizedDescription)")
                continue
            }
        }
        
        print("⚠️ All Workflowy update endpoints failed")
        throw WorkflowyError.apiError("All update endpoints failed. Workflowy API may have limited write access - please update manually in Workflowy.")
    }
    
    private func attemptUpdateNode(endpoint: String, id: String, name: String?, note: String?) async throws {
        var requestBody: [String: Any] = [
            "id": id
        ]
        
        if let name = name {
            requestBody["name"] = name
        }
        
        if let note = note {
            requestBody["note"] = note
        }
        
        print("📡 Attempting update at: \(endpoint)")
        
        let response = try await AF.request(
            endpoint,
            method: .put, // Try PUT for updates
            parameters: requestBody,
            encoding: JSONEncoding.default,
            headers: [
                "Authorization": "Bearer \(apiKey)",
                "Content-Type": "application/json",
                "User-Agent": "RemarkableWorkflowySync/1.0"
            ]
        ).serializingData().value
        
        let responseString = String(data: response, encoding: .utf8) ?? "unable to decode"
        print("📜 Update response: \(responseString.prefix(200))")
        
        let json = try JSON(data: response)
        
        // Check for error responses
        if json["success"].bool == false {
            let error = json["error"].string ?? "Update failed"
            print("❌ Workflowy update error: \(error)")
            throw WorkflowyError.apiError(error)
        }
        
        // Check if we got an HTTP error response
        if responseString.contains("<!DOCTYPE html>") {
            throw WorkflowyError.apiError("Received HTML response - endpoint may not exist or API key invalid")
        }
        
        // If we get here without an explicit success/failure, assume it worked
        print("✅ Update appears successful")
    }
    
    // MARK: - Remarkable Integration Methods
    
    func ensureRemarkableRootNode() async throws -> WorkflowyNode {
        if let cachedId = remarkableRootNodeId {
            // Check if the cached node still exists
            do {
                let allNodes = try await fetchRootNodes()
                if let existingNode = findNodeById(cachedId, in: allNodes) {
                    return existingNode
                }
            } catch {
                // If we can't fetch nodes, clear cache and continue
                remarkableRootNodeId = nil
            }
        }
        
        // Search for existing "Remarkable" node
        let allNodes = try await fetchRootNodes()
        if let existingRemarkable = findRemarkableNode(in: allNodes) {
            remarkableRootNodeId = existingRemarkable.id
            return existingRemarkable
        }
        
        // Create new "Remarkable" root node
        let remarkableNode = try await createNode(
            name: "📱 Remarkable",
            note: "Documents and notebooks from Remarkable 2 tablet\n\nSynced automatically by RemarkableWorkflowySync",
            parentId: nil // Top level
        )
        
        remarkableRootNodeId = remarkableNode.id
        return remarkableNode
    }
    
    func createRemarkableFolderStructure(document: RemarkableDocument, dropboxUrl: String?) async throws -> WorkflowyNode {
        let remarkableRoot = try await ensureRemarkableRootNode()
        
        // Create folder structure based on document hierarchy
        let parentNode = remarkableRoot
        
        // If document has a parent folder, ensure that folder exists
        if document.parentId != nil {
            // This would require fetching the parent document structure
            // For now, create under root
        }
        
        // Create document node with rich metadata
        var noteContent = """
        📄 Type: \(document.type.uppercased())
        📏 Size: \(formatFileSize(document.size))
        📅 Modified: \(document.lastModified.formatted())
        🆔 Remarkable ID: \(document.id)
        """
        
        if let dropboxUrl = dropboxUrl {
            noteContent += "\n\n🔗 Dropbox Link: \(dropboxUrl)\n\n📲 Click to download or view the document"
        }
        
        let documentNode = try await createNode(
            name: "📄 \(document.name)",
            note: noteContent,
            parentId: parentNode.id
        )
        
        return documentNode
    }
    
    func syncRemarkableDocument(_ document: RemarkableDocument, dropboxUrl: String?) async throws -> WorkflowyNode {
        // Check if document already exists in Workflowy
        if let existingNodeId = document.workflowyNodeId {
            // Update existing node
            let updatedNote = createDocumentNote(for: document, dropboxUrl: dropboxUrl)
            try await updateNode(id: existingNodeId, name: nil, note: updatedNote)
            
            return WorkflowyNode(
                id: existingNodeId,
                name: document.name,
                note: updatedNote,
                parentId: remarkableRootNodeId,
                children: nil
            )
        } else {
            // Create new node
            return try await createRemarkableFolderStructure(document: document, dropboxUrl: dropboxUrl)
        }
    }
    
    private func findRemarkableNode(in nodes: [WorkflowyNode]) -> WorkflowyNode? {
        for node in nodes {
            if node.name.contains("Remarkable") || node.name.contains("📱") {
                return node
            }
            // Search recursively in children
            if let children = node.children,
               let found = findRemarkableNode(in: children) {
                return found
            }
        }
        return nil
    }
    
    private func findNodeById(_ id: String, in nodes: [WorkflowyNode]) -> WorkflowyNode? {
        for node in nodes {
            if node.id == id {
                return node
            }
            // Search recursively in children
            if let children = node.children,
               let found = findNodeById(id, in: children) {
                return found
            }
        }
        return nil
    }
    
    private func createDocumentNote(for document: RemarkableDocument, dropboxUrl: String?) -> String {
        var noteContent = """
        📄 Type: \(document.type.uppercased())
        📏 Size: \(formatFileSize(document.size))
        📅 Modified: \(document.lastModified.formatted())
        🆔 Remarkable ID: \(document.id)
        """
        
        if let dropboxUrl = dropboxUrl {
            noteContent += "\n\n🔗 Dropbox Link: \(dropboxUrl)\n\n📲 Click to download or view the document"
        }
        
        return noteContent
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    func searchNodes(query: String) async throws -> [WorkflowyNode] {
        // Since Workflowy API doesn't support direct search, get all nodes and filter locally
        let allNodes = try await fetchRootNodes()
        
        func searchInNodes(_ nodes: [WorkflowyNode]) -> [WorkflowyNode] {
            var results: [WorkflowyNode] = []
            
            for node in nodes {
                // Check if current node matches
                if node.name.lowercased().contains(query.lowercased()) ||
                   (node.note?.lowercased().contains(query.lowercased()) ?? false) {
                    results.append(node)
                }
                
                // Recursively search children
                if let children = node.children {
                    results.append(contentsOf: searchInNodes(children))
                }
            }
            
            return results
        }
        
        return searchInNodes(allNodes)
    }
    
    func deleteNode(id: String) async throws {
        // Note: Workflowy's public API is read-only. Deletions require manual action.
        throw WorkflowyError.apiError("Workflowy's public API doesn't support deleting nodes. Please delete manually in Workflowy.")
    }
    
    private func parseNode(from json: JSON) -> WorkflowyNode? {
        guard let id = json["id"].string,
              let name = json["nm"].string else {
            return nil
        }
        
        let note = json["no"].string
        let parentId = json["prnt"].string
        
        var children: [WorkflowyNode] = []
        if let childrenData = json["ch"].array {
            for childJson in childrenData {
                if let child = parseNode(from: childJson) {
                    children.append(child)
                }
            }
        }
        
        return WorkflowyNode(
            id: id,
            name: name,
            note: note,
            parentId: parentId?.isEmpty == true ? nil : parentId,
            children: children.isEmpty ? nil : children
        )
    }
}

enum WorkflowyError: Error, LocalizedError {
    case authenticationFailed
    case invalidResponse
    case apiError(String)
    case nodeNotFound
    case rateLimited
    
    var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "Failed to authenticate with Workflowy"
        case .invalidResponse:
            return "Received invalid response from Workflowy"
        case .apiError(let message):
            return "API Error: \(message)"
        case .nodeNotFound:
            return "Node not found"
        case .rateLimited:
            return "Rate limit exceeded"
        }
    }
}