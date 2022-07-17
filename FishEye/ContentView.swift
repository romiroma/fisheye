//
//  ContentView.swift
//  FishEye
//
//  Created by Roman on 17.07.2022.
//

import SwiftUI
import AVFoundation

struct ContentView: View {

    let cameraSession: CameraSession
    @ObservedObject var cameraRenderer: CameraRenderer

    var body: some View {
        ZStack {
            CameraMetalView(coordinator: cameraRenderer)
            CameraSessionView(session: cameraSession)
            VStack {
                Spacer()
                Slider(value: .init(get: {
                    cameraRenderer.fisheyeModifier
                }, set: { n in
                    cameraRenderer.fisheyeModifier = n
                }),
                       in: 0...1)
            }

        }
    }
}
