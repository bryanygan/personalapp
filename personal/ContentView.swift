//
//  ContentView.swift
//  personal
//
//  Created by Bryan Gan on 5/12/25.
//


import SwiftUI

// MARK: - Tomorrow.io Weather Models & ViewModel

struct TomorrowResponse: Codable {
    let data: TimelinesData
}
struct TimelinesData: Codable {
    let timelines: [Timeline]
}
struct Timeline: Codable {
    let timestep: String
    let intervals: [Interval]
}
struct Interval: Codable {
    let startTime: String
    let values: Values
}
struct Values: Codable {
    let temperature: Double
    let weatherCode: Int
    let temperatureMin: Double?
    let temperatureMax: Double?
    let precipitationProbability: Int?
}

struct Weather: Identifiable {
    let id = UUID()
    let date: Date
    let temperature: Double
    let condition: String
}

struct DailyWeather: Identifiable {
    let id = UUID()
    let date: Date
    let minTemp: Double
    let maxTemp: Double
    let precipitationProbability: Int?
    let condition: String
}

@MainActor
class WeatherViewModel: ObservableObject {
    @Published var currentWeather: Weather?
    @Published var hourlyForecast: [Weather] = []
    @Published var dailyForecast: [DailyWeather] = []

    private let apiKey = "ckqLXmq5V19LL4JtMIuQg86xDqtaDVXC"
    private let location = "39.9526,-75.1652" // Philadelphia, PA
    private let fields = ["temperature", "weatherCode", "temperatureMin", "temperatureMax", "precipitationProbability"]
    private let timesteps = ["current", "1h", "1d"]
    private let units = "imperial"

    func fetchWeather() async {
        var components = URLComponents(string: "https://api.tomorrow.io/v4/timelines")!
        components.queryItems = [
            URLQueryItem(name: "location", value: location),
            URLQueryItem(name: "fields", value: fields.joined(separator: ",")),
            URLQueryItem(name: "timesteps", value: timesteps.joined(separator: ",")),
            URLQueryItem(name: "units", value: units),
            URLQueryItem(name: "apikey", value: apiKey)
        ]

        guard let url = components.url else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let resp = try JSONDecoder().decode(TomorrowResponse.self, from: data)
            if let currentTimeline = resp.data.timelines.first(where: { $0.timestep == "current" }),
               let currentInterval = currentTimeline.intervals.first {
                let date = ISO8601DateFormatter().date(from: currentInterval.startTime) ?? Date()
                let condition = mapWeatherCode(currentInterval.values.weatherCode)
                currentWeather = Weather(date: date,
                                         temperature: currentInterval.values.temperature,
                                         condition: condition)
            }
            if let hourlyTimeline = resp.data.timelines.first(where: { $0.timestep == "1h" }) {
                let now = Date()
                let startOfToday = Calendar.current.startOfDay(for: now)
                // Extend hourly data through 3AM next day
                let cutoff = Calendar.current.date(byAdding: .hour, value: 27, to: startOfToday)!
                hourlyForecast = hourlyTimeline.intervals.compactMap { interval in
                    guard let date = ISO8601DateFormatter().date(from: interval.startTime) else { return nil }
                    let condition = mapWeatherCode(interval.values.weatherCode)
                    return Weather(date: date,
                                   temperature: interval.values.temperature,
                                   condition: condition)
                }
                .filter { $0.date >= now && $0.date < cutoff }
            }
            if let dailyTimeline = resp.data.timelines.first(where: { $0.timestep == "1d" }) {
                dailyForecast = dailyTimeline.intervals.compactMap { interval in
                    guard let date = ISO8601DateFormatter().date(from: interval.startTime) else { return nil }
                    let min = interval.values.temperatureMin ?? 0
                    let max = interval.values.temperatureMax ?? 0
                    let precip = interval.values.precipitationProbability
                    let condition = mapWeatherCode(interval.values.weatherCode)
                    return DailyWeather(date: date, minTemp: min, maxTemp: max, precipitationProbability: precip, condition: condition)
                }
            }
        } catch {
            print("Weather fetch error:", error)
        }
    }

    private func mapWeatherCode(_ code: Int) -> String {
        switch code {
        case 1000: return "Clear"
        case 1100: return "Mostly Clear"
        case 1101: return "Partly Cloudy"
        case 1102: return "Mostly Cloudy"
        case 1001: return "Cloudy"
        case 2000: return "Fog"
        case 2100: return "Light Fog"
        case 4000: return "Drizzle"
        case 4001: return "Rain"
        case 4200: return "Light Rain"
        case 4201: return "Heavy Rain"
        case 5000: return "Snow"
        case 5001: return "Flurries"
        case 5100: return "Light Snow"
        case 5101: return "Heavy Snow"
        case 6000: return "Freezing Drizzle"
        case 6001: return "Freezing Rain"
        case 6200: return "Light Freezing Rain"
        case 6201: return "Heavy Freezing Rain"
        case 7000: return "Ice Pellets"
        case 7101: return "Heavy Ice Pellets"
        case 7102: return "Light Ice Pellets"
        case 8000: return "Thunderstorm"
        default: return "Unknown"
        }
    }
}

