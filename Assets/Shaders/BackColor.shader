Shader "Outline/BackColor"
{
    Properties
    {
        _MainTex("Base Map (RGB) Smoothness / Alpha (A)", 2D) = "white" {}
        _NormalTex("Normal Map", 2D) = "bump" {}
    }
        SubShader
    {
        Tags { "RenderType" = "Opaque"}
        Cull Back
        LOD 100

        Pass
        {
            Cull Front
            //ZWrite Off
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
            };

            sampler2D _NormalTex;
            sampler2D _MainTex;

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex + v.normal);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                return float4(0, 0, 0, 1.0f);
            }
            ENDCG
        }
    }
}
