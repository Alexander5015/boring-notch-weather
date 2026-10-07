import ExtensionKit
import NotchTabKit

@objc(BoringNotchWeather)
@main
final class BoringNotchWeather: NSObject, NotchTab {
    @MainActor
    required override init() { super.init() }

    var body: some AppExtensionScene {
        NotchTabScene(size: NotchTabSize(width: 480, height: 110)) {
            WeatherPanel()
        }
        .settings {
            WeatherSettingsScene()
        }
    }
}