struct ContentView: View {
    @State private var currentTime = Date()
    @State private var selectedTab: Int = 0
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var timerDuration: TimeInterval = 60
    @State private var isTimerRunning = false
    @State private var lastSetDuration: TimeInterval = 60
    @State private var timerActive: Bool = false
    
    enum SectionType: Hashable {
        case clock, web, weather, timer
    }
    let allSections: [SectionType] = [.clock, .web, .weather, .timer]
    @State private var selectedLeft: SectionType = .clock
    @State private var selectedRight: SectionType = .web
    
    @ViewBuilder
    private func viewFor(_ section: SectionType, geometry: GeometryProxy) -> some View {
        switch section {
        case .clock:
            ClockView(currentTime: currentTime)
        case .web:
            WebView(url: URL(string: "https://apple.com")!)
        case .weather:
            WeatherView()
        case .timer:
            if timerActive {
                ZStack {
                    Color.black.ignoresSafeArea()
                    VStack(spacing: 24) {
                        // Format remaining time
                        let totalSeconds = Int(timerDuration)
                        let hrs = totalSeconds / 3600
                        let mins = (totalSeconds % 3600) / 60
                        let secs = totalSeconds % 60
                        let timeString = totalSeconds >= 3600
                            ? String(format: "%d:%02d:%02d", hrs, mins, secs)
                            : String(format: "%02d:%02d", mins, secs)
                        Text(timeString)
                            .font(.system(size: 72, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        HStack(spacing: 40) {
                            Button("Pause") {
                                isTimerRunning = false
                            }
                            Button("Cancel") {
                                isTimerRunning = false
                                timerActive = false
                                timerDuration = lastSetDuration
                            }
                        }
                        .font(.title2)
                        .foregroundColor(.white)
                    }
                }
            } else {
                VStack(spacing: 16) {
                    // Compute formatted duration string
                    let totalSeconds = Int(timerDuration)
                    let hrs = totalSeconds / 3600
                    let mins = (totalSeconds % 3600) / 60
                    let secs = totalSeconds % 60
                    let formatted = "\(hrs) hours, \(String(format: "%02d", mins)) minutes, \(String(format: "%02d", secs)) seconds"

                    Text("Countdown:")
                        .font(.title2)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                    Text(formatted)
                        .font(.title2)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)

                    TimerView(duration: $timerDuration)
                        .frame(maxWidth: .infinity, maxHeight: 200)
                    HStack(spacing: 40) {
                        Button("Start") {
                            lastSetDuration = timerDuration
                            isTimerRunning = true
                            timerActive = true
                        }
                        Button("Cancel") {
                            isTimerRunning = false
                            timerDuration = lastSetDuration
                        }
                    }
                    .font(.headline)
                }
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left swipe area
                TabView(selection: $selectedLeft) {
                    ForEach(allSections, id: \.self) { section in
                        viewFor(section, geometry: geometry)
                            .frame(width: geometry.size.width / 2, height: geometry.size.height)
                            .tag(section)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))

                // Right swipe area: exclude left selection
                TabView(selection: $selectedRight) {
                    ForEach(allSections.filter { $0 != selectedLeft }, id: \.self) { section in
                        viewFor(section, geometry: geometry)
                            .frame(width: geometry.size.width / 2, height: geometry.size.height)
                            .tag(section)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
            }
        }
        .ignoresSafeArea()
        .onReceive(timer) { input in
            currentTime = input
            if isTimerRunning && timerDuration > 0 {
                timerDuration -= 1
            } else if timerDuration <= 0 {
                isTimerRunning = false
            }
        }
        .onChange(of: selectedLeft) { newLeft in
            // Ensure right is not the same as left
            if selectedRight == newLeft {
                selectedRight = allSections.first { $0 != newLeft }!
            }
        }
        .previewInterfaceOrientation(.landscapeLeft)
    }
}

struct ClockView: View {
    // Formatter to display digital time without AM/PM
    private let digitalFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return f
    }()
    let currentTime: Date

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Clock face
                Circle()
                    .fill(Color.clear)
                    .overlay(
                        Circle().stroke(Color.white, lineWidth: 4)
                    )
                // Hour marks
                ForEach(0..<12) { tick in
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 2, height: geometry.size.width * 0.05)
                        .offset(y: -geometry.size.width * 0.35)
                        .rotationEffect(.degrees(Double(tick) * 30))
                }
                // Hour hand
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 6, height: geometry.size.width * 0.18)
                    .offset(y: -geometry.size.width * 0.09)
                    .rotationEffect(hourAngle(date: currentTime))
                // Minute hand
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 4, height: geometry.size.width * 0.28)
                    .offset(y: -geometry.size.width * 0.14)
                    .rotationEffect(minuteAngle(date: currentTime))
                // Second hand
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 2, height: geometry.size.width * 0.35)
                    .offset(y: -geometry.size.width * 0.175)
                    .rotationEffect(.degrees(currentTime.timeIntervalSinceReferenceDate * 6))
                    .animation(.linear(duration: 1), value: currentTime)
                // Center circle
                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
            }
            .frame(width: min(geometry.size.width, geometry.size.height) * 0.8,
                   height: min(geometry.size.width, geometry.size.height) * 0.8)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            .background(Color.black)
            .overlay(
                Text(currentTime, formatter: digitalFormatter)
                    .font(.system(size: geometry.size.width * 0.05, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .offset(x: 0, y: min(geometry.size.width, geometry.size.height) * 0.08)
            )
        }
    }

    // Helper functions for hand angles
    private func hourAngle(date: Date) -> Angle {
        let calendar = Calendar.current
        let hour = Double(calendar.component(.hour, from: date) % 12)
        let minute = Double(calendar.component(.minute, from: date))
        return .degrees((hour + minute / 60) * 30)
    }

    private func minuteAngle(date: Date) -> Angle {
        let calendar = Calendar.current
        let minute = Double(calendar.component(.minute, from: date))
        let second = Double(calendar.component(.second, from: date))
        return .degrees((minute + second / 60) * 6)
    }

    private func secondAngle(date: Date) -> Angle {
        let calendar = Calendar.current
        let second = Double(calendar.component(.second, from: date))
        return .degrees(second * 6)
    }
}

