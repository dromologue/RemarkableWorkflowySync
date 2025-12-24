import Foundation

struct APITokenParser {
    static let shared = APITokenParser()
    
    private init() {}
    
    struct ParsedTokens {
        let remarkableToken: String
        let workflowyApiKey: String
        let dropboxAccessToken: String
    }
    
    func loadTokensFromFile() -> ParsedTokens? {
        guard let projectRoot = findProjectRoot() else {
            print("Could not find project root directory")
            return nil
        }
        
        let tokensFilePath = projectRoot.appendingPathComponent("api-tokens.md")
        
        guard FileManager.default.fileExists(atPath: tokensFilePath.path) else {
            print("api-tokens.md file not found at: \(tokensFilePath.path)")
            return nil
        }
        
        do {
            let content = try String(contentsOf: tokensFilePath, encoding: .utf8)
            return parseTokensFromContent(content)
        } catch {
            print("Error reading api-tokens.md file: \(error)")
            return nil
        }
    }
    
    func findProjectRoot() -> URL? {
        let currentDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        
        // Check if we're already in the project root (has Package.swift)
        if FileManager.default.fileExists(atPath: currentDirectory.appendingPathComponent("Package.swift").path) {
            return currentDirectory
        }
        
        // Check common development paths
        let possiblePaths: [URL] = [
            URL(fileURLWithPath: "/Users/dromologue/code/RemarkableWorkflowySync"),
            currentDirectory.appendingPathComponent("../../../").resolvingSymlinksInPath(),
            currentDirectory.appendingPathComponent("../../").resolvingSymlinksInPath(),
            currentDirectory.appendingPathComponent("../").resolvingSymlinksInPath()
        ]
        
        for url in possiblePaths {
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
                return url
            }
        }
        
        return nil
    }
    
    private func parseTokensFromContent(_ content: String) -> ParsedTokens? {
        var remarkableToken = ""
        var workflowyApiKey = ""
        var dropboxAccessToken = ""
        
        // Split content into sections
        let lines = content.components(separatedBy: .newlines)
        var currentSection = ""
        var inCodeBlock = false
        var currentToken = ""
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Detect section headers
            if trimmedLine.contains("## Remarkable 2") {
                currentSection = "remarkable"
                continue
            } else if trimmedLine.contains("## Workflowy") {
                currentSection = "workflowy"
                continue
            } else if trimmedLine.contains("## Dropbox") {
                currentSection = "dropbox"
                continue
            }
            
            // Handle code blocks
            if trimmedLine.hasPrefix("```") {
                if inCodeBlock {
                    // End of code block - save the token
                    let token = currentToken.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !token.isEmpty && !token.hasPrefix("[") {
                        switch currentSection {
                        case "remarkable":
                            remarkableToken = token
                        case "workflowy":
                            workflowyApiKey = token
                        case "dropbox":
                            dropboxAccessToken = token
                        default:
                            break
                        }
                    }
                    currentToken = ""
                    inCodeBlock = false
                } else {
                    // Start of code block
                    inCodeBlock = true
                    currentToken = ""
                }
                continue
            }
            
            // Collect token content inside code blocks
            if inCodeBlock {
                if !currentToken.isEmpty {
                    currentToken += "\n"
                }
                currentToken += trimmedLine
            }
        }
        
        return ParsedTokens(
            remarkableToken: remarkableToken,
            workflowyApiKey: workflowyApiKey,
            dropboxAccessToken: dropboxAccessToken
        )
    }
}