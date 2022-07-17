//
//  Fisheye.swift
//  FishEye
//
//  Created by Roman on 17.07.2022.
//

import Metal
import MetalPerformanceShaders

public final class Fisheye: MPSUnaryImageKernel {

    private let threadgroupSize: MTLSize
    private let computePipeline: MTLComputePipelineState

    var modifier: Float = 0.5 // 0...1

    init(_ device: MTLDevice) throws {

        let library = try device.makeDefaultLibrary(bundle: .main)
        guard let kernelFunction = library.makeFunction(name: "fisheye") else {
            throw NSError(domain: "NoKernel", code: 0)
        }
        computePipeline = try device.makeComputePipelineState(function: kernelFunction)
        threadgroupSize = computePipeline.threadGroupSize

        super.init(device: device)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func encode(commandBuffer: MTLCommandBuffer, sourceTexture: MTLTexture, destinationTexture: MTLTexture) {
        let size: MTLSize = .init(width: sourceTexture.width,
                                  height: sourceTexture.height,
                                  depth: sourceTexture.depth)
        let threadgroupCount = MTLSize(width: (size.width - 1) / threadgroupSize.width + 1,
                                       height: (size.height - 1) / threadgroupSize.height + 1,
                                       depth: 1)
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return
        }
        encoder.setComputePipelineState(computePipeline)
        encoder.setTexture(sourceTexture, index: 0)
        encoder.setTexture(destinationTexture, index: 1)
        encoder.setBytes(&modifier, length: MemoryLayout<Float>.size, index: 0)
        encoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        encoder.endEncoding()
    }
}
