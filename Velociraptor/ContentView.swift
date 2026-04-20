import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = SpeedViewModel(locationProvider: LocationManager())

    var body: some View {
        SpeedView(viewModel: viewModel)
    }
}

#Preview {
    ContentView()
}
