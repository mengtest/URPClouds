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
                float4 vertex : SV_POSITION;
                float3 tpos : TEXCOORD1;
                float3 wpos : TEXCOORD2;
            };

            sampler2D _NormalTex;
            sampler2D _MainTex;
            // float4 _NormalTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.uv = v.uv;
                o.vertex = UnityObjectToClipPos(v.vertex);
                fixed3 worldPos = mul(unity_ObjectToWorld, v.vertex);
                // fixed3 viewDir = _WorldSpaceCameraPos - worldPos;
                // float3 binormal = cross( normalize(v.normal), normalize(v.tangent.xyz) ) * v.tangent.w;
                // float3x3 rotation = float3x3( v.tangent.xyz, binormal, v.normal )
                // TANGENT_SPACE_ROTATION;
                // o.tpos = mul(rotation, viewDir);
                fixed3 normalWS = UnityObjectToWorldNormal(v.normal);
                o.tpos = normalWS;
                o.wpos = worldPos;
                // o.pos = v.vertex;
                // o.uv = TRANSFORM_TEX(v.uv, _NormalTex);
                // UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                // fixed3 normal = UnpackNormal(tex2D(_NormalTex, i.uv));
                // float d = dot(normal, i.tpos);
                float d = clamp(dot(normalize(i.tpos), normalize(_WorldSpaceCameraPos - i.wpos)), 0, 1);
                fixed3 c = tex2D(_MainTex, i.uv);
                // return fixed4(c * d, 1.0f);
                if (d < 0.5f) 
                {
                    float md = abs(d - 0.25f) * 4;
                    // return fixed4(c * md, 1.0f);
                    return fixed4(0, 0, 0, 1.0f);
                }
                else
                {
                    // return fixed4(normalize(i.wpos), 1.0f);
                    return fixed4(c, 1.0f);
                }
            }
            ENDCG
        }
    }
}
