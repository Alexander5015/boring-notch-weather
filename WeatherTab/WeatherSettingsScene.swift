import SwiftUI

struct WeatherSettingsScene: View {

    @State private var settings = WeatherSettingsModel()
    @State private var location = LocationProvider()

    var body: some View {
        Form {
            locationSection
            if settings.locationSource == .fixed {
                FixedLocationSection(settings: settings)
            }
            displaySection
            detailSection
            if settings.isModified {
                Section {
                    Button("Reset All Settings") { settings.reset() }
                        .foregroundStyle(.red)
                } footer: {
                    Text("Restores every setting to its default.")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 620)
        .task {
            settings.reload()
            if settings.locationSource == .automatic {
                location.request()
            }
        }
    }

    private var locationSection: some View {
        Section("Location") {
            Picker("Source", selection: $settings.locationSource) {
                ForEach(LocationSource.allCases) { source in
                    Text(source.label).tag(source)
                }
            }
            .pickerStyle(.segmented)

            if settings.locationSource == .automatic {
                LabeledContent("Permission") {
                    HStack(spacing: 6) {
                        Text(permissionLabel)
                            .foregroundStyle(location.access.isUsable ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.orange))
                        if !location.access.isUsable, location.access != .denied {
                            Button("Allow") { location.request() }
                                .buttonStyle(.link)
                        }
                    }
                }
            }
        }
    }

    private var displaySection: some View {
        Section("Display") {
            Picker("Units", selection: $settings.units) {
                ForEach(UnitSystem.allCases) { unit in
                    Text(unit.label).tag(unit)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var detailSection: some View {
        Section("Weather Details") {
            ForEach(TabDetail.allCases) { detail in
                Toggle(detail.label, isOn: detailBinding(detail))
            }
        }
    }

    private func detailBinding(_ detail: TabDetail) -> Binding<Bool> {
        Binding(
            get: { settings.isEnabled(detail) },
            set: { settings.set(detail, enabled: $0) }
        )
    }

    private var permissionLabel: String {
        switch location.access {
        case .notRequested: "Not requested"
        case .pending: "Waiting…"
        case .denied: "Denied"
        case .authorized: "Allowed"
        case .searching: "Locating…"
        case .failed: "Unavailable"
        }
    }
}

private struct FixedLocationSection: View {

    @Bindable var settings: WeatherSettingsModel
    @State private var query = ""
    @State private var results: [Place] = []
    @State private var searching = false
    @State private var failed: String?
    @State private var task: Task<Void, Never>?

    var body: some View {
        Section("Fixed Location") {
            HStack {
                TextField("Search for a place", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await runSearch() } }
                    .onChange(of: query) { _, _ in scheduleSearch() }
                if searching { ProgressView().controlSize(.small) }
            }

            if let failed {
                Text(failed)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            ForEach(results) { place in
                Button {
                    settings.choose(place)
                    query = place.name
                    results = []
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(place.name)
                            if let subtitle = place.subtitle {
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "arrow.down.circle")
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Stepper(value: $settings.fixedLatitude, in: -90...90, step: 0.25) {
                LabeledContent("Latitude") {
                    Text(settings.fixedLatitude.formatted(.number.precision(.fractionLength(2))))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            Stepper(value: $settings.fixedLongitude, in: -180...180, step: 0.25) {
                LabeledContent("Longitude") {
                    Text(settings.fixedLongitude.formatted(.number.precision(.fractionLength(2))))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            LabeledContent("Forecast for") {
                Text(settings.fixedLocationDescription)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func scheduleSearch() {
        task?.cancel()
        results = []
        failed = nil
        guard query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else { return }
        task = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await runSearch()
        }
    }

    private func runSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return }
        searching = true
        defer { searching = false }
        do {
            let found = try await PlaceSearch.search(trimmed)
            guard !Task.isCancelled else { return }
            results = found
            failed = found.isEmpty ? "No places matched “\(trimmed)”." : nil
        } catch {
            guard !Task.isCancelled else { return }
            results = []
            failed = error.localizedDescription
        }
    }
}
