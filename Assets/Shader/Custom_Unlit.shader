Shader "Custom/Unlit" {
    Properties {
        _BaseMap ("Example Texture", 2D) = "white" {}
        _BaseColor ("Example Colour", Color) = (0, 0.66, 0.73, 1)
    }
    SubShader {

        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalRenderPipeline" }
       
        HLSLINCLUDE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            //#include "Packages/com.unity.render-pipelines.universal/Shaders/UnlitInput.hlsl"
            // #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            // #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            // #pragma multi_compile _ _SHADOWS_SOFT
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            float4 _BaseColor;
            CBUFFER_END
        ENDHLSL

        UsePass "Universal Render Pipeline/Unlit/DepthOnly"
        Pass {
            Name "ForwardBase"
            Tags { "LightMode"="UniversalForward" }
           
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
           
            struct Attributes {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
                float4 color        : COLOR;
                float4 normalOS     : NORMAL;
            };
 
            struct Varyings {
                float4 positionCS  : SV_POSITION;
                float2 uv           : TEXCOORD0;
                float4 color        : COLOR;
                float3 normalWS     : NORMAl;
                float3 positionWS   : TEXCOORD2;
            };
 
            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
           
            Varyings vert(Attributes IN) {
                Varyings OUT;
 
                VertexPositionInputs positionInputs = GetVertexPositionInputs(IN.positionOS.xyz);
                OUT.positionCS = positionInputs.positionCS;
                // Or this :
                //OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.positionWS = positionInputs.positionWS;

                VertexNormalInputs normalInputs = GetVertexNormalInputs(IN.normalOS.xyz);
                OUT.normalWS = normalInputs.normalWS;

                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                OUT.color = IN.color;
                return OUT;
            }
           
            half4 frag(Varyings IN) : SV_Target {
                half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);
                half4 color = baseMap * _BaseColor * IN.color;

                float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS.xyz);
                Light light = GetMainLight(shadowCoord);

                half3 diffuse = LightingLambert(light.color,light.direction,IN.normalWS);
               
                return half4(color.rgb * diffuse * light.shadowAttenuation,color.a);
            }
            ENDHLSL
        }
    }
}