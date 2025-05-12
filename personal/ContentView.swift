//
//  ContentView.swift
//  personal
//
//  Created by Bryan Gan on 5/12/25.
//

import SwiftUI

struct ContentView: View {
    @State private var currentTime = Date()
    @State private var selectedTab: Int = 0
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    enum SectionType: Hashable {
        case clock, web, weather
    }
    let allSections: [SectionType] = [.clock, .web, .weather]
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
                    .rotationEffect(secondAngle(date: currentTime))
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
    // Displays Philadelphia weather via a simple web widget
    private let weatherURL = URL(string: "https://wttr.in/Philadelphia?format=%l:+%t+%C")!

    var body: some View {
        WebView(url: weatherURL)
    }
}

#Preview {
    ContentView()
}
