import SwiftUI

struct LargeTitleProbe: View {
    var body: some View {
        TabView {
            NavigationStack {
                List(0..<30) { i in
                    NavigationLink("Row \(i)", destination: Text("Detail \(i)").navigationBarTitleDisplayMode(.inline))
                }
                .navigationTitle("Probe A")
                .navigationBarTitleDisplayMode(.large)
                .toolbar(.visible, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
            }
            .tabItem { Label("A", systemImage: "1.circle") }

            NavigationStack {
                ScrollView { Text("Hello") }
                .navigationTitle("Probe B")
                .navigationBarTitleDisplayMode(.large)
                .toolbar(.visible, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
            }
            .tabItem { Label("B", systemImage: "2.circle") }
        }
    }
}

#Preview {
    LargeTitleProbe()
}