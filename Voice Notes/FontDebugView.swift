import SwiftUI

// MARK: - Font Debug View for Testing
struct FontDebugView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Font Debug Information")
                    .font(.title)
                    .padding(.bottom)
                
                Group {
                    Text("System Fonts Available:")
                        .font(.headline)
                    
                    Text("Available font families:")
                        .font(.subheadline)
                    
                    ForEach(UIFont.familyNames.sorted(), id: \.self) { family in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(family)
                                .font(.body)
                                .bold()
                            
                            ForEach(UIFont.fontNames(forFamilyName: family), id: \.self) { fontName in
                                Text("  • \(fontName)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Divider()
                    .padding(.vertical)
                
                Group {
                    Text("Poppins Font Tests:")
                        .font(.headline)
                    
                    Text("Voice Notes (Should be Poppins Bold)")
                        .font(.poppins.bold(size: 36))
                        .background(Color.yellow.opacity(0.3))
                    
                    Text("Recent Recordings (Should be Poppins SemiBold)")
                        .font(.poppins.semiBold(size: 22))
                        .background(Color.green.opacity(0.3))
                    
                    Text("Regular Text (Should be Poppins Regular)")
                        .font(.poppins.regular(size: 17))
                        .background(Color.blue.opacity(0.3))
                    
                    Text("System Font for Comparison")
                        .font(.system(size: 17))
                        .background(Color.red.opacity(0.3))
                }
                
                Divider()
                    .padding(.vertical)
                
                Group {
                    Text("Custom Font Loading Tests:")
                        .font(.headline)
                    
                    Text("Poppins-Regular Direct Test")
                        .font(Font.custom("Poppins-Regular", size: 17))
                        .background(Color.orange.opacity(0.3))
                    
                    Text("Poppins-Bold Direct Test")
                        .font(Font.custom("Poppins-Bold", size: 17))
                        .background(Color.purple.opacity(0.3))
                    
                    Text("Poppins-SemiBold Direct Test")
                        .font(Font.custom("Poppins-SemiBold", size: 17))
                        .background(Color.pink.opacity(0.3))
                }
            }
            .padding()
        }
        .navigationTitle("Font Debug")
        .onAppear {
            printAvailableFonts()
        }
    }
    
    private func printAvailableFonts() {
        print("=== Available Font Families ===")
        for family in UIFont.familyNames.sorted() {
            if family.lowercased().contains("poppins") {
                print("FOUND POPPINS: \(family)")
                for font in UIFont.fontNames(forFamilyName: family) {
                    print("  - \(font)")
                }
            }
        }
        
        print("=== Direct Font Tests ===")
        let testFonts = [
            "Poppins-Regular",
            "Poppins-Bold", 
            "Poppins-SemiBold",
            "Poppins-Medium",
            "Poppins-Light"
        ]
        
        for fontName in testFonts {
            if let font = UIFont(name: fontName, size: 17) {
                print("✅ \(fontName) - LOADED")
            } else {
                print("❌ \(fontName) - FAILED")
            }
        }
    }
}

#Preview {
    NavigationView {
        FontDebugView()
    }
}