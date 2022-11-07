#include "ReShade.fxh"

/////////////////////////////  GPL LICENSE NOTICE  /////////////////////////////

//  crt-royale-reshade: A port of TroggleMonkey's crt-royale from libretro to ReShade.
//  Copyright (C) 2020 Alex Gunter <akg7634@gmail.com>
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along with
//  this program; if not, write to the Free Software Foundation, Inc., 59 Temple
//  Place, Suite 330, Boston, MA 02111-1307 USA

// Enable or disable the shader
#ifndef CONTENT_BOX_VISIBLE
	#define CONTENT_BOX_VISIBLE 0
#endif

#include "crt-royale/shaders/content-box.fxh"

#if !CONTENT_BOX_VISIBLE
	#include "crt-royale/shaders/linear-preblur.fxh"
	#include "crt-royale/shaders/electron-beams.fxh"
	#include "crt-royale/shaders/bloom-approx.fxh"
	#include "crt-royale/shaders/blur9fast-vertical.fxh"
	#include "crt-royale/shaders/blur9fast-horizontal.fxh"
	#include "crt-royale/shaders/deinterlace.fxh"
	#include "crt-royale/shaders/computed-mask.fxh"
	#include "crt-royale/shaders/brightpass.fxh"
	#include "crt-royale/shaders/bloom-vertical.fxh"
	#include "crt-royale/shaders/bloom-horizontal-reconstitute.fxh"
	#include "crt-royale/shaders/geometry-aa-last-pass.fxh"
	#include "crt-royale/shaders/content-uncrop.fxh"
#endif


technique CRT_Royale
{
	// Toggle the content box to help users configure it
	#if CONTENT_BOX_VISIBLE
		// content-box.fxh
		pass contentBoxPass
		{
			// Draw a box that displays the crop we'll perform.
			VertexShader = PostProcessVS;
			PixelShader = contentBoxPixelShader;
		}
	#else
		#if ENABLE_PREBLUR
			pass PreblurVert
			{
				VertexShader = PostProcessVS;
				PixelShader = preblurVertPS;

				RenderTarget = texPreblurVert;
			}
			pass PreblurHoriz
			{
				VertexShader = PostProcessVS;
				PixelShader = preblurHorizPS;
				
				RenderTarget = texPreblurHoriz;
			}
		#endif
		pass beamDistPass
		{
			// Simulate emission of the interlaced video as electron beams. 	
			VertexShader = calculateBeamDistsVS;
			PixelShader = calculateBeamDistsPS;

			RenderTarget = texBeamDist;

			// This lets us improve performance by only computing the mask every k frames
			ClearRenderTargets = false;
		}
		pass electronBeamPass
		{
			// Simulate emission of the interlaced video as electron beams. 	
			VertexShader = simulateEletronBeamsVS;
			PixelShader = simulateEletronBeamsPS;

			RenderTarget = texElectronBeams;
		}
		pass beamConvergencePass
		{
			// Simulate beam convergence miscalibration
			//   Not to be confused with beam purity
			VertexShader = beamConvergenceVS;
			PixelShader = beamConvergencePS;

			RenderTarget = texBeamConvergence;
		}
		// crt-royale-bloom-approx.fxh
		pass bloomApproxPassVert
		{
			// The original crt-royale did a bunch of math in this pass
			//   and then threw it all away. So this is a no-op for now.
			//   It still has a blur effect b/c its a smaller buffer.
			// TODO: activate the math in this pass and see what happens.
			VertexShader = PostProcessVS;
			PixelShader = approximateBloomVertPS;
			
			RenderTarget = texBloomApproxVert;
		}
		pass bloomApproxPassHoriz
		{
			// The original crt-royale did a bunch of math in this pass
			//   and then threw it all away. So this is a no-op for now.
			//   It still has a blur effect b/c its a smaller buffer.
			// TODO: activate the math in this pass and see what happens.
			VertexShader = PostProcessVS;
			PixelShader = approximateBloomHorizPS;
			
			RenderTarget = texBloomApproxHoriz;
		}
		// blur9fast-vertical.fxh
		pass blurVerticalPass
		{
			// Vertically blur the approx bloom
			VertexShader = blurVerticalVS;
			PixelShader = blurVerticalPS;
			
			RenderTarget = texBlurVertical;
		}
		// blur9fast-horizontal.fxh
		pass blurHorizontalPass
		{
			// Horizontally blur the approx bloom
			VertexShader = blurHorizontalVS;
			PixelShader = blurHorizontalPS;
			
			RenderTarget = texBlurHorizontal;
		}
		// crt-royale-deinterlace.fxh
		pass deinterlacePass
		{
			// Optionally deinterlace the video. This can produce more
			//   consistent behavior across monitors and emulators.
			//   It can also help simulate some edge cases.
			VertexShader = deinterlaceVS;
			PixelShader = deinterlacePS;
			
			RenderTarget = texDeinterlace;
		}
		pass freezeFramePass
		{
			// Capture the current frame, so we can use it in the next
			//   frame's deinterlacing pass.
			VertexShader = PostProcessVS;
			PixelShader = freezeFramePS;

			RenderTarget = texFreezeFrame;

			// Explicitly disable clearing render targets
			//   scanlineBlendPass will not work properly if this ever defaults to true
			ClearRenderTargets = false;
		}
		// crt-royale-computed-mask.fxh
		pass generatePhosphorMask
		{
			VertexShader = generatePhosphorMaskVS;
			PixelShader = generatePhosphorMaskPS;

			RenderTarget = texPhosphorMask;

			// This lets us improve performance by only computing the mask every k frames
			ClearRenderTargets = false;
		}
		pass applyPhosphormask
		{
			// Tile the scaled phosphor mask and apply it to
			//   the deinterlaced image.
			VertexShader = PostProcessVS;
			PixelShader = applyComputedPhosphorMaskPS;
			
			RenderTarget = texMaskedScanlines;
			// RenderTarget = texGeometry;
		}
		// crt-royale-brightpass.fxh
		pass brightpassPass
		{
			// Apply a brightpass filter for the bloom effect
			VertexShader = brightpassVS;
			PixelShader = brightpassPS;
			
			RenderTarget = texBrightpass;
		}
		// crt-royale-bloom-vertical.fxh
		pass bloomVerticalPass
		{
			// Blur vertically for the bloom effect
			VertexShader = bloomVerticalVS;
			PixelShader = bloomVerticalPS;
			
			RenderTarget = texBloomVertical;
		}
		// crt-royale-bloom-horizontal-reconstitute.fxh
		pass bloomHorizontalPass
		{
			// Blur horizontally for the bloom effect.
			//   Also apply various color changes and effects.
			VertexShader = bloomHorizontalVS;
			PixelShader = bloomHorizontalPS;
			
			RenderTarget = texBloomHorizontal;
		}
		// crt-royale-geometry-aa-last-pass.fxh
		pass geometryPass
		{
			// Apply screen geometry and anti-aliasing.
			VertexShader = geometryVS;
			PixelShader = geometryPS;

			RenderTarget = texGeometry;
		}
		// content-uncrop.fxh
		pass uncropPass
		{
			// Uncrop the video, so we draw the game's content
			//   in the same position it started in.
			VertexShader = PostProcessVS;
			PixelShader = uncropContentPixelShader;
		}
	#endif
}