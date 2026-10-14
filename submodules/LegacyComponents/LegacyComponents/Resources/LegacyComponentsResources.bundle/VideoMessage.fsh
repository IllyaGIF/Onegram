precision mediump float;

varying mediump vec2 varTexcoord;
uniform sampler2D texture;
uniform sampler2D previousTexture;
uniform mediump float opacity;
uniform mediump float aspectRatio;
uniform mediump float noMirror;
uniform sampler2D chromaTexture;
uniform sampler2D previousChromaTexture;
uniform mediump float isNV12;
uniform mediump float previousIsNV12;
uniform mediump mat3 colorConversion;
uniform mediump mat3 previousColorConversion;
uniform mediump vec3 colorOffset;
uniform mediump vec3 previousColorOffset;

void main()
{
    vec2 texcoord = vec2(1.0 - varTexcoord.x * noMirror + clamp(noMirror, -1.0, 0.0), varTexcoord.y);
    vec2 prevTexcoord = vec2(texcoord.x, 1.0 - texcoord.y);
    
    vec4 white = vec4(1.0, 1.0, 1.0, 1.0);
    vec4 color = texture2D(texture, texcoord);
    vec4 previousColor = texture2D(previousTexture, prevTexcoord);
    if (isNV12 > 0.5)
    {
        vec3 yuv = vec3(color.r, texture2D(chromaTexture, texcoord).ra);
        color = vec4(clamp(colorConversion * (yuv + colorOffset), 0.0, 1.0), 1.0);
    }
    if (previousIsNV12 > 0.5)
    {
        vec3 yuv = vec3(previousColor.r, texture2D(previousChromaTexture, prevTexcoord).ra);
        previousColor = vec4(clamp(previousColorConversion * (yuv + previousColorOffset), 0.0, 1.0), 1.0);
    }
    
    color.rgb = mix(color.rgb, previousColor.rgb, opacity);
    
    vec2 c = vec2((varTexcoord.x * 2.0 - 1.0) * aspectRatio, varTexcoord.y * 2.0 - 1.0) * 0.996;
    vec2 c1 = c - 0.005;
    vec2 c2 = c + 0.005;
    vec2 c3 = vec2(c1.x, c2.y);
    vec2 c4 = vec2(c2.x, c1.y);
    float s1 = floor(dot(c1, c1));
    float s2 = floor(dot(c2, c2));
    float s3 = floor(dot(c3, c3));
    float s4 = floor(dot(c4, c4));
    
    gl_FragColor = mix(color, white, (s1 + s2 + s3 + s4) * 0.25);
}
