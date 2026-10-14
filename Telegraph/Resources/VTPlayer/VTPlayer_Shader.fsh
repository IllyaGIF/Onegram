/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  Passthrough shader for displaying CVPixelbuffers
  
 */

varying highp vec2 texCoordVarying;
precision mediump float;

uniform sampler2D SamplerY;
uniform sampler2D SamplerUV;
uniform mat3 colorConversionMatrix;
uniform float useLuminanceAlpha;

void main()
{
	mediump vec3 yuv;
	lowp vec3 rgb;
	
	// Subtract constants to map the video range start at 0
    yuv.x = (texture2D(SamplerY, texCoordVarying).r - (16.0/255.0));
    vec4 chroma = texture2D(SamplerUV, texCoordVarying);
    yuv.yz = (mix(chroma.rg, chroma.ra, useLuminanceAlpha) - vec2(0.5, 0.5));
	
	rgb = colorConversionMatrix * yuv;

	gl_FragColor = vec4(rgb,1);
}

