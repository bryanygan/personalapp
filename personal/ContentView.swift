//
//  ContentView.swift
//  personal
//
//  Created by Bryan Gan on 5/12/25.
//

import SwiftUI

struct ContentView: View {
    @State private var currentTime = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Clock Section
                ClockView(currentTime: currentTime)
                    .frame(width: geometry.size.width / 2)
                
                // WebView Section
                WebView(url: URL(string: "https://apple.com")!)
                    .frame(width: geometry.size.width / 2)
            }
        }
        .onReceive(timer) { input in
            currentTime = input
        }
        .previewInterfaceOrientation(.landscapeLeft)
    }
}

struct ClockView: View {
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

#Preview {
    ContentView()
}
