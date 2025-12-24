import Foundation
import PDFKit

final class SimplePDFService: @unchecked Sendable {
    func createPDFFromText(_ text: String, title: String) -> Data? {
        let pdfDocument = PDFDocument()
        
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let pdfPage = PDFPage()
        pdfPage.setBounds(pageRect, for: .mediaBox)
        
        let textAnnotation = PDFAnnotation(bounds: pageRect, forType: .freeText, withProperties: nil)
        textAnnotation.contents = text
        textAnnotation.font = NSFont.systemFont(ofSize: 12)
        pdfPage.addAnnotation(textAnnotation)
        
        pdfDocument.insert(pdfPage, at: 0)
        
        return pdfDocument.dataRepresentation()
    }
}