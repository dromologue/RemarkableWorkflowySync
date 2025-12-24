import XCTest
import PDFKit
@testable import RemarkableWorkflowySync

final class PDFGeneratorTests: XCTestCase {
    
    var pdfGenerator: PDFGenerator!
    
    override func setUpWithError() throws {
        pdfGenerator = PDFGenerator()
    }
    
    override func tearDownWithError() throws {
        pdfGenerator = nil
    }
    
    func testGeneratePDFFromSimpleNodes() async throws {
        // Given: Simple test nodes
        let nodes = createTestNodes()
        
        // When: Generate PDF
        let pdfData = try await pdfGenerator.generateWorkflowyPDF(from: nodes, title: "Test Export")
        
        // Then: PDF should be created successfully
        XCTAssertFalse(pdfData.isEmpty, "PDF data should not be empty")
        
        let pdfDocument = PDFDocument(data: pdfData)
        XCTAssertNotNil(pdfDocument, "PDF document should be created")
        XCTAssertGreaterThan(pdfDocument!.pageCount, 2, "PDF should have at least 3 pages (title + TOC + content)")
    }
    
    func testGeneratePDFWithHierarchicalNodes() async throws {
        // Given: Hierarchical test nodes with children
        let nodes = createHierarchicalTestNodes()
        
        // When: Generate PDF
        let pdfData = try await pdfGenerator.generateWorkflowyNavigationPDF(from: nodes)
        
        // Then: PDF should contain all levels of hierarchy
        XCTAssertFalse(pdfData.isEmpty)
        
        let pdfDocument = PDFDocument(data: pdfData)
        XCTAssertNotNil(pdfDocument)
        
        // Should have title page + TOC + one page per top-level node
        let expectedPageCount = 2 + nodes.count // title + TOC + content pages
        XCTAssertGreaterThanOrEqual(pdfDocument!.pageCount, expectedPageCount)
    }
    
