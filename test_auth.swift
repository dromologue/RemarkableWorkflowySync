#!/usr/bin/env swift

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// Simple test script to verify Remarkable and Workflowy authentication

print("🧪 Testing API Authentication")
print(String(repeating: "=", count: 50))

// Test Remarkable Registration
func testRemarkableRegistration() async {
    print("\n📱 Testing Remarkable Registration...")
    
    let code = "qcstowjc" // Your 8-character code
    let url = "https://webapp-production-dot-remarkable-production.appspot.com/token/json/2/device/new"
    let deviceID = UUID().uuidString
    
    let requestBody: [String: Any] = [
        "code": code,
        "deviceDesc": "desktop-windows",
        "deviceID": deviceID
    ]
    
    do {
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        print("🔄 Making request to: \(url)")
        print("🆔 Device ID: \(deviceID)")
        print("🔑 Code: \(code)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📡 HTTP Status: \(httpResponse.statusCode)")
        }
        
        let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode"
        print("📝 Response: \(responseString)")
        
        if !responseString.isEmpty && !responseString.contains("error") && !responseString.contains("<html") {
            print("✅ Remarkable registration appears successful!")
        } else {
            print("❌ Remarkable registration failed")
        }
        
    } catch {
        print("❌ Remarkable test error: \(error)")
    }
}

// Test Workflowy API
func testWorkflowyAPI() async {
    print("\n🌊 Testing Workflowy API...")
    
    let username = "dromologue@gmail.com" // Your username
    let apiKey = "cf5a1fc04b7a17388d630d875a498e6aff6afda9" // Your API key
    
    let endpoints = [
        "https://workflowy.com/api/v1/targets",                     // Official API - check access
        "https://workflowy.com/api/v1/nodes?target=inbox&limit=3"   // Official API - test data access
    ]
    
    for url in endpoints {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("RemarkableWorkflowySync/1.0", forHTTPHeaderField: "User-Agent")
        
        do {
            print("🔄 Making request to: \(url)")
            print("👤 Username: \(username)")
            print("🔑 API Key: \(apiKey.prefix(8))...")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 HTTP Status: \(httpResponse.statusCode)")
            }
            
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode"
            print("📝 Response: \(responseString.prefix(300))...")
            
            let httpStatusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            
            if responseString.contains("<!DOCTYPE html>") {
                print("❌ Endpoint \(url) returned HTML (likely 404)")
                continue
            }
            
            if responseString.contains("email") || responseString.contains("username") || responseString.contains("projectTreeData") || responseString.contains("globals") || httpStatusCode == 200 {
                print("✅ Workflowy API access successful via \(url)!")
                return // Exit after first successful endpoint
            } else {
                print("❌ Workflowy API endpoint \(url) failed")
            }
            
        } catch {
            print("❌ Workflowy endpoint \(url) error: \(error)")
        }
    }
    
    print("❌ All Workflowy endpoints failed")
}

// Run tests
Task {
    await testRemarkableRegistration()
    await testWorkflowyAPI()
    print("\n🏁 Test completed")
    exit(0)
}

RunLoop.main.run()