#!/usr/bin/env swift

import Foundation

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

func validateRemarkableToken(token: String) async {
    print("\n🔍 Validating Remarkable 2 Token...")
    print("Token: '\(token)'")
    print("Length: \(token.count) characters")
    
    if token.count < 20 {
        print("⚠️  WARNING: Token appears too short for a valid Remarkable device token")
        print("📝 Device tokens are typically 40+ characters long")
        print("🔗 Get a valid token at: https://remarkable.com/device/desktop/connect")
        return
    }
    
    // Try the correct Remarkable API endpoint
    guard let url = URL(string: "https://document-storage-production.remarkable.com/document-storage/json/2/docs") else {
        print("❌ Invalid URL")
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 HTTP Status: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 Response: \(responseString)")
            }
            
            if httpResponse.statusCode == 200 {
                print("✅ Remarkable API connection successful!")
            } else if httpResponse.statusCode == 401 {
                print("❌ Remarkable API: Unauthorized - Invalid token")
            } else {
                print("❌ Remarkable API failed with status \(httpResponse.statusCode)")
            }
        }
        
    } catch {
        print("❌ Remarkable API error: \(error)")
    }
}

func validateWorkflowyToken(apiKey: String) async {
    print("\n🔍 Validating Workflowy API Key...")
    print("API Key: '\(apiKey)'")
    print("Length: \(apiKey.count) characters")
    
    if apiKey.count != 40 {
        print("⚠️  WARNING: Workflowy API keys are typically 40 characters long")
    }
    
    // Test the correct Workflowy API endpoint
    guard let url = URL(string: "https://workflowy.com/api/outline/") else {
        print("❌ Invalid URL")
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 HTTP Status: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 Response: \(responseString.prefix(500))...")
            }
            
            if httpResponse.statusCode == 200 {
                print("✅ Workflowy API connection successful!")
            } else if httpResponse.statusCode == 401 {
                print("❌ Workflowy API: Unauthorized - Invalid API key")
            } else {
                print("❌ Workflowy API failed with status \(httpResponse.statusCode)")
                
                // Try alternative with query parameter
                await testWorkflowyWithQuery(apiKey: apiKey)
            }
        }
        
    } catch {
        print("❌ Workflowy API error: \(error)")
    }
}

func testWorkflowyWithQuery(apiKey: String) async {
    print("\n🔄 Testing Workflowy with query parameter...")
    
    guard let url = URL(string: "https://workflowy.com/api/outline/?key=\(apiKey)") else {
        print("❌ Invalid URL")
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 Query param HTTP Status: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 Query param Response: \(responseString.prefix(500))...")
            }
            
            if httpResponse.statusCode == 200 {
                print("✅ Workflowy API with query parameter successful!")
            } else {
                print("❌ Both Workflowy methods failed")
                print("🔗 Verify your API key at: https://workflowy.com/api-key")
            }
        }
        
    } catch {
        print("❌ Workflowy query param error: \(error)")
    }
}

func validateDropboxToken(accessToken: String) async {
    print("\n🔍 Validating Dropbox Access Token...")
    print("Token: \(String(accessToken.prefix(50)))...")
    print("Length: \(accessToken.count) characters")
    
    guard let url = URL(string: "https://api.dropboxapi.com/2/users/get_current_account") else {
        print("❌ Invalid URL")
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    // Dropbox expects an empty JSON object for this endpoint
    let emptyBody = "{}"
    request.httpBody = emptyBody.data(using: .utf8)
    
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 HTTP Status: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 Response: \(responseString)")
            }
            
            if httpResponse.statusCode == 200 {
                print("✅ Dropbox API connection successful!")
            } else if httpResponse.statusCode == 401 {
                print("❌ Dropbox API: Unauthorized - Invalid access token")
                print("🔗 Check your token at: https://dropbox.com/developers/apps")
            } else {
                print("❌ Dropbox API failed with status \(httpResponse.statusCode)")
            }
        }
        
    } catch {
        print("❌ Dropbox API error: \(error)")
    }
}

// Main execution
Task {
    print("🚀 Starting API Token Validation...")
    
    guard let (remarkableToken, workflowyKey, dropboxToken) = loadTokens() else {
        print("❌ Failed to load API tokens")
        exit(1)
    }
    
    print("\n📋 Token Summary:")
    print("  Remarkable: \(remarkableToken.isEmpty ? "❌ Empty" : "📝 \(remarkableToken.count) chars")")
    print("  Workflowy: \(workflowyKey.isEmpty ? "❌ Empty" : "📝 \(workflowyKey.count) chars")")  
    print("  Dropbox: \(dropboxToken.isEmpty ? "❌ Empty" : "📝 \(dropboxToken.count) chars")")
    
    if !remarkableToken.isEmpty {
        await validateRemarkableToken(token: remarkableToken)
    }
    
    if !workflowyKey.isEmpty {
        await validateWorkflowyToken(apiKey: workflowyKey)
    }
    
    if !dropboxToken.isEmpty {
        await validateDropboxToken(accessToken: dropboxToken)
    }
    
    print("\n🏁 Validation complete!")
    print("\n📚 Troubleshooting Notes:")
    print("1. Remarkable: Device tokens must be obtained from https://remarkable.com/device/desktop/connect")
    print("2. Workflowy: API keys are found at https://workflowy.com/api-key")
    print("3. Dropbox: Create an app at https://dropbox.com/developers and generate an access token")
    
    exit(0)
}

RunLoop.main.run()