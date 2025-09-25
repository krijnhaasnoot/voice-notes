import Foundation
import UIKit
import PDFKit

class PDFGenerator {
    
    static func generatePDF(for recording: Recording, includeTranscript: Bool = true) -> Data? {
        let pageSize = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let renderer = UIGraphicsPDFRenderer(bounds: pageSize)
        
        return renderer.pdfData { context in
            var currentY: CGFloat = 60 // Top margin
            let leftMargin: CGFloat = 60
            let rightMargin: CGFloat = 60
            let contentWidth = pageSize.width - leftMargin - rightMargin
            
            context.beginPage()
            
            // Helper function to add text with word wrapping
            func addText(_ text: String, font: UIFont, color: UIColor = .black, y: inout CGFloat, lineSpacing: CGFloat = 4) -> CGFloat {
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineSpacing = lineSpacing
                paragraphStyle.alignment = .left
                
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color,
                    .paragraphStyle: paragraphStyle
                ]
                
                let attributedString = NSAttributedString(string: text, attributes: attributes)
                let textRect = CGRect(x: leftMargin, y: y, width: contentWidth, height: pageSize.height - y - 60)
                
                attributedString.draw(in: textRect)
                
                let textSize = attributedString.boundingRect(
                    with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                ).size
                
                y += textSize.height + 20
                
                // Check if we need a new page
                if y > pageSize.height - 100 {
                    context.beginPage()
                    y = 60
                }
                
                return y
            }
            
            // Header with app branding
            let headerFont = UIFont.systemFont(ofSize: 24, weight: .bold)
            let headerColor = UIColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0) // Blue
            addText("Voice Notes", font: headerFont, color: headerColor, y: &currentY)
            
            // Title
            let title = !recording.title.isEmpty ? recording.title : recording.fileName
            let titleFont = UIFont.systemFont(ofSize: 18, weight: .semibold)
            // Clean up title for display
            let displayTitle = title.replacingOccurrences(of: ".m4a", with: "")
                                   .replacingOccurrences(of: ".wav", with: "")
                                   .replacingOccurrences(of: ".mp3", with: "")
            addText(displayTitle, font: titleFont, y: &currentY)
            
            // Date and metadata
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .full
            dateFormatter.timeStyle = .short
            let dateText = "Recorded: \(dateFormatter.string(from: recording.date))"
            
            var metadataLines = [dateText]
            if recording.duration > 0 {
                let minutes = Int(recording.duration / 60)
                let seconds = Int(recording.duration.truncatingRemainder(dividingBy: 60))
                metadataLines.append("Duration: \(minutes)m \(seconds)s")
            }
            
            // Add detected mode if available
            if let detectedMode = recording.detectedMode, !detectedMode.isEmpty {
                metadataLines.append("Mode: \(detectedMode)")
            }
            
            let metadataFont = UIFont.systemFont(ofSize: 12, weight: .regular)
            let metadataColor = UIColor.gray
            addText(metadataLines.joined(separator: "\n"), font: metadataFont, color: metadataColor, y: &currentY)
            
            // Add separator line
            currentY += 10
            let lineY = currentY
            let linePath = UIBezierPath()
            linePath.move(to: CGPoint(x: leftMargin, y: lineY))
            linePath.addLine(to: CGPoint(x: pageSize.width - rightMargin, y: lineY))
            UIColor.lightGray.setStroke()
            linePath.lineWidth = 1
            linePath.stroke()
            currentY += 20
            
            // AI Summary Section
            if let summary = recording.summary, !summary.isEmpty {
                let summaryHeaderFont = UIFont.systemFont(ofSize: 16, weight: .semibold)
                addText("AI Summary", font: summaryHeaderFont, color: headerColor, y: &currentY)
                
                let summaryFont = UIFont.systemFont(ofSize: 14, weight: .regular)
                let cleanSummary = prettifyMarkdownToPlain(summary)
                addText(cleanSummary, font: summaryFont, y: &currentY, lineSpacing: 6)
            }
            
            // Transcript Section (if requested and available)
            if includeTranscript, let transcript = recording.transcript, !transcript.isEmpty {
                // Add some space before transcript
                currentY += 10
                
                let transcriptHeaderFont = UIFont.systemFont(ofSize: 16, weight: .semibold)
                addText("Transcript", font: transcriptHeaderFont, color: headerColor, y: &currentY)
                
                let transcriptFont = UIFont.systemFont(ofSize: 12, weight: .regular)
                addText(transcript, font: transcriptFont, y: &currentY, lineSpacing: 4)
            }
            
            // Footer
            let footerY = pageSize.height - 40
            let footerText = "Generated by Voice Notes"
            let footerFont = UIFont.systemFont(ofSize: 10, weight: .regular)
            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: footerFont,
                .foregroundColor: UIColor.lightGray
            ]
            
            let footerString = NSAttributedString(string: footerText, attributes: footerAttributes)
            let footerSize = footerString.size()
            let footerX = (pageSize.width - footerSize.width) / 2
            footerString.draw(at: CGPoint(x: footerX, y: footerY))
        }
    }
    
    static func savePDFToDocuments(_ pdfData: Data, fileName: String) -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let pdfURL = documentsPath.appendingPathComponent("\(fileName).pdf")
        
        do {
            try pdfData.write(to: pdfURL)
            return pdfURL
        } catch {
            print("Error saving PDF: \(error)")
            return nil
        }
    }
}

