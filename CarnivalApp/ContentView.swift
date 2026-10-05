import CarnivalKit
import SwiftUI

/// Shows `CarnivalView`, or a simple error message if `Carnival`'s GPU
/// setup failed (`Carnival.rendererError`). `CarnivalKit` deliberately has
/// no opinion on how to surface that failure -- this is the app's own
/// choice for how to handle it.
struct ContentView: View {
    let carnival: Carnival

    var body: some View {
        if let rendererError = carnival.rendererError {
            ContentUnavailableView(
                "Unable to Show the Carnival",
                systemImage: "exclamationmark.triangle",
                description: Text(String(describing: rendererError))
            )
        } else {
            CarnivalView(carnival: carnival)
        }
    }
}
