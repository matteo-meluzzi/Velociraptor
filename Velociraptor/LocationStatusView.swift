import Combine
import CoreLocation
import SwiftUI

@MainActor
final class LocationStatusViewModel: ObservableObject {
    @Published var isAvailable: Bool = false

    private let authProvider: any AuthorizationProviding
    private var cancellable: AnyCancellable?

    init(_ authProvider: any AuthorizationProviding) {
        self.authProvider = authProvider
        cancellable = authProvider.publisher
            .sink { [weak self] status in
                guard let self else { return }
                switch status {
                case .authorizedWhenInUse, .authorizedAlways:
                    self.isAvailable = true
                case .denied, .restricted:
                    self.isAvailable = false
                default:
                    break
                }
            }
    }
}

struct LocationStatusView: View {
    @ObservedObject var viewModel: LocationStatusViewModel

    var body: some View {
        if !viewModel.isAvailable {
            Text("Location unavailable")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
