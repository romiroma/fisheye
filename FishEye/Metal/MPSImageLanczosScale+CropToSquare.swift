//
//  CropToSquare.swift
//  FishEye
//
//  Created by Roman on 17.07.2022.
//

import MetalPerformanceShaders

extension MPSImageLanczosScale {
    func cropToSquare(commandBuffer: MTLCommandBuffer,
                      sourceTexture: MTLTexture,
                      destinationTexture: MTLTexture) {
        let sourceSize: SIMD2<Double> = .init(x: Double(sourceTexture.width), y: Double(sourceTexture.height))
        let destinationSize: SIMD2<Double> = .init(x: Double(destinationTexture.width), y: Double(destinationTexture.height))
        let scale: SIMD2<Double> = .init(x: 1, y: 1)//destinationSize / sourceSize
        let sourceOrigin: SIMD2<Double> = (sourceSize - destinationSize) / 2
        let translate: SIMD2<Double> = -sourceOrigin * scale
        var transform = MPSScaleTransform(scaleX: scale.x, scaleY: scale.y, translateX: translate.x, translateY: translate.y)
        withUnsafePointer(to: &transform) { (transformPtr: UnsafePointer<MPSScaleTransform>) -> () in
            scaleTransform = transformPtr
            encode(commandBuffer: commandBuffer, sourceTexture: sourceTexture, destinationTexture: destinationTexture)
        }
    }
}
