Shader "soundhero/entity_cover"
{
    Properties
    {
		_CoverColor("_CoverColor",Color) = (0,0,0,1)
    }


    SubShader
    {
		
        Tags { "RenderPipeline"="LightweightPipeline" "RenderType"="Opaque" "Queue"="AlphaTest+100" }

		Cull Back
		HLSLINCLUDE
		#pragma target 3.0
		ENDHLSL
		Pass
		{
			//?????????????
			Tags{ "LightMode" = "LightweightForward" }

			Cull Back
			ZWrite Off
			ZTest Greater
			Blend SrcAlpha OneMinusSrcAlpha
			CGPROGRAM
#pragma vertex vert
#pragma fragment frag
			struct appdata
			{
				float4 vertex : POSITION;

			};
			struct v2f
			{
				float4 vertex : SV_POSITION;
			};
			float4 _CoverColor;
			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				return _CoverColor;
			}
			ENDCG
		}
	}
    Fallback "Hidden/InternalErrorShader"
	CustomEditor "ASEMaterialInspector"
}