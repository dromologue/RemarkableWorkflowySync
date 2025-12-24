#!/usr/bin/env swift

import Foundation
import Alamofire
import SwiftyJSON

struct APIDebugger {
    
    static func testRemarkableConnection(token: String) async {
        print("\n🔍 Testing Remarkable 2 API Connection...")
        print("Token: \(token)")
        
        // Test 1: Authentication
        await testRemarkableAuth(token: token)
        
        // Test 2: Document listing (if auth works)
        await testRemarkableDocuments(token: token)
    }
    
    static func testRemarkableAuth(token: String) async {
        print("\n📋 Testing Remarkable Authentication...")
        
        let url = "https://webapp-production.remarkable.com/token/json/2/user/new"
        
        let parameters: [String: Any] = [
            "deviceDesc": "desktop-macos",
            "deviceID": generateDeviceID()
        ]
        
        do {
            let response = try await AF.request(
                url,
                method: .post,
                parameters: parameters,
                encoding: JSONEncoding.default,
                headers: [
                    "Authorization": "Bearer \(token)"
                ]
            ).serializingData().value
            
            let json = try JSON(data: response)
            print("✅ Authentication Response: \(json)")
            
            if json.isEmpty {
                print("⚠️ Empty response - this may indicate an invalid token")
            }
        } catch {
            print("❌ Authentication failed: \(error)")
            if let afError = error as? AFError {
                print("   AFError details: \(afError.localizedDescription)")
                if let underlyingError = afError.underlyingError {
                    print("   Underlying error: \(underlyingError)")
                }
            }
        }
    }
    
    static func testRemarkableDocuments(token: String) async {
        print("\n📄 Testing Remarkable Document Listing...")
        
        let url = "https://document-storage-production.remarkable.com/document-storage/json/2/docs"
        
        do {
            let response = try await AF.request(
                url,
                method: .get,
                headers: [
                    "Authorization": "Bearer \(token)"
                ]
            ).serializingData().value
            
            let json = try JSON(data: response)
            print("✅ Documents Response: \(json)")
            
            if let documents = json.array {
                print("📊 Found \(documents.count) documents")
            }
        } catch {
            print("❌ Document listing failed: \(error)")
        }
    }
    
    static func testWorkflowyConnection(apiKey: String) async {
        print("\n🔍 Testing Workflowy API Connection...")
        print("API Key: \(apiKey)")
        
        // Test different Workflowy endpoints
        await testWorkflowyAuth(apiKey: apiKey)
        await testWorkflowyNodes(apiKey: apiKey)
    }
    
    static func testWorkflowyAuth(apiKey: String) async {
        print("\n🔐 Testing Workflowy Authentication...")
        
        let url = "https://workflowy.com/api/v1/account"
        
        do {
            let response = try await AF.request(
                url,
                method: .get,
                headers: [
                    "Authorization": "Bearer \(apiKey)",
                    "Content-Type": "application/json"
                ]
            ).serializingData().value
            
            let json = try JSON(data: response)
            print("✅ Account Response: \(json)")
        } catch {
            print("❌ Authentication failed: \(error)")
            
            // Try alternative authentication method
            await testWorkflowyAlternativeAuth(apiKey: apiKey)
        }
    }
    
    static func testWorkflowyAlternativeAuth(apiKey: String) async {
        print("\n🔄 Testing alternative Workflowy authentication...")
        
        let url = "https://workflowy.com/api/account"
        
        do {
            let response = try await AF.request(
                url,
                method: .get,
                parameters: ["api_key": apiKey],
                headers: [
                    "Content-Type": "application/json"
                ]
            ).serializingData().value
            
            let json = try JSON(data: response)
            print("✅ Alternative auth response: \(json)")
        } catch {
            print("❌ Alternative authentication failed: \(error)")
        }
    }
    
    static func testWorkflowyNodes(apiKey: String) async {
        print("\n🌳 Testing Workflowy Nodes...")
        
        let url = "https://workflowy.com/api/v1/nodes"
        
        do {
            let response = try await AF.request(
                url,
                method: .get,
                headers: [
                    "Authorization": "Bearer \(apiKey)",
                    "Content-Type": "application/json"
                ]
            ).serializingData().value
            
            let json = try JSON(data: response)
            print("✅ Nodes Response: \(json)")
        } catch {
            print("❌ Nodes request failed: \(error)")
        }
    }
    
