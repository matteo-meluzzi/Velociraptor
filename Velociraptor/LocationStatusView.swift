import Combine
import CoreLocation
import SwiftUI

@MainActor
final class LocationStatusViewModel: ObservableObject {
    @Published var isAvailable: Bool = false

    private let authPublisher: AuthorizationStatusPublisher
    private var cancellable: AnyCancellable?

    init(_ authPublisher: AuthorizationStatusPublisher) {
        self.authPublisher = authPublisher
        cancellable = authPublisher.publisher
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
