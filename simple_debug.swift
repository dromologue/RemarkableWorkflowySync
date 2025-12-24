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

func testRemarkableAPI(token: String) async {
    print("\n🔍 Testing Remarkable 2 API...")
    print("Token: \(token)")
    
    // Try the authentication endpoint
    guard let url = URL(string: "https://webapp-production.remarkable.com/token/json/2/user/new") else {
        print("❌ Invalid URL")
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let deviceID = UUID().uuidString.lowercased()
    let body = [
        "deviceDesc": "desktop-macos",
        "deviceID": deviceID
    ]
    
    do {
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 HTTP Status: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 Response: \(responseString)")
            }
            
            if httpResponse.statusCode == 200 {
                print("✅ Remarkable API connection successful!")
            } else {
                print("❌ Remarkable API failed with status \(httpResponse.statusCode)")
            }
        }
        
    } catch {
        print("❌ Remarkable API error: \(error)")
    }
}

func testWorkflowyAPI(apiKey: String) async {
    print("\n🔍 Testing Workflowy API...")
    print("API Key: \(apiKey)")
    
    // Try getting account info
    guard let url = URL(string: "https://workflowy.com/api/account?api_key=\(apiKey)") else {
        print("❌ Invalid URL")
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 HTTP Status: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 Response: \(responseString)")
            }
            
            if httpResponse.statusCode == 200 {
                print("✅ Workflowy API connection successful!")
            } else {
                print("❌ Workflowy API failed with status \(httpResponse.statusCode)")
                
                // Try alternative endpoint
                await testWorkflowyAlternative(apiKey: apiKey)
            }
        }
        
    } catch {
        print("❌ Workflowy API error: \(error)")
    }
}

func testWorkflowyAlternative(apiKey: String) async {
    print("\n🔄 Testing alternative Workflowy endpoint...")
    
    guard let url = URL(string: "https://workflowy.com/api/v1/account") else {
        print("❌ Invalid URL")
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 Alternative HTTP Status: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 Alternative Response: \(responseString)")
            }
        }
        
    } catch {
        print("❌ Alternative Workflowy API error: \(error)")
    }
}

func testDropboxAPI(accessToken: String) async {
    print("\n🔍 Testing Dropbox API...")
    print("Token: \(String(accessToken.prefix(50)))...")
    
    guard let url = URL(string: "https://api.dropboxapi.com/2/users/get_current_account") else {
        print("❌ Invalid URL")
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 HTTP Status: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 Response: \(responseString)")
            }
            
            if httpResponse.statusCode == 200 {
                print("✅ Dropbox API connection successful!")
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
    print("🚀 Starting Simple API Connection Testing...")
    
    guard let (remarkableToken, workflowyKey, dropboxToken) = loadTokens() else {
        print("❌ Failed to load API tokens")
        exit(1)
    }
    
    print("\n📋 Loaded tokens:")
    print("  Remarkable: \(remarkableToken.isEmpty ? "❌ Empty" : "✅ Loaded (\(remarkableToken.count) chars)")")
    print("  Workflowy: \(workflowyKey.isEmpty ? "❌ Empty" : "✅ Loaded (\(workflowyKey.count) chars)")")
    print("  Dropbox: \(dropboxToken.isEmpty ? "❌ Empty" : "✅ Loaded (\(dropboxToken.count) chars)")")
    
    if !remarkableToken.isEmpty {
        await testRemarkableAPI(token: remarkableToken)
    }
    
    if !workflowyKey.isEmpty {
        await testWorkflowyAPI(apiKey: workflowyKey)
    }
    
    if !dropboxToken.isEmpty {
        await testDropboxAPI(accessToken: dropboxToken)
    }
    
    print("\n🏁 Testing complete!")
    exit(0)
}

RunLoop.main.run()