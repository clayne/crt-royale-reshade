#include "../lib/user-settings.fxh"
#include "../lib/derived-settings-and-constants.fxh"
#include "../lib/bind-shader-params.fxh"
#include "../lib/gamma-management.fxh"
#include "../lib/scanline-functions.fxh"

void lerpScanlinesPS(
    in const float4 pos : SV_Position,
    in const float2 texcoord : TEXCOORD0,

    out float4 color : SV_Target
) {
    if (enable_interlacing) {
        /*
        if (texcoord.x < 0.5) {
            color = tex2D(samplerBloomHorizontal, texcoord);
        }
        else {
            color = tex2D(samplerFreezeFrame, texcoord);
        }
        */
        const float cur_scanline_idx = get_curr_scanline_idx(texcoord.y, CONTENT_HEIGHT_INTERNAL);
        const float wrong_field = curr_line_is_wrong_field(cur_scanline_idx);

        // const float4 cur_line_color = tex2D_linearize(samplerBloomHorizontal, texcoord, get_intermediate_gamma());
        // const float4 cur_line_prev_color = tex2D_linearize(samplerFreezeFrame, texcoord, get_intermediate_gamma());
        const float4 cur_line_color = tex2D(samplerBloomHorizontal, texcoord);
        const float4 cur_line_prev_color = tex2D(samplerFreezeFrame, texcoord);

        // const float4 prev_weight = cur_line_prev_color;
        const float4 avg_color = (cur_line_color + cur_line_prev_color) / 2.0;
        // const float s = wrong_field ? 1 : -1;
        // const float4 color_dev = abs(cur_line_color - avg_color);
        // const float4 delta_c = s * (1 - scanline_blend_strength) * color_dev;
        // color = encode_output(avg_color + delta_c, lerp(1.0, scanline_blend_gamma, scanline_blend_strength));

        const float4 raw_out_color = lerp(cur_line_color, avg_color, scanline_blend_strength);
        color = encode_output(raw_out_color, lerp(1.0, scanline_blend_gamma, scanline_blend_strength));
    }
    else {
        color = tex2D(samplerBloomHorizontal, texcoord);
    }
}

void freezeFramePS(
    in const float4 pos : SV_Position,
    in const float2 texcoord : TEXCOORD0,

    out float4 color : SV_Target
) {
    color = tex2D(samplerBloomHorizontal, texcoord);
}