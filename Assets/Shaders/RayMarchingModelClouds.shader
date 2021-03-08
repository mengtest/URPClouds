Shader "ModelClouds"
{
    Properties
    {
        [HideInInspector] _MainTex("Base (RGB)", 2D) = "white" {}
        [NoScaleOffset]_BlueNoise("BlueNoise", 2D) = "white" {}
        [NoScaleOffset]_ShapeNoise("ShapeNoise", 3D) = "white" {}
        [NoScaleOffset]_DetailNoise("DetailNoise", 3D) = "white" {}
        _BoundsMin("BoundsMin", Vector) = (0, 0, 0, 0)
        _BoundsSize("BoundsSize", float) = 100
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
            sampler2D _BlueNoise;
            sampler3D _ShapeNoise;
            sampler3D _DetailNoise;
            float4x4 _ClipToWorldMatrix;
            float3 _BoundsMin;
            float _BoundsSize;
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

            // Henyey-Greenstein
            float hg(float a, float g) {
                float g2 = g*g;
                return (1-g2) / (4*3.1415*pow(1+g2-2*g*(a), 1.5));
            }


            // 相函数信息
            const static float4 phaseParams = float4(0.5, 0.1, 0.1, 0.9);
            float phase(float a) {
                float blend = .5;
                float hgBlend = hg(a,phaseParams.x) * (1-blend) + hg(a,-phaseParams.y) * blend;
                return phaseParams.z + hgBlend*phaseParams.w;
            }

            float smoothStep(float v)
            {
                float v2 = v * v;
                float v3 = v2 * v;
                return 3 * v2 - 2 * v3;
            }

            float remap(float v, float minOld, float maxOld, float minNew, float maxNew) {
                return minNew + (v-minOld) * (maxNew - minNew) / (maxOld-minOld);
            }

            bool sampleDensity(float3 pos, out float sdf, out float density)
            {
                float3 size = float3(_BoundsSize, _BoundsSize, _BoundsSize);
                float3 uvw = (pos - _BoundsMin) / size;

                // float value = shapeFBM;
                sdf = tex3D(_ShapeNoise, uvw).a;
                if (sdf < -0.002f) density = 1;
                else density  = smoothStep(saturate(remap(sdf, 0, 0.003f, 1.0, 0.0)));

                if (density > 0)
                {
                    const static float3 speed = float3(0.01f, 0.02f, 0.05f);
                    float3 detailNoise = tex3D(_DetailNoise, uvw * 0.5f + speed * _Time.y).xyz;   
                    const static float3 detailWeights = float3(0.5, 0.3, 0.3);
                    float detailFBM = dot(detailNoise, detailWeights);
                    detailFBM = remap(detailFBM, 0, 1, 0.5, 1);
                    // density *= detailFBM;
                    // density *= detailFBM;
                    density *= remap(detailNoise.z, 0, 1, 0.4, 1);
                }
                return sdf < 0;
            }

            
            float2 rayBoxDst(float3 rayOrigin, float3 invRayDir)
            {
                float3 t0 = (_BoundsMin - rayOrigin) * invRayDir;
                float3 _BoundsMax = _BoundsMin + float3(_BoundsSize, _BoundsSize, _BoundsSize);
                float3 t1 = (_BoundsMax - rayOrigin) * invRayDir;

                float3 tmin = min(t0, t1);
                float3 tmax = max(t0, t1);

                float dstA = max(max(tmin.x, tmin.y), tmin.z); //进入点
                float dstB = min(tmax.x, min(tmax.y, tmax.z)); //出去点

                // if (dstB > 0 && dstA < dstB) return(dstA, dstB);

                // if (dstA > dstB) return float2(0, 0);
                float dstToBox = max(0, dstA);
                float dstInsideBox = max(0, dstB - dstToBox);
                return float2(dstToBox, dstInsideBox);
            }

            float2 squareUV(float2 uv) {
                float width = _ScreenParams.x;
                float height =_ScreenParams.y;
                //float minDim = min(width, height);
                float scale = 1000;
                float x = uv.x * width;
                float y = uv.y * height;
                return float2 (x/scale, y/scale);
            }

            float4 frag(Varyings input) : SV_Target
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


                // RayMarching步长
                const static float stepSize = 0.5f;
                float3 VolumeSize = float3(_BoundsSize, _BoundsSize, _BoundsSize);
                float3 InvSize = rcp(VolumeSize);
                float tmax = rayInfo.x + rayInfo.y;

                
                float3 lightDirection = normalize(_MainLightPosition.xyz);
                float cosTheta = dot(lightDirection, direction);
                float phaseVal = phase(cosTheta);
                float Tr = 1.0f;
                float LightEnergy = 0;
                float sum = 0;

                // float randomOffset = tex2D(_BlueNoise, squareUV(input.uv * 3)).r;
                float randomOffset = tex2D(_BlueNoise, input.uv).r;
                [loop]
                for(float t = rayInfo.x + randomOffset; t < tmax;)
                {
                    float3 pos = cameraPos  + t * direction;
                    float3 uvw = (pos - _BoundsMin) * InvSize;


                    float d;
                    float sdf;
                    // sampleDensity(pos, sdf, d);
                    // t += stepSize;
                    // SDF变步长
                    if (!sampleDensity(pos, sdf, d))
                    {
                        t += max(sdf * _BoundsSize * 7.5f, stepSize); 
                    }
                    else
                    {
                        t += stepSize;
                    }
                    // t += stepSize;
                    sum += d * 0.02f;

                    if (d > 0)
                    {
                        float2 lightMarchingInfo = rayBoxDst(pos, rcp(lightDirection));
                        const static int lightMatchingSteps = 5;
                        float lightMarchingStepSize = lightMarchingInfo.y / lightMatchingSteps;
                        float lightMarchingDensityAccum = d;
                        [loop]
                        for(int i = 1; i < lightMatchingSteps; i++)
                        {
                            float3 npos = pos + lightDirection * (lightMarchingInfo.x + lightMarchingStepSize * i);
                            float sdf, dl;

                            sampleDensity(npos, sdf, dl);

                            // if (sampleDensity(npos, sdf, dl))
                            // {
                            //     i += max(sdf * _BoundsSize, lightMatchingSteps);
                            // }
                            // else
                            // {
                            //     i += stepSize;
                            // }
                            lightMarchingDensityAccum += dl;
                        }
                        const static float LightAbsortionTowardsSun = 0.2f;
                        float sunLightTr = exp(-lightMarchingDensityAccum * lightMarchingStepSize * LightAbsortionTowardsSun);
                        const static float darknessThreshold = 0.02f;
                        sunLightTr = darknessThreshold + (1 - darknessThreshold) * sunLightTr;
                        LightEnergy += Tr * d * stepSize * sunLightTr * phaseVal;
                    }

                    const static float LightAbsortionThroughCloud = 0.17f;
                    Tr *= exp(-d * stepSize * LightAbsortionThroughCloud);
                    if (Tr < 0.01) break;
                }

                // return float4(sum, sum, sum , 1);
                //  return float4(phaseVal * 3, 0, 0 , 1);
                // return float4(Tr * col.xyz, 1);
                return float4(Tr * col.xyz + LightEnergy * _MainLightColor.xyz, 1);
                // return float4(randomOffset, randomOffset, randomOffset, 1);
                // return float4(Tr * col.xyz, 1);
            }
            
            
            

            #pragma vertex vert
            #pragma fragment frag

            ENDHLSL
        }
    }
}
