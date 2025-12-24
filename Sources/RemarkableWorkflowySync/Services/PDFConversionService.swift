import Foundation
import PDFKit
import Quartz
import UniformTypeIdentifiers
import WebKit
import AppKit

final class PDFConversionService: @unchecked Sendable {
    private let tempDirectory: URL
    
    init() {
        self.tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RemarkableWorkflowySync")
        
        try? FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
    
    func convertToPDF(remarkableData: Data, documentName: String, documentType: String) async throws -> Data {
        switch documentType.lowercased() {
        case "notebook", "rm":
            return try await convertNotebookToPDF(data: remarkableData, name: documentName)
        case "pdf":
            return remarkableData
        case "epub":
            return try await convertEPUBToPDF(data: remarkableData, name: documentName)
        default:
            throw PDFConversionError.unsupportedFormat(documentType)
        }
    }
    
    private func convertNotebookToPDF(data: Data, name: String) async throws -> Data {
        let tempInputFile = tempDirectory.appendingPathComponent("\(name).rm")
        let tempOutputFile = tempDirectory.appendingPathComponent("\(name).pdf")
        
        defer {
            try? FileManager.default.removeItem(at: tempInputFile)
            try? FileManager.default.removeItem(at: tempOutputFile)
        }
        
        try data.write(to: tempInputFile)
        
        let notebook = try parseRemarkableNotebook(from: data)
        let pdfDocument = try createPDFFromNotebook(notebook, name: name)
        
        guard let pdfData = pdfDocument.dataRepresentation() else {
            throw PDFConversionError.conversionFailed("Failed to create PDF data")
        }
        
        return pdfData
    }
    
    private func convertEPUBToPDF(data: Data, name: String) async throws -> Data {
        let tempInputFile = tempDirectory.appendingPathComponent("\(name).epub")
        let tempOutputFile = tempDirectory.appendingPathComponent("\(name).pdf")
        
        defer {
            try? FileManager.default.removeItem(at: tempInputFile)
            try? FileManager.default.removeItem(at: tempOutputFile)
        }
        
        try data.write(to: tempInputFile)
        
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                do {
                    let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 612, height: 792))
                    webView.loadFileURL(tempInputFile, allowingReadAccessTo: tempInputFile.deletingLastPathComponent())
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        webView.createPDF { result in
                            switch result {
                            case .success(let pdfData):
                                continuation.resume(returning: pdfData)
                            case .failure(let error):
                                continuation.resume(throwing: PDFConversionError.conversionFailed(error.localizedDescription))
                            }
                        }
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func parseRemarkableNotebook(from data: Data) throws -> RemarkableNotebook {
        var notebook = RemarkableNotebook()
        
        let dataReader = BinaryDataReader(data: data)
        
        try dataReader.skipBytes(33)
        
        let pageCount = try dataReader.readUInt32()
        
        for _ in 0..<pageCount {
            var page = RemarkableNotebook.Page()
            
            let layerCount = try dataReader.readUInt32()
            
            for _ in 0..<layerCount {
                var layer = RemarkableNotebook.Layer()
                
                let strokeCount = try dataReader.readUInt32()
                
                for _ in 0..<strokeCount {
                    let stroke = try parseStroke(from: dataReader)
                    layer.strokes.append(stroke)
                }
                
                page.layers.append(layer)
            }
            
            notebook.pages.append(page)
        }
        
        return notebook
    }
    
    private func parseStroke(from reader: BinaryDataReader) throws -> RemarkableNotebook.Stroke {
        var stroke = RemarkableNotebook.Stroke()
        
        let penType = try reader.readUInt32()
        let color = try reader.readUInt32()
        _ = try reader.readUInt32()
        let width = try reader.readFloat()
        _ = try reader.readUInt32()
        
        stroke.pen = RemarkableNotebook.PenType(rawValue: penType) ?? .ballpoint
        stroke.color = RemarkableNotebook.Color(rawValue: color) ?? .black
        stroke.width = width
        
        let pointCount = try reader.readUInt32()
        
        for _ in 0..<pointCount {
            let x = try reader.readFloat()
            let y = try reader.readFloat()
            let pressure = try reader.readFloat()
            let tilt = try reader.readFloat()
            _ = try reader.readFloat()
            _ = try reader.readFloat()
            
            let point = RemarkableNotebook.Point(x: x, y: y, pressure: pressure, tilt: tilt)
            stroke.points.append(point)
        }
        
        return stroke
    }
    
    private func createPDFFromNotebook(_ notebook: RemarkableNotebook, name: String) throws -> PDFDocument {
        let pdfDocument = PDFDocument()
        
        for (pageIndex, page) in notebook.pages.enumerated() {
            let pageRect = CGRect(x: 0, y: 0, width: 1404, height: 1872)
            _ = PDFPage()
            
            let image = NSImage(size: pageRect.size)
            image.lockFocus()
            
            NSColor.white.setFill()
            pageRect.fill()
            
            if let context = NSGraphicsContext.current?.cgContext {
                for layer in page.layers {
                    drawLayer(layer, in: context, pageRect: pageRect)
                }
            }
            
            image.unlockFocus()
            
            let pageWithImage = PDFPage()
            pageWithImage.setBounds(pageRect, for: .mediaBox)
            pdfDocument.insert(pageWithImage, at: pageIndex)
        }
        
        return pdfDocument
    }
    
    private func drawLayer(_ layer: RemarkableNotebook.Layer, in context: CGContext, pageRect: CGRect) {
        for stroke in layer.strokes {
            drawStroke(stroke, in: context, pageRect: pageRect)
        }
    }
    
    private func drawStroke(_ stroke: RemarkableNotebook.Stroke, in context: CGContext, pageRect: CGRect) {
        guard !stroke.points.isEmpty else { return }
        
        context.saveGState()
        
        context.setStrokeColor(stroke.color.cgColor)
        context.setLineWidth(CGFloat(stroke.width))
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        let path = CGMutablePath()
        let firstPoint = stroke.points[0]
        path.move(to: CGPoint(x: CGFloat(firstPoint.x), y: CGFloat(firstPoint.y)))
        
        for point in stroke.points.dropFirst() {
            path.addLine(to: CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)))
        }
        
