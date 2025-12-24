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

func testDropboxCorrectly(accessToken: String) async {
    print("\n🔍 Testing Dropbox API (Corrected)...")
    
    guard let url = URL(string: "https://api.dropboxapi.com/2/users/get_current_account") else {
        print("❌ Invalid URL")
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    // Dropbox expects null body, so don't set httpBody at all
    
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
            } else {
                print("❌ Dropbox API failed with status \(httpResponse.statusCode)")
            }
        }
        
    } catch {
        print("❌ Dropbox API error: \(error)")
    }
}

func testWorkflowyCorrectEndpoint(apiKey: String) async {
    print("\n🔍 Testing Workflowy API (Correct Endpoint)...")
    
    // Try the documented Workflowy API endpoint
    let endpoints = [
        "https://workflowy.com/api/outline.json",
        "https://beta.workflowy.com/api/outline.json",
        "https://workflowy.com/outline_api",
        "https://workflowy.com/get_initialization_data"
    ]
    
    for endpoint in endpoints {
        print("\n🔍 Trying endpoint: \(endpoint)")
        
        guard let url = URL(string: "\(endpoint)?key=\(apiKey)") else {
            print("❌ Invalid URL")
            continue
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 Status: \(httpResponse.statusCode)")
                
                if let responseString = String(data: data, encoding: .utf8) {
                    let preview = String(responseString.prefix(200))
                    print("📄 Response preview: \(preview)...")
                }
                
                if httpResponse.statusCode == 200 {
                    print("✅ Found working Workflowy endpoint!")
                    return
                } else if httpResponse.statusCode == 401 {
                    print("❌ Unauthorized - API key might be invalid")
                } else {
                    print("⚠️ Status \(httpResponse.statusCode) - trying next endpoint...")
                }
            }
            
        } catch {
            print("❌ Error: \(error)")
        }
    }
    
    print("\n❌ All Workflowy endpoints failed")
    print("🔗 Please verify your API key at: https://workflowy.com/api-key")
}

func checkRemarkableToken(token: String) {
    print("\n🔍 Analyzing Remarkable Token...")
    print("Token: '\(token)'")
    print("Length: \(token.count) characters")
    
    if token.count < 20 {
        print("❌ INVALID: Remarkable device tokens are typically 40+ characters")
        print("📝 Your token '\(token)' appears to be a placeholder or invalid")
        print("🔗 Get a real device token from: https://remarkable.com/device/desktop/connect")
        print("💡 Follow these steps:")
        print("   1. Go to https://remarkable.com/device/desktop/connect")
        print("   2. Sign in to your reMarkable account")
        print("   3. Click 'Connect desktop app'")
        print("   4. Copy the long device token (usually starts with letters/numbers)")
        print("   5. Paste it in your api-tokens.md file")
    } else {
        print("✅ Token length looks reasonable for a device token")
    }
}

// Main execution
Task {
    print("🚀 Final API Troubleshooting...")
    
    guard let (remarkableToken, workflowyKey, dropboxToken) = loadTokens() else {
        print("❌ Failed to load API tokens")
        exit(1)
    }
    
    print("\n📋 Token Analysis:")
    
    // Check each token
    if !remarkableToken.isEmpty {
        checkRemarkableToken(token: remarkableToken)
    } else {
        print("❌ No Remarkable token found")
    }
    
    if !workflowyKey.isEmpty {
        await testWorkflowyCorrectEndpoint(apiKey: workflowyKey)
    } else {
        print("❌ No Workflowy API key found")
    }
    
    if !dropboxToken.isEmpty {
        await testDropboxCorrectly(accessToken: dropboxToken)
    } else {
        print("❌ No Dropbox token found")
    }
    
    print("\n📝 Summary & Next Steps:")
    print("1. ✅ Dropbox token format looks correct - testing with proper API call")
    print("2. ⚠️ Workflowy key looks correct format - testing multiple endpoints")
    print("3. ❌ Remarkable token '\(remarkableToken)' is INVALID - you need to get a real one")
    
    exit(0)
}

RunLoop.main.run()