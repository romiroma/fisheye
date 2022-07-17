//
//  CameraRenderer.swift
//  FishEye
//
//  Created by Roman on 17.07.2022.
//

import Foundation
import AVFoundation
import MetalKit
import MetalPerformanceShaders

final class CameraRenderer: NSObject, ObservableObject {

    enum Error: Swift.Error {
        case couldntCreateCache
        case couldntCreateCommandQueue
    }

    let device: MTLDevice
    @Published var fisheyeModifier: Float = 0.5 {
        didSet {
            fisheye.modifier = fisheyeModifier
        }
    }
    private let commandQueue: MTLCommandQueue

    private var texture: MTLTexture? {
        didSet {
            texture.map {
                setupTransform(withWidth: $0.width, height: $0.height)
            }
        }
    }
    private var vertexCoordinateBuffer: MTLBuffer?
    private var textureCoordinateBuffer: MTLBuffer?
    private var frameSize: CGSize = .zero
    private var lastFrameSize: CGSize = .zero

    private var textureWidth: Int = 0
    private var textureHeight: Int = 0

    private var frontCamera: Bool = false // for internal drawing
    private var tempFrontCamera: Bool = false // for external setter

    private var textureMirroring: Bool = false // for internal drawing
    private var tempTextureMirroring: Bool = false // for external setter

    private var textureRotation: TextureRotation = .rotate0Degrees // for internal drawing
    private var tempTextureRotation: TextureRotation = .rotate0Degrees // for external setter

    private var textureContentMode: TextureContentMode = .aspectRatioFit // for internal drawing
    private var tempTextureContentMode: TextureContentMode = .aspectRatioFit // for external setter
    private let lock: DispatchSemaphore
    private let textureCache: CVMetalTextureCache
    private let renderPipeline: MTLRenderPipelineState
    
    private let fisheye: Fisheye
    private let lanchos: MPSImageLanczosScale

    private let textureDescriptor: MTLTextureDescriptor = {
        let tD = MTLTextureDescriptor()
        tD.pixelFormat = .bgra8Unorm
        tD.mipmapLevelCount = 1
        tD.textureType = .type2D
        tD.usage = [.shaderRead, .shaderWrite]
        return tD
    }()

    enum TextureRotation {
        case rotate0Degrees
        case rotate90Degrees
        case rotate180Degrees
        case rotate270Degrees
    }

    enum TextureContentMode {
        case aspectRatioFill
        case aspectRatioFit
        case stretch
    }

    init(device metalDevice: MTLDevice) throws {
        lock = DispatchSemaphore(value: 1)
        device = metalDevice
        guard let queue = device.makeCommandQueue() else {
            throw Error.couldntCreateCommandQueue
        }
        commandQueue = queue
        fisheye = try .init(device)
        lanchos = .init(device: device)

        let library = try device.makeDefaultLibrary(bundle: .main)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "TexturePipeline"
        descriptor.vertexFunction = library.makeFunction(name: "vertexPassThrough")!
        descriptor.fragmentFunction = library.makeFunction(name: "fragmentPassThrough")!
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        renderPipeline = try device.makeRenderPipelineState(descriptor: descriptor)

        let textureAgeKey = kCVMetalTextureCacheMaximumTextureAgeKey as NSString
        let textureAgeValue = NSNumber(value: 1)
        let options = [textureAgeKey: textureAgeValue] as NSDictionary

        var videoTextureCache: CVMetalTextureCache! = nil
        let status = CVMetalTextureCacheCreate(kCFAllocatorDefault,
                                               options,
                                               device,
                                               nil,
                                               &videoTextureCache)
        if status != kCVReturnSuccess {
            throw Error.couldntCreateCache
        }
        textureCache = videoTextureCache
    }
}

