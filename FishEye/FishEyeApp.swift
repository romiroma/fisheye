//
//  FishEyeApp.swift
//  FishEye
//
//  Created by Roman on 17.07.2022.
//

import SwiftUI
import AVFoundation

@main
struct FishEyeApp: App {

    private let renderer: CameraRenderer = try! .init(device: MTLCreateSystemDefaultDevice()!)

    var body: some Scene {
        WindowGroup {
            ContentView(cameraSession: .init(sampleBufferDelegate: renderer),
                        cameraRenderer: renderer)
        }
    }
}
