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
        // Try multiple Workflowy endpoints since the API structure is not well documented
        let endpoints = [
            "https://workflowy.com/get_initialization_data",
            "\(baseURL)/get_initialization_data", 
            "https://workflowy.com/api/beta/get-initialization-data"
        ]
        
        for endpoint in endpoints {
            do {
                let response = try await AF.request(
                    endpoint,
                    method: .get,
                    parameters: ["api_key": apiKey],
                    headers: [
                        "Content-Type": "application/json",
                        "User-Agent": "RemarkableWorkflowySync/1.0"
                    ]
                ).serializingData().value
                
                let json = try JSON(data: response)
                
                // Check for valid response indicators
                if json["user"].exists() || 
                   json["projectTreeData"].exists() ||
                   json["settings"].exists() ||
                   (json["success"].bool == true) {
                    return true
                }
                
                // Check if it's an auth error vs endpoint error
                if let error = json["error"].string?.lowercased() {
                    if error.contains("invalid") || error.contains("unauthorized") {
                        return false // Invalid API key
                    }
                }
                
            } catch {
                // Try next endpoint
                continue
            }
        }
        
        return false // All endpoints failed
    }
    
    func fetchRootNodes() async throws -> [WorkflowyNode] {
        let url = "\(baseURL)/outline/get"
        
        let response = try await AF.request(
            url,
            method: .get,
            headers: ["Authorization": "Bearer \(apiKey)"]
        ).serializingData().value
        
        let json = try JSON(data: response)
        
        guard json["success"].boolValue else {
            throw WorkflowyError.apiError(json["error"].stringValue)
        }
        
        var nodes: [WorkflowyNode] = []
        let outline = json["outline"]
        
        for (_, item) in outline {
            if let node = parseNode(from: item) {
                nodes.append(node)
            }
        }
        
        return nodes
    }
    
    func createNode(name: String, note: String? = nil, parentId: String? = nil) async throws -> WorkflowyNode {
        let url = "\(baseURL)/outline/create"
        
        var parameters: [String: Any] = [
            "name": name
        ]
        
        if let note = note {
            parameters["note"] = note
        }
        
        if let parentId = parentId {
            parameters["parentid"] = parentId
        }
        
        let response = try await AF.request(
            url,
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: ["Authorization": "Bearer \(apiKey)"]
        ).serializingData().value
        
        let json = try JSON(data: response)
        
        guard json["success"].boolValue else {
            throw WorkflowyError.apiError(json["error"].stringValue)
        }
        
        let nodeData = json["node"]
        guard let node = parseNode(from: nodeData) else {
            throw WorkflowyError.invalidResponse
        }
        
        return node
    }
    
    func updateNode(id: String, name: String? = nil, note: String? = nil) async throws {
        let url = "\(baseURL)/outline/edit"
        
        var parameters: [String: Any] = [
            "projectid": id
        ]
        
        if let name = name {
            parameters["name"] = name
        }
        
        if let note = note {
            parameters["note"] = note
        }
        
        let response = try await AF.request(
            url,
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: ["Authorization": "Bearer \(apiKey)"]
        ).serializingData().value
        
        let json = try JSON(data: response)
        
        guard json["success"].boolValue else {
            throw WorkflowyError.apiError(json["error"].stringValue)
        }
    }
    
    func searchNodes(query: String) async throws -> [WorkflowyNode] {
        let url = "\(baseURL)/search"
        
        let parameters = [
            "query": query
        ]
        
        let response = try await AF.request(
            url,
            method: .get,
            parameters: parameters,
            headers: ["Authorization": "Bearer \(apiKey)"]
        ).serializingData().value
        
        let json = try JSON(data: response)
        
        guard json["success"].boolValue else {
            throw WorkflowyError.apiError(json["error"].stringValue)
        }
        
        var nodes: [WorkflowyNode] = []
        let results = json["results"]
        
        for (_, item) in results {
            if let node = parseNode(from: item) {
                nodes.append(node)
            }
        }
        
        return nodes
    }
    
    func deleteNode(id: String) async throws {
        let url = "\(baseURL)/outline/delete"
        
        let parameters = [
            "projectid": id
        ]
        
        let response = try await AF.request(
            url,
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: ["Authorization": "Bearer \(apiKey)"]
        ).serializingData().value
        
        let json = try JSON(data: response)
        
        guard json["success"].boolValue else {
            throw WorkflowyError.apiError(json["error"].stringValue)
        }
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