    static func testDropboxConnection(accessToken: String) async {
        print("\n🔍 Testing Dropbox API Connection...")
        print("Access Token: \(String(accessToken.prefix(50)))...")
        
        await testDropboxAccount(accessToken: accessToken)
        await testDropboxSpace(accessToken: accessToken)
    }
    
    static func testDropboxAccount(accessToken: String) async {
        print("\n👤 Testing Dropbox Account Info...")
        
        let url = "https://api.dropboxapi.com/2/users/get_current_account"
        
        do {
            let response = try await AF.request(
                url,
                method: .post,
                headers: [
                    "Authorization": "Bearer \(accessToken)",
                    "Content-Type": "application/json"
                ]
            ).serializingData().value
            
            let json = try JSON(data: response)
            print("✅ Account Response: \(json)")
            
            if let accountId = json["account_id"].string {
                print("📋 Account ID: \(accountId)")
            }
        } catch {
            print("❌ Account request failed: \(error)")
            if let afError = error as? AFError {
                print("   Status code: \(afError.responseCode ?? -1)")
            }
        }
    }
    
    static func testDropboxSpace(accessToken: String) async {
        print("\n💾 Testing Dropbox Space Usage...")
        
        let url = "https://api.dropboxapi.com/2/users/get_space_usage"
        
        do {
            let response = try await AF.request(
                url,
                method: .post,
                headers: [
                    "Authorization": "Bearer \(accessToken)",
                    "Content-Type": "application/json"
                ]
            ).serializingData().value
            
            let json = try JSON(data: response)
            print("✅ Space Usage Response: \(json)")
        } catch {
            print("❌ Space usage request failed: \(error)")
        }
    }
    
    static func generateDeviceID() -> String {
        return UUID().uuidString.lowercased()
    }
}

// Load tokens from api-tokens.md
func loadTokens() -> (String, String, String)? {
    let fileURL = URL(fileURLWithPath: "/Users/dromologue/code/RemarkableWorkflowySync/api-tokens.md")
    
    guard let content = try? String(contentsOf: fileURL) else {
        print("❌ Could not read api-tokens.md file")
        return nil
    }
    
    var remarkableToken = ""
    var workflowyKey = ""
    var dropboxToken = ""
    
    let lines = content.components(separatedBy: .newlines)
    var currentSection = ""
    var inCodeBlock = false
    var currentToken = ""
    
    for line in lines {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        
        if trimmedLine.contains("## Remarkable 2") {
            currentSection = "remarkable"
        } else if trimmedLine.contains("## Workflowy") {
            currentSection = "workflowy"
        } else if trimmedLine.contains("## Dropbox") {
            currentSection = "dropbox"
        }
        
        if trimmedLine.hasPrefix("```") {
            if inCodeBlock {
                let token = currentToken.trimmingCharacters(in: .whitespacesAndNewlines)
                if !token.isEmpty && !token.hasPrefix("[") {
                    switch currentSection {
                    case "remarkable": remarkableToken = token
                    case "workflowy": workflowyKey = token
                    case "dropbox": dropboxToken = token
                    default: break
                    }
                }
                currentToken = ""
                inCodeBlock = false
            } else {
                inCodeBlock = true
                currentToken = ""
            }
        } else if inCodeBlock {
            if !currentToken.isEmpty {
                currentToken += "\n"
            }
            currentToken += trimmedLine
        }
    }
    
    return (remarkableToken, workflowyKey, dropboxToken)
}

// Main execution
Task {
    print("🚀 Starting API Connection Debugging...")
    
    guard let (remarkableToken, workflowyKey, dropboxToken) = loadTokens() else {
        print("❌ Failed to load API tokens")
        exit(1)
    }
    
    print("\n📋 Loaded tokens:")
    print("  Remarkable: \(remarkableToken.isEmpty ? "❌ Empty" : "✅ Loaded")")
    print("  Workflowy: \(workflowyKey.isEmpty ? "❌ Empty" : "✅ Loaded")")
    print("  Dropbox: \(dropboxToken.isEmpty ? "❌ Empty" : "✅ Loaded")")
    
    if !remarkableToken.isEmpty {
        await APIDebugger.testRemarkableConnection(token: remarkableToken)
    }
    
    if !workflowyKey.isEmpty {
        await APIDebugger.testWorkflowyConnection(apiKey: workflowyKey)
    }
    
    if !dropboxToken.isEmpty {
        await APIDebugger.testDropboxConnection(accessToken: dropboxToken)
    }
    
    print("\n🏁 Debugging complete!")
}

// Keep the script running
RunLoop.main.run()