extension CameraRenderer: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let sourceTexture = sampleBuffer.imageBuffer?.metalTexture(using: textureCache, pixelFormat: .bgra8Unorm) else {
            return
        }
        let smallerSide = min(sourceTexture.width, sourceTexture.height)
        textureDescriptor.height = smallerSide
        textureDescriptor.width = smallerSide
        guard let croppedTexture = device.makeTexture(descriptor: textureDescriptor) else {
            return
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        lanchos.cropToSquare(commandBuffer: commandBuffer, sourceTexture: sourceTexture, destinationTexture: croppedTexture)
        guard let destinationTexture = device.makeTexture(descriptor: textureDescriptor) else {
            return
        }
        fisheye.encode(commandBuffer: commandBuffer, sourceTexture: croppedTexture, destinationTexture: destinationTexture)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        texture = destinationTexture
    }
}

// Rendering part of code taken from BBMetalImage's (no link in my clipboard :) BBMetalView

extension CameraRenderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        frameSize = view.frame.size
    }

    func draw(in view: MTKView) {
        guard let vBuffer = vertexCoordinateBuffer, let tBuffer = textureCoordinateBuffer else { return }
        guard let texture = texture,
              let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        view.drawableSize = .init(width: texture.width, height: texture.height)
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        commandBuffer.label = "CameraRendererBuffer"
        encoder.label = "CameraRendererEncoder"
        encoder.setRenderPipelineState(renderPipeline)
        encoder.setVertexBuffer(vBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(tBuffer, offset: 0, index: 1)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func setupTransform(withWidth width: Int, height: Int) {
        lastFrameSize = frameSize
        textureWidth = width
        textureHeight = height
        frontCamera = tempFrontCamera
        textureMirroring = tempTextureMirroring
        textureRotation = tempTextureRotation
        textureContentMode = tempTextureContentMode

        var scaleX: Float = 1
        var scaleY: Float = 1

        if textureContentMode != .stretch {
            if textureWidth > 0 && textureHeight > 0 {
                switch textureRotation {
                case .rotate0Degrees, .rotate180Degrees:
                    scaleX = Float(lastFrameSize.width / CGFloat(textureWidth))
                    scaleY = Float(lastFrameSize.height / CGFloat(textureHeight))

                case .rotate90Degrees, .rotate270Degrees:
                    scaleX = Float(lastFrameSize.width / CGFloat(textureHeight))
                    scaleY = Float(lastFrameSize.height / CGFloat(textureWidth))
                }
            }

            if scaleX < scaleY {
                if textureContentMode == .aspectRatioFill {
                    scaleX = scaleY / scaleX
                    scaleY = 1
                } else {
                    scaleY = scaleX / scaleY
                    scaleX = 1
                }
            } else {
                if textureContentMode == .aspectRatioFill {
                    scaleY = scaleX / scaleY
                    scaleX = 1
                } else {
                    scaleX = scaleY / scaleX
                    scaleY = 1
                }
            }
        }

        if textureMirroring != frontCamera { scaleX = -scaleX }

        let vertexData: [Float] = [
            -scaleX, -scaleY,
             +scaleX, -scaleY,
             -scaleX, +scaleY,
             +scaleX, +scaleY,
        ]
        vertexCoordinateBuffer = device.makeBuffer(bytes: vertexData, length: vertexData.count * MemoryLayout<Float>.size, options: [])

        var textData: [Float]
        switch textureRotation {
        case .rotate0Degrees:
            textData = [
                0.0, 1.0,
                1.0, 1.0,
                0.0, 0.0,
                1.0, 0.0
            ]
        case .rotate180Degrees:
            textData = [
                1.0, 0.0,
                0.0, 0.0,
                1.0, 1.0,
                0.0, 1.0
            ]
        case .rotate90Degrees:
            textData = [
                1.0, 1.0,
                1.0, 0.0,
                0.0, 1.0,
                0.0, 0.0
            ]
        case .rotate270Degrees:
            textData = [
                0.0, 0.0,
                0.0, 1.0,
                1.0, 0.0,
                1.0, 1.0
            ]
        }
        textureCoordinateBuffer = device.makeBuffer(bytes: textData, length: textData.count * MemoryLayout<Float>.size, options: [])
    }
}
