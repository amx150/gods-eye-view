import Foundation
import Combine
@preconcurrency import CoreLocation


struct UserCoordinate: Equatable, Sendable {
    let latitude: Double
    let longitude: Double
}


@MainActor
final class LocationManager:
    NSObject,
    ObservableObject
{
    @Published private(set)
    var coordinate: UserCoordinate?

    @Published private(set)
    var isLocating = false

    @Published private(set)
    var errorMessage: String?

    private let manager = CLLocationManager()


    override init() {
        super.init()

        manager.delegate = self

        manager.desiredAccuracy =
            kCLLocationAccuracyHundredMeters

        manager.distanceFilter = 100
    }


    func requestCurrentLocation() {
        errorMessage = nil

        switch manager.authorizationStatus {

        case .notDetermined:
            manager.requestWhenInUseAuthorization()


        case .authorizedAlways,
             .authorizedWhenInUse:

            isLocating = true
            manager.requestLocation()


        case .denied:
            isLocating = false

            errorMessage =
                "O acesso à localização está desativado."


        case .restricted:
            isLocating = false

            errorMessage =
                "A localização não está disponível neste aparelho."


        @unknown default:
            isLocating = false

            errorMessage =
                "Não foi possível verificar a permissão de localização."
        }
    }
}


extension LocationManager:
    CLLocationManagerDelegate
{
    nonisolated func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {
        let status =
            manager.authorizationStatus

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            switch status {

            case .authorizedAlways,
                 .authorizedWhenInUse:

                self.isLocating = true
                self.manager.requestLocation()


            case .denied:
                self.isLocating = false

                self.errorMessage =
                    "O acesso à localização está desativado."


            case .restricted:
                self.isLocating = false

                self.errorMessage =
                    "A localização não está disponível."


            case .notDetermined:
                break


            @unknown default:
                break
            }
        }
    }


    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location =
            locations.last
        else {
            return
        }

        let newCoordinate =
            UserCoordinate(
                latitude:
                    location.coordinate.latitude,

                longitude:
                    location.coordinate.longitude
            )

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            self.coordinate =
                newCoordinate

            self.isLocating =
                false

            self.errorMessage =
                nil
        }
    }


    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        let code =
            (error as? CLError)?.code

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            self.isLocating = false

            switch code {

            case .locationUnknown:
                self.errorMessage =
                    "Não foi possível obter sua localização agora. Tente novamente."


            case .denied:
                self.errorMessage =
                    "O acesso à localização está desativado."


            case .network:
                self.errorMessage =
                    "Não foi possível obter sua localização por um problema de rede."


            default:
                self.errorMessage =
                    "Não foi possível obter sua localização."
            }
        }
    }
}
