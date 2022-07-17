//
//  MTLComputePipelineState+threadgroupSize.swift
//  FishEye
//
//  Created by Roman on 17.07.2022.
//

import Metal

extension MTLComputePipelineState {
    public var threadGroupSize: MTLSize { MTLSizeMake(threadExecutionWidth,
                                                      maxTotalThreadsPerThreadgroup / threadExecutionWidth,
                                                      1) }
}
