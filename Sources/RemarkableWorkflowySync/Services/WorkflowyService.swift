import Foundation
import Alamofire
import SwiftyJSON

final class WorkflowyService: ObservableObject, @unchecked Sendable {
    private let apiKey: String
    private let baseURL = "https://workflowy.com/api"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func validateConnection() async throws -> Bool {
        // Workflowy's API is limited. Try the main endpoint that should work
        let url = "https://workflowy.com/get_initialization_data"
        
        do {
            let response = try await AF.request(
                url,
                method: .get,
                parameters: ["api_key": apiKey],
                headers: [
                    "User-Agent": "RemarkableWorkflowySync/1.0",
                    "Accept": "application/json"
                ]
            ).serializingData().value
            
            let json = try JSON(data: response)
            
            // Check for valid Workflowy response structure
            if json["user"].exists() || 
               json["projectTreeData"].exists() ||
               json["settings"].exists() {
                return true
            }
            
            // Check for error responses
            if json["error"].exists() {
                let errorMessage = json["error"].string ?? ""
                if errorMessage.lowercased().contains("invalid") {
                    return false // Invalid API key
                }
            }
            
            // If we get HTML back instead of JSON, it's likely a 404/invalid endpoint
            if let responseString = String(data: response, encoding: .utf8),
               responseString.contains("<!DOCTYPE html>") {
                throw WorkflowyError.apiError("API endpoint returned HTML instead of JSON - API key may be invalid")
            }
            
            return !json.isEmpty
            
        } catch let error as WorkflowyError {
            throw error
        } catch {
            throw WorkflowyError.apiError("Failed to validate connection: \(error.localizedDescription)")
        }
    }
    
    func fetchRootNodes() async throws -> [WorkflowyNode] {
        let url = "https://workflowy.com/get_initialization_data"
        
        let response = try await AF.request(
            url,
            method: .get,
            parameters: ["api_key": apiKey],
            headers: [
                "User-Agent": "RemarkableWorkflowySync/1.0",
                "Accept": "application/json"
            ]
        ).serializingData().value
        
        let json = try JSON(data: response)
        
        guard !json.isEmpty else {
            throw WorkflowyError.invalidResponse
        }
        
        var nodes: [WorkflowyNode] = []
        
        // Workflowy returns data in projectTreeData structure
        if let projectTreeData = json["projectTreeData"].dictionary {
            for (_, item) in projectTreeData {
                if let node = parseNode(from: item) {
                    nodes.append(node)
                }
            }
        }
        
        return nodes
    }
    
    func createNode(name: String, note: String? = nil, parentId: String? = nil) async throws -> WorkflowyNode {
        // Note: Workflowy's public API is read-only. Creating nodes requires manual action.
        // For now, we'll create a virtual node that represents what should be created
        
        let virtualId = "pending-\(UUID().uuidString)"
        
        return WorkflowyNode(
            id: virtualId,
            name: "📄 \(name)",
            note: (note ?? "") + "\n\n[Note: This node needs to be manually created in Workflowy]",
            parentId: parentId,
            children: nil
        )
    }
    
    func updateNode(id: String, name: String? = nil, note: String? = nil) async throws {
        // Note: Workflowy's public API is read-only. Updates require manual action.
        throw WorkflowyError.apiError("Workflowy's public API doesn't support updating nodes. Please update manually in Workflowy.")
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