    func testPDFContainsExpectedContent() async throws {
        // Given: Nodes with specific content
        let testNode = WorkflowyNode(
            id: "test-1",
            name: "Test Node with Special Content",
            note: "This is a test note with important information",
            parentId: nil,
            children: [
                WorkflowyNode(id: "child-1", name: "Child Node", note: "Child note", parentId: "test-1", children: nil)
            ]
        )
        let nodes = [testNode]

        // When: Generate PDF
        let pdfData = try await pdfGenerator.generateWorkflowyPDF(from: nodes, title: "Content Test")

        // Then: PDF should contain the expected content in annotations
        let pdfDocument = PDFDocument(data: pdfData)!

        // Extract text from all annotations across pages
        var allAnnotationText = ""
        for pageIndex in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: pageIndex) {
                for annotation in page.annotations {
                    if let contents = annotation.contents {
                        allAnnotationText += contents + " "
                    }
                }
            }
        }

        XCTAssertTrue(allAnnotationText.contains("Test Node with Special Content"), "PDF should contain node name")
        XCTAssertTrue(allAnnotationText.contains("This is a test note"), "PDF should contain node note")
        XCTAssertTrue(allAnnotationText.contains("Child Node"), "PDF should contain child node")
        XCTAssertTrue(allAnnotationText.contains("Table of Contents"), "PDF should contain TOC")
    }
    
    func testPDFNavigationAnnotations() async throws {
        // Given: Multiple nodes for navigation testing
        let nodes = createTestNodes()
        
        // When: Generate PDF with navigation
        let pdfData = try await pdfGenerator.generateWorkflowyNavigationPDF(from: nodes)
        
        // Then: PDF should contain navigation annotations
        let pdfDocument = PDFDocument(data: pdfData)!
        
        // Check that TOC page has link annotations
        if let tocPage = pdfDocument.page(at: 1) { // TOC is typically page 1
            let annotations = tocPage.annotations
            let linkAnnotations = annotations.filter { $0.type == "Link" }
            XCTAssertGreaterThan(linkAnnotations.count, 0, "TOC should have navigation links")
        }
    }
    
    func testEmptyNodesHandling() async throws {
        // Given: Empty nodes array
        let nodes: [WorkflowyNode] = []
        
        // When: Generate PDF
        let pdfData = try await pdfGenerator.generateWorkflowyPDF(from: nodes, title: "Empty Test")
        
        // Then: PDF should still be created with title and empty TOC
        XCTAssertFalse(pdfData.isEmpty)
        
        let pdfDocument = PDFDocument(data: pdfData)
        XCTAssertNotNil(pdfDocument)
        XCTAssertGreaterThanOrEqual(pdfDocument!.pageCount, 2) // At least title + TOC
    }
    
    func testPDFWithDeepNesting() async throws {
        // Given: Deeply nested nodes
        let deeplyNestedNodes = createDeeplyNestedTestNodes()

        // When: Generate PDF
        let pdfData = try await pdfGenerator.generateWorkflowyPDF(from: deeplyNestedNodes, title: "Deep Nesting Test")

        // Then: PDF should handle deep nesting gracefully
        XCTAssertFalse(pdfData.isEmpty)

        let pdfDocument = PDFDocument(data: pdfData)!

        // Extract text from all annotations
        var fullText = ""
        for pageIndex in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: pageIndex) {
                for annotation in page.annotations {
                    if let contents = annotation.contents {
                        fullText += contents + " "
                    }
                }
            }
        }

        XCTAssertTrue(fullText.contains("Level 1"), "Should contain top level")
        XCTAssertTrue(fullText.contains("Level 2"), "Should contain second level")
        XCTAssertTrue(fullText.contains("Level 3"), "Should contain third level")
    }
    
    func testPDFTitlePageGeneration() async throws {
        // Given: Custom title
        let customTitle = "My Custom Workflowy Export"
        let nodes = createTestNodes()

        // When: Generate PDF with custom title
        let pdfData = try await pdfGenerator.generateWorkflowyPDF(from: nodes, title: customTitle)

        // Then: Title page should contain custom title (check via annotations)
        let pdfDocument = PDFDocument(data: pdfData)!
        let titlePage = pdfDocument.page(at: 0)!

        // Extract text from annotations
        var titlePageText = ""
        for annotation in titlePage.annotations {
            if let contents = annotation.contents {
                titlePageText += contents + " "
            }
        }

        XCTAssertTrue(titlePageText.contains(customTitle), "Title page should contain custom title")
        XCTAssertTrue(titlePageText.contains("Generated from Workflowy"), "Title page should contain source info")
        XCTAssertTrue(titlePageText.contains("RemarkableWorkflowySync"), "Title page should contain app name")
    }
    
    func testPDFTableOfContentsGeneration() async throws {
        // Given: Known node names
        let node1 = WorkflowyNode(id: "1", name: "First Section", note: nil, parentId: nil, children: nil)
        let node2 = WorkflowyNode(id: "2", name: "Second Section", note: nil, parentId: nil, children: nil)
        let nodes = [node1, node2]

        // When: Generate PDF
        let pdfData = try await pdfGenerator.generateWorkflowyPDF(from: nodes, title: "TOC Test")

        // Then: TOC should list all sections (check via annotations since text is added as annotations)
        let pdfDocument = PDFDocument(data: pdfData)!
        let tocPage = pdfDocument.page(at: 1)! // TOC is page 1

        // Extract text from annotations
        var tocText = ""
        for annotation in tocPage.annotations {
            if let contents = annotation.contents {
                tocText += contents + " "
            }
        }

        XCTAssertTrue(tocText.contains("Table of Contents"), "Should have TOC header")
        XCTAssertTrue(tocText.contains("First Section"), "Should list first section")
        XCTAssertTrue(tocText.contains("Second Section"), "Should list second section")
        XCTAssertTrue(tocText.contains("1."), "Should have section numbering")
        XCTAssertTrue(tocText.contains("2."), "Should have section numbering")
    }
    
    // MARK: - Performance Tests
    
    func testPDFGenerationPerformance() async throws {
        // Given: Large number of nodes
        let largeNodeSet = createLargeTestNodeSet(count: 50)
        
        // When/Then: Measure PDF generation performance
        let startTime = Date()
        _ = try await pdfGenerator.generateWorkflowyPDF(from: largeNodeSet, title: "Performance Test")
        let endTime = Date()
        
        let duration = endTime.timeIntervalSince(startTime)
        XCTAssertLessThan(duration, 10.0, "PDF generation should complete within 10 seconds")
    }
    
    // MARK: - Helper Methods
    
    private func createTestNodes() -> [WorkflowyNode] {
        return [
            WorkflowyNode(
                id: "1",
                name: "Project Planning",
                note: "Main project planning section",
                parentId: nil,
                children: [
                    WorkflowyNode(id: "1.1", name: "Research Phase", note: "Initial research", parentId: "1", children: nil),
                    WorkflowyNode(id: "1.2", name: "Development Phase", note: "Main development", parentId: "1", children: nil)
                ]
            ),
            WorkflowyNode(
                id: "2",
                name: "Meeting Notes",
                note: "Notes from various meetings",
                parentId: nil,
                children: [
                    WorkflowyNode(id: "2.1", name: "Daily Standups", note: "Daily meeting notes", parentId: "2", children: nil)
                ]
            )
        ]
    }
    
    private func createHierarchicalTestNodes() -> [WorkflowyNode] {
        return [
            WorkflowyNode(
                id: "hierarchical-1",
                name: "Main Topic",
                note: "This is the main topic with lots of subtopics",
                parentId: nil,
                children: [
                    WorkflowyNode(
                        id: "h-1.1",
                        name: "Subtopic A",
                        note: "First subtopic",
                        parentId: "hierarchical-1",
                        children: [
                            WorkflowyNode(id: "h-1.1.1", name: "Sub-subtopic A1", note: "Detailed notes", parentId: "h-1.1", children: nil),
                            WorkflowyNode(id: "h-1.1.2", name: "Sub-subtopic A2", note: "More details", parentId: "h-1.1", children: nil)
                        ]
                    ),
                    WorkflowyNode(
                        id: "h-1.2",
                        name: "Subtopic B",
                        note: "Second subtopic",
                        parentId: "hierarchical-1",
                        children: nil
                    )
                ]
            )
        ]
    }
    
    private func createDeeplyNestedTestNodes() -> [WorkflowyNode] {
        let level3 = WorkflowyNode(id: "level3", name: "Level 3 Node", note: "Deep nested content", parentId: "level2", children: nil)
        let level2 = WorkflowyNode(id: "level2", name: "Level 2 Node", note: "Nested content", parentId: "level1", children: [level3])
        let level1 = WorkflowyNode(id: "level1", name: "Level 1 Node", note: "Top level content", parentId: nil, children: [level2])
        
        return [level1]
    }
    
    private func createLargeTestNodeSet(count: Int) -> [WorkflowyNode] {
        return (1...count).map { index in
            WorkflowyNode(
                id: "node-\(index)",
                name: "Test Node \(index)",
                note: "This is test node number \(index) with some content",
                parentId: nil,
                children: index % 3 == 0 ? [
                    WorkflowyNode(id: "child-\(index)", name: "Child of \(index)", note: nil, parentId: "node-\(index)", children: nil)
                ] : nil
            )
        }
    }
}