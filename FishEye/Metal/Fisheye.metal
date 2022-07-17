//
//  Fisheye.metal
//  FishEye
//
//  Created by Roman on 17.07.2022.
//

#include <metal_stdlib>
using namespace metal;

// shader code from: https://www.shadertoy.com/view/ll2GWV

kernel void fisheye(texture2d<half, access::read> input [[texture(0)]],
                    texture2d<half, access::write> output [[texture(1)]],
                    const device float& modifier [[buffer(0)]],
                    uint2 gid [[thread_position_in_grid]])
{
    half2 size = half2(half(output.get_width()), half(output.get_height()));
    half2 uv = half2(gid) * 2 / size - half2(1);

    half d = length(uv) / (2 - modifier);
    half z = sqrt(1 - d * d);
    half r = atan2(d, z) / 3.14159;
    half phi = atan2(uv.y, uv.x);

    uv = half2(r * cos(phi) + 0.5, r * sin(phi) + 0.5);
    half4 value = input.read(uint2(uv * size) + 1);
    output.write(value, gid);
}
