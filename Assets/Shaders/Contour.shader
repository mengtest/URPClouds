Shader "Outline/Contour"
{
    Properties
    {
        _MainTex ("Base Map (RGB) Smoothness / Alpha (A)", 2D) = "white" {}
        _NormalTex ("Normal Map", 2D) = "bump" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque"}
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float3 view : TEXCOORD2;
                float3 tangentDir : TEXCOORD3;
                float3 bitangentDir : TEXCOORD4;
                float3 normal : NORMAL;
                float4 vertex : SV_POSITION;
            };

            sampler2D _NormalTex;
            sampler2D _MainTex;

            v2f vert (appdata v)
            {
                v2f o;
                o.uv = v.uv;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.view = normalize(WorldSpaceViewDir(v.vertex));
                o.normal = normalize( mul( unity_ObjectToWorld ,  v.normal).xyz ) ;
                o.tangentDir = normalize( mul( unity_ObjectToWorld , float4( v.tangent.xyz, 0) ).xyz );
                o.bitangentDir = cross( o.normal , o.tangentDir) * v.tangent.w;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3x3 rotation = float3x3(i.tangentDir, i.bitangentDir, i.normal);
                float3 viewDirTS = normalize(mul(rotation, i.view));
                float3 normal = normalize(UnpackNormal(tex2D(_NormalTex, i.uv)));
                float d = clamp(dot(normal, viewDirTS), 0, 1);
                float3 c = tex2D(_MainTex, i.uv);
                if (d < 0.5f) 
                {
                    float md = abs(d - 0.25f) * 4;
                    return float4(0, 0, 0, 1.0f);
                }
                else
                {
                    return float4(c, 1.0f);
                }
            }
            ENDCG
        }
    }
}
