import SwiftUI

struct MacrosPage: View {
    var body: some View {
        ContentUnavailableView(
            "Macros Are Coming Soon", systemImage: "record.circle",
            description: Text("Recording macros and assigning them to keys will arrive in a later version. Keys and lighting work today."))
            .navigationTitle("Macros")
    }
}