        context.addPath(path)
        context.strokePath()
        
        context.restoreGState()
    }
}

class BinaryDataReader {
    private let data: Data
    private var offset: Int = 0
    
    init(data: Data) {
        self.data = data
    }
    
    func readUInt32() throws -> UInt32 {
        guard offset + 4 <= data.count else {
            throw PDFConversionError.invalidData
        }
        let value = data.subdata(in: offset..<offset+4).withUnsafeBytes { $0.load(as: UInt32.self) }
        offset += 4
        return value.littleEndian
    }
    
    func readFloat() throws -> Float {
        guard offset + 4 <= data.count else {
            throw PDFConversionError.invalidData
        }
        let value = data.subdata(in: offset..<offset+4).withUnsafeBytes { $0.load(as: Float.self) }
        offset += 4
        return value
    }
    
    func skipBytes(_ count: Int) throws {
        guard offset + count <= data.count else {
            throw PDFConversionError.invalidData
        }
        offset += count
    }
}

struct RemarkableNotebook {
    var pages: [Page] = []
    
    struct Page {
        var layers: [Layer] = []
    }
    
    struct Layer {
        var strokes: [Stroke] = []
    }
    
    struct Stroke {
        var pen: PenType = .ballpoint
        var color: Color = .black
        var width: Float = 1.0
        var points: [Point] = []
    }
    
    struct Point {
        let x: Float
        let y: Float
        let pressure: Float
        let tilt: Float
    }
    
    enum PenType: UInt32 {
        case ballpoint = 0
        case fineliner = 1
        case marker = 2
        case pencil = 3
        case brush = 4
        case highlighter = 5
        case eraser = 6
        case mechanicalPencil = 7
        case pen = 8
    }
    
    enum Color: UInt32 {
        case black = 0
        case gray = 1
        case white = 2
        case yellow = 3
        case green = 4
        case pink = 5
        case blue = 6
        case red = 7
        case grayOverlay = 8
        
        var cgColor: CGColor {
            switch self {
            case .black: return CGColor.black
            case .gray: return CGColor(gray: 0.5, alpha: 1.0)
            case .white: return CGColor.white
            case .yellow: return CGColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 1.0)
            case .green: return CGColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)
            case .pink: return CGColor(red: 1.0, green: 0.75, blue: 0.8, alpha: 1.0)
            case .blue: return CGColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
            case .red: return CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
            case .grayOverlay: return CGColor(gray: 0.7, alpha: 0.5)
            }
        }
    }
}

enum PDFConversionError: Error, LocalizedError {
    case unsupportedFormat(String)
    case conversionFailed(String)
    case invalidData
    case fileNotFound
    
    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let format):
            return "Unsupported file format: \(format)"
        case .conversionFailed(let reason):
            return "PDF conversion failed: \(reason)"
        case .invalidData:
            return "Invalid or corrupted data"
        case .fileNotFound:
            return "File not found"
        }
    }
}