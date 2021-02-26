Shader "Clouds"
{
    Properties
    {
        [HideInInspector] _MainTex("Base (RGB)", 2D) = "white" {}
        _BlueNoise("BlueNoise", 2D) = "white" {}
        _MaskNoise("MaskNoise", 2D) = "white" {}
        _CloudNoise("CloudNoise", 3D) = "white" {}
        _StepSize("StepSize", Float) = 3
        _WeatherMap("WeatherMap", 2D) = "white" {}
        _BoundsMax("BoundsMax", Vector) = (10, 3, 10, 0)
        _BoundsMin("BoundsMin", Vector) = (-10, 0, -10, 0)
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        LOD 200

        Pass
        {
            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"

            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            sampler2D _WeatherMap;
            sampler2D _MaskNoise;
            sampler3D _CloudNoise;
            float4x4 _ClipToWorldMatrix;
            float3 _BoundsMin;
            float3 _BoundsMax;
            float3 _SunLightDirection;
            float3 _SunLightColor;

            struct Attributes
            {
                float4 positionOS       : POSITION;
                float2 uv               : TEXCOORD0;
            };

            struct Varyings
            {
                float2 uv        : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.vertex = vertexInput.positionCS;
                output.uv = input.uv;

                return output;
            }

            float HG(float a, float g)
            {

            }

            float sampleDensity(float3 uvw)
            {
                return tex3D(_CloudNoise, uvw).x * tex2D(_WeatherMap, uvw.xz).x;
            }
            
            float2 rayBoxDst(float3 rayOrigin, float3 invRayDir)
            {
                float3 t0 = (_BoundsMin - rayOrigin) * invRayDir;
                float3 t1 = (_BoundsMax - rayOrigin) * invRayDir;

                float3 tmin = min(t0, t1);
                float3 tmax = max(t0, t1);

                float dstA = max(max(tmin.x, tmin.y), tmin.z); //进入点
                float dstB = min(tmax.x, min(tmax.y, tmax.z)); //出去点

                float dstToBox = max(0, dstA);
                float dstInsideBox = max(0, dstB - dstToBox);
                return float2(dstToBox, dstInsideBox);
            }

            half4 frag(Varyings input) : SV_Target
            {
                float beginz = UNITY_NEAR_CLIP_VALUE;
                float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, input.uv);
                float linearDepth = LinearEyeDepth(depth, _ZBufferParams);
                #if defined UNITY_REVERSED_Z
                    depth = 1 - depth;
                #endif

                half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                float3 ndc = float3(input.uv * 2 - 1, depth * 2 - 1);
                float4 WSP = mul(_ClipToWorldMatrix, float4(ndc, 1.0f));
                WSP /= WSP.w;

                float3 cameraPos = _WorldSpaceCameraPos;
                float3 direction = normalize(WSP.xyz - cameraPos);
                float3 invDirection = 1 / direction;
                float2 rayInfo = rayBoxDst(cameraPos, invDirection);

                rayInfo.y = min(linearDepth - rayInfo.x, rayInfo.y);

                const float stepSize = 0.1f;
                const float maxSteps = 50;
                float sum = 0;
                float3 VolumeSize = _BoundsMax - _BoundsMin;
                float3 InvSize = rcp(VolumeSize);
                float tmax = rayInfo.x + min(rayInfo.y, stepSize * maxSteps);

                
                float3 lightDirection = normalize(_MainLightPosition.xyz);
                float Tr = 1.0f;
                float3 AccumLight = float3(0, 0, 0);
                [loop]
                for(float t = rayInfo.x; t < tmax; t += stepSize)
                {
                    float3 pos = cameraPos  + t * direction;
                    float3 uvw = (pos - _BoundsMin) * InvSize;

                    float d = sampleDensity(uvw);

                    float2 lightMarchingInfo = rayBoxDst(pos, rcp(lightDirection));
                    float lightMarchingStepSize = lightMarchingInfo.y * 0.25f;
                    float lightMarchingDensityAccum = 0;
                    [loop]
                    for(int i = 0.5f; i < 4; i = i + 1.0f)
                    {
                        lightMarchingDensityAccum += sampleDensity((pos + lightDirection * (lightMarchingStepSize * i + lightMarchingInfo.x) - _BoundsMin) * InvSize);
                    }
                    // AccumLight = Tr * _MainLightColor * d * stepSize * exp(-lightMarchingStepSize * lightMarchingDensityAccum);
                    AccumLight = Tr * _MainLightColor.xyz * d * stepSize * 10;
                    Tr *= exp(-d * stepSize);
                    if (Tr < 0.01) break;

                    

                }

                
                // float3 VolumeSize = _BoundsMax - _BoundsMin;
                // float InvMax = 1 / max(VolumeSize.x, VolumeSize.z);
                // float3 uvw = (WSP - _BoundsMin) / VolumeSize;
                // float2 uv = (WSP.xz - _BoundsMin.xz) * InvMax;
                // float c = tex2D(_WeatherMap, uv).x;
                // return float4(lightDirection, 1.0f);
                // return float4(_MainLightColor.xyz, 1.0f);
                // return float4(col.xyz, 1);
                return float4(Tr * col.xyz , 1);
                // return float4(col.xyz * intensity, 1.0f);
                // return float4(intensity , intensity, intensity, 1.0f);
                // return float4(col.xyz * (intensity ), 1.0f);
            }
            
            
            

            #pragma vertex vert
            #pragma fragment frag

            ENDHLSL
        }
    }
}
