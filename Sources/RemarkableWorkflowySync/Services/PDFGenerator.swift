import Foundation
import PDFKit
import Cocoa

final class PDFGenerator: @unchecked Sendable {
    private let pageSize = CGSize(width: 595, height: 842) // A4 size in points
    private let margins = NSEdgeInsets(top: 50, left: 50, bottom: 50, right: 50)
    
    func generateWorkflowyPDF(from nodes: [WorkflowyNode], title: String = "Workflowy Export") async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                do {
                    let pdfData = try self.createPDFFromNodes(nodes, title: title)
                    continuation.resume(returning: pdfData)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func createPDFFromNodes(_ nodes: [WorkflowyNode], title: String) throws -> Data {
        let pdfDocument = PDFDocument()
        var currentPageIndex = 0
        
        // Create title page
        let titlePage = createTitlePage(title: title, nodeCount: nodes.count)
        pdfDocument.insert(titlePage, at: currentPageIndex)
        currentPageIndex += 1
        
        // Create table of contents
        let tocPages = createTableOfContents(nodes: nodes)
        for tocPage in tocPages {
            pdfDocument.insert(tocPage, at: currentPageIndex)
            currentPageIndex += 1
        }
        
        // Create content pages - each top-level node starts on new page
        for (index, node) in nodes.enumerated() {
            let nodePages = createNodePages(node: node, nodeIndex: index + 1, totalNodes: nodes.count)
            for page in nodePages {
                pdfDocument.insert(page, at: currentPageIndex)
                currentPageIndex += 1
            }
        }
        
        // Add navigation annotations
        addNavigationAnnotations(to: pdfDocument, nodes: nodes)
        
        guard let pdfData = pdfDocument.dataRepresentation() else {
            throw PDFGeneratorError.failedToCreatePDF
        }
        
        return pdfData
    }
    
    private func createTitlePage(title: String, nodeCount: Int) -> PDFPage {
        let page = PDFPage()
        
        // Create attributed string for title page
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 24),
            .foregroundColor: NSColor.black
        ]
        
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16),
            .foregroundColor: NSColor.darkGray
        ]
        
        let titleText = NSMutableAttributedString()
        titleText.append(NSAttributedString(string: "📊 " + title + "\n\n", attributes: titleAttributes))
        titleText.append(NSAttributedString(string: "Generated from Workflowy\n", attributes: subtitleAttributes))
        titleText.append(NSAttributedString(string: "Date: \\(Date().formatted(.dateTime.day().month().year()))\n", attributes: subtitleAttributes))
        titleText.append(NSAttributedString(string: "Total sections: \\(nodeCount)\n\n", attributes: subtitleAttributes))
        titleText.append(NSAttributedString(string: "🚀 Synced via RemarkableWorkflowySync", attributes: subtitleAttributes))
        
        let titleRect = CGRect(
            x: margins.left,
            y: pageSize.height - margins.top - 200,
            width: pageSize.width - margins.left - margins.right,
            height: 200
        )
        
        page.setBounds(CGRect(origin: .zero, size: pageSize), for: .mediaBox)
        
        // Add title to page
        addText(titleText, to: page, in: titleRect)
        
        return page
    }
    
    private func createTableOfContents(nodes: [WorkflowyNode]) -> [PDFPage] {
        var pages: [PDFPage] = []
        let page = PDFPage()
        page.setBounds(CGRect(origin: .zero, size: pageSize), for: .mediaBox)
        
        let tocText = NSMutableAttributedString()
        
        // TOC Header
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 20),
            .foregroundColor: NSColor.black
        ]
        tocText.append(NSAttributedString(string: "📋 Table of Contents\n\n", attributes: headerAttributes))
        
        // TOC Entries
        let entryAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.black
        ]
        
        for (index, node) in nodes.enumerated() {
            let pageNumber = index + 3 // Title page + TOC page + content starts at page 3
            let entry = "\\(index + 1). \\(node.name) .......................... \\(pageNumber)\n"
            tocText.append(NSAttributedString(string: entry, attributes: entryAttributes))
            
            // Add children if they exist
            if let children = node.children {
                for (_, child) in children.enumerated() {
                    let childEntry = "   \\(index + 1).\\(childIndex + 1) \\(child.name)\n"
                    tocText.append(NSAttributedString(string: childEntry, attributes: entryAttributes))
                }
            }
        }
        
        let tocRect = CGRect(
            x: margins.left,
            y: margins.bottom,
            width: pageSize.width - margins.left - margins.right,
            height: pageSize.height - margins.top - margins.bottom
        )
        
        addText(tocText, to: page, in: tocRect)
        pages.append(page)
        
        return pages
    }
    
    private func createNodePages(node: WorkflowyNode, nodeIndex: Int, totalNodes: Int) -> [PDFPage] {
        var pages: [PDFPage] = []
        
        // Create main node page
        let page = PDFPage()
        page.setBounds(CGRect(origin: .zero, size: pageSize), for: .mediaBox)
        
        let contentText = NSMutableAttributedString()
        
        // Header
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 18),
            .foregroundColor: NSColor.black
        ]
        contentText.append(NSAttributedString(string: "\\(nodeIndex). \\(node.name)\n\n", attributes: headerAttributes))
        
        // Note content
        if let note = node.note, !note.isEmpty {
            let noteAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.darkGray
            ]
            contentText.append(NSAttributedString(string: "\\(note)\n\n", attributes: noteAttributes))
        }
        
        // Children content
        if let children = node.children {
            let childAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.black
            ]
            
            for (_, child) in children.enumerated() {
                contentText.append(NSAttributedString(string: "• \\(child.name)\n", attributes: childAttributes))
                
                if let childNote = child.note, !childNote.isEmpty {
                    let childNoteAttributes: [NSAttributedString.Key: Any] = [
                        .font: NSFont.systemFont(ofSize: 10),
                        .foregroundColor: NSColor.gray
                    ]
                    contentText.append(NSAttributedString(string: "  \\(childNote)\n", attributes: childNoteAttributes))
                }
                
                // Recursively add nested children
                if let grandchildren = child.children {
                    addNestedChildren(grandchildren, to: contentText, level: 2)
                }
                contentText.append(NSAttributedString(string: "\n", attributes: childAttributes))
            }
        }
        
        // Footer with navigation
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.lightGray
        ]
        contentText.append(NSAttributedString(string: "\n\n", attributes: footerAttributes))
        
        if nodeIndex > 1 {
            contentText.append(NSAttributedString(string: "← Previous Section | ", attributes: footerAttributes))
        }
        if nodeIndex < totalNodes {
            contentText.append(NSAttributedString(string: "Next Section →", attributes: footerAttributes))
        }
        
        let contentRect = CGRect(
            x: margins.left,
            y: margins.bottom,
            width: pageSize.width - margins.left - margins.right,
            height: pageSize.height - margins.top - margins.bottom
        )
        
        addText(contentText, to: page, in: contentRect)
        pages.append(page)
        
        return pages
    }
    
    private func addNestedChildren(_ children: [WorkflowyNode], to attributedString: NSMutableAttributedString, level: Int) {
        let indent = String(repeating: "  ", count: level)
        
        let childAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: CGFloat(max(8, 12 - level))),
            .foregroundColor: NSColor.black
        ]
        
        for child in children {
            attributedString.append(NSAttributedString(string: "\\(indent)• \\(child.name)\n", attributes: childAttributes))
            
            if let note = child.note, !note.isEmpty {
                let noteAttributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: CGFloat(max(7, 10 - level))),
                    .foregroundColor: NSColor.gray
                ]
                attributedString.append(NSAttributedString(string: "\\(indent)  \\(note)\n", attributes: noteAttributes))
            }
            
            if let grandchildren = child.children {
                addNestedChildren(grandchildren, to: attributedString, level: level + 1)
            }
        }
    }
    
    private func addText(_ attributedString: NSAttributedString, to page: PDFPage, in rect: CGRect) {
        // Create a text annotation for the content
        let annotation = PDFAnnotation(bounds: rect, forType: .freeText, withProperties: nil)
        annotation.contents = attributedString.string
        annotation.font = NSFont.systemFont(ofSize: 12)
        annotation.fontColor = NSColor.black
        page.addAnnotation(annotation)
    }
    
    private func addNavigationAnnotations(to document: PDFDocument, nodes: [WorkflowyNode]) {
        // Add clickable links for navigation between sections
        let tocPageIndex = 1 // Table of contents is on page 1 (0-indexed)
        
        for (nodeIndex, _) in nodes.enumerated() {
            let contentPageIndex = nodeIndex + 2 // Content starts at page 2
            
            if let tocPage = document.page(at: tocPageIndex),
               let contentPage = document.page(at: contentPageIndex) {
                
                // Add link from TOC to content
                let linkRect = CGRect(x: margins.left, y: pageSize.height - margins.top - 100 - CGFloat(nodeIndex * 20), width: 200, height: 15)
                let linkAnnotation = PDFAnnotation(bounds: linkRect, forType: .link, withProperties: nil)
                linkAnnotation.destination = PDFDestination(page: contentPage, at: CGPoint.zero)
                tocPage.addAnnotation(linkAnnotation)
                
                // Add back-to-TOC link from content
                let backLinkRect = CGRect(x: margins.left, y: margins.bottom + 10, width: 100, height: 15)
                let backAnnotation = PDFAnnotation(bounds: backLinkRect, forType: .link, withProperties: nil)
                backAnnotation.destination = PDFDestination(page: tocPage, at: CGPoint.zero)
                contentPage.addAnnotation(backAnnotation)
            }
        }
    }
}

extension PDFGenerator {
    func generateWorkflowyNavigationPDF(from nodes: [WorkflowyNode]) async throws -> Data {
        return try await generateWorkflowyPDF(from: nodes, title: "Workflowy Outline - Complete Export")
    }
}

enum PDFGeneratorError: Error, LocalizedError {
    case failedToCreatePDF
    case invalidNodeStructure
    
    var errorDescription: String? {
        switch self {
        case .failedToCreatePDF:
            return "Failed to create PDF document"
        case .invalidNodeStructure:
            return "Invalid node structure provided"
        }
    }
}