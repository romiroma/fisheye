//
//  CVPixelBuffer+MTLTexture.swift
//  FishEye
//
//  Created by Roman on 17.07.2022.
//

import CoreVideo
import Metal

extension CVPixelBuffer {

    func metalTexture(using cache: CVMetalTextureCache,
                      pixelFormat: MTLPixelFormat,
                      planeIndex: Int = 0) -> MTLTexture? {
        let width = CVPixelBufferGetWidthOfPlane(self, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(self, planeIndex)

        var texture: CVMetalTexture? = nil
        let status = CVMetalTextureCacheCreateTextureFromImage(nil,
                                                               cache,
                                                               self,
                                                               nil,
                                                               pixelFormat,
                                                               width,
                                                               height,
                                                               planeIndex,
                                                               &texture)

        var retVal: MTLTexture? = nil
        if status == kCVReturnSuccess {
            retVal = CVMetalTextureGetTexture(texture!)
        }

        return retVal
    }

}