struct WeatherView: View {
    @StateObject private var vm = WeatherViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let current = vm.currentWeather {
                Text("Now: \(Int(current.temperature))°F, \(current.condition)")
                    .font(.title2)
                    .bold()
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            } else {
                Text("Loading current weather...")
                    .font(.title2)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(vm.hourlyForecast) { hour in
                        VStack {
                            Text(hour.date, style: .time)
                                .font(.caption)
                            Text("\(Int(hour.temperature))°")
                                .font(.headline)
                            Text(hour.condition)
                                .font(.caption2)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 8)
                        .frame(width: 60)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
            }
            Divider().padding(.vertical, 8)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Text("Day")
                        .font(.caption)
                        .frame(width: 60, alignment: .leading)
                    Text("Condition")
                        .font(.caption)
                        .frame(width: 80, alignment: .leading)
                    Text("Precip")
                        .font(.caption2)
                        .frame(width: 50, alignment: .leading)
                    Text("Low")
                        .font(.caption2)
                        .frame(width: 40, alignment: .leading)
                    Text("High")
                        .font(.caption2)
                        .frame(width: 40, alignment: .trailing)
                }
                ForEach(vm.dailyForecast) { day in
                    HStack(spacing: 12) {
                        Text(day.date, format: .dateTime.weekday(.abbreviated))
                            .frame(width: 60, alignment: .leading)
                        Text(day.condition)
                            .font(.caption)
                            .frame(width: 80, alignment: .leading)
                        if let precip = day.precipitationProbability {
                            Text("\(precip)%")
                                .font(.caption2)
                                .frame(width: 50, alignment: .leading)
                        }
                        Text("\(Int(day.minTemp))°")
                            .font(.caption2)
                            .frame(width: 40, alignment: .leading)
                        Text("\(Int(day.maxTemp))°")
                            .font(.headline)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding()
        .task {
            await vm.fetchWeather()
        }
    }
}

// MARK: - Built-In Countdown Timer View

struct TimerView: UIViewRepresentable {
    @Binding var duration: TimeInterval

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .countDownTimer
        picker.addTarget(context.coordinator,
                         action: #selector(Coordinator.timeChanged(_:)),
                         for: .valueChanged)
        return picker
    }

    func updateUIView(_ uiView: UIDatePicker, context: Context) {
        uiView.countDownDuration = duration
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: TimerView
        init(_ parent: TimerView) {
            self.parent = parent
        }
        @objc func timeChanged(_ picker: UIDatePicker) {
            parent.duration = picker.countDownDuration
        }
    }
}

#Preview {
    ContentView()
}
