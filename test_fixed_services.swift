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

func testDropboxFixed(accessToken: String) async {
    print("\n🔍 Testing Fixed Dropbox API...")
    
    guard let url = URL(string: "https://api.dropboxapi.com/2/users/get_current_account") else {
        print("❌ Invalid URL")
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    // FIXED: Removed Content-Type header and don't set httpBody
    
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 HTTP Status: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 Response: \(responseString)")
            }
            
            if httpResponse.statusCode == 200 {
                print("✅ Dropbox API connection FIXED and working!")
            } else {
                print("❌ Still failing with status \(httpResponse.statusCode)")
            }
        }
        
    } catch {
        print("❌ Dropbox API error: \(error)")
    }
}

func testWorkflowyFixed(apiKey: String) async {
    print("\n🔍 Testing Fixed Workflowy API...")
    
    // Try the endpoints from our research
    let endpoints = [
        "https://workflowy.com/get_initialization_data",
        "https://workflowy.com/api/beta/get-initialization-data"
    ]
    
    for endpoint in endpoints {
        print("\n🔍 Trying: \(endpoint)")
        
        guard let url = URL(string: "\(endpoint)?api_key=\(apiKey)") else {
            print("❌ Invalid URL")
            continue
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("RemarkableWorkflowySync/1.0", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 Status: \(httpResponse.statusCode)")
                
                if let responseString = String(data: data, encoding: .utf8) {
                    let preview = String(responseString.prefix(200))
                    print("📄 Response: \(preview)...")
                }
                
                if httpResponse.statusCode == 200 {
                    print("✅ Found working Workflowy endpoint!")
                    return
                } else if httpResponse.statusCode == 401 {
                    print("❌ Unauthorized - API key invalid")
                    return
                } else {
                    print("⚠️ Status \(httpResponse.statusCode)")
                }
            }
            
        } catch {
            print("❌ Error: \(error)")
        }
    }
    
    print("❌ All Workflowy endpoints still failing")
}

func validateRemarkableTokenFormat(token: String) {
    print("\n🔍 Validating Remarkable Token Format...")
    print("Token: '\(token)'")
    print("Length: \(token.count) characters")
    
    if token.count < 20 {
        print("❌ INVALID: Token too short")
        print("💡 Action Required:")
        print("   1. Visit https://remarkable.com/device/desktop/connect")
        print("   2. Sign in to your reMarkable account")
        print("   3. Get your actual device token (40+ characters)")
        print("   4. Replace '\(token)' in api-tokens.md with the real token")
    } else {
        print("✅ Token length looks valid")
        print("💡 Try running the app - it should now validate the token properly")
    }
}

// Main execution
Task {
    print("🔧 Testing Fixed API Services...")
    
    guard let (remarkableToken, workflowyKey, dropboxToken) = loadTokens() else {
        print("❌ Failed to load API tokens")
        exit(1)
    }
    
    print("\n📋 Testing Results:")
    
    // Test each fixed service
    if !remarkableToken.isEmpty {
        validateRemarkableTokenFormat(token: remarkableToken)
    }
    
    if !workflowyKey.isEmpty {
        await testWorkflowyFixed(apiKey: workflowyKey)
    }
    
    if !dropboxToken.isEmpty {
        await testDropboxFixed(accessToken: dropboxToken)
    }
    
    print("\n📝 Summary of Fixes:")
    print("1. ✅ Dropbox: Removed Content-Type header - should now work")
    print("2. ⚠️ Workflowy: Updated endpoints based on API research")
    print("3. ⚠️ Remarkable: Added token validation with helpful error messages")
    print("4. 🎯 Next: Get a real Remarkable device token to test full functionality")
    
    exit(0)
}

RunLoop.main.run()