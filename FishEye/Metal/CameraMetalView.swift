//
//  CameraMetalView.swift
//  FishEye
//
//  Created by Roman on 17.07.2022.
//

import SwiftUI
import MetalKit

struct CameraMetalView: UIViewRepresentable {

    let coordinator: Coordinator

    func makeCoordinator() -> Coordinator {
        coordinator
    }

    func makeUIView(context: Context) -> MTKView {
        let uiView = MTKView()
        uiView.delegate = context.coordinator
        uiView.preferredFramesPerSecond = 60
        uiView.device = context.coordinator.device
        uiView.framebufferOnly = false
        uiView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        uiView.drawableSize = uiView.frame.size
        return uiView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        uiView.delegate = context.coordinator
        uiView.drawableSize = uiView.frame.size
    }
}

extension CameraMetalView {
    typealias Coordinator = CameraRenderer
}
