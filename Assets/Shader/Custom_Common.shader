Shader "Custom/Common" {
    Properties {
        _BaseMap ("Example Texture", 2D) = "white" {}
        _BaseColor ("Example Colour", Color) = (0, 0.66, 0.73, 1)
        _Smoothness("Smoothness",Range(0,1)) = 0.5

        [Toggle(_NORMALMAP)]_EnableBumpMap("Enable Normal/Bump Map",Float) = 0.0
        _BumpMap ("Normal/Bump Texture", 2D) = "bump" {}
        _BumpScale ("Bump Scale", Float) = 1

        [Toggle(_ALPHATEST_ON)]_EnableAlphaTest("Enable Alpha Cutoff",Float) = 0.0
        _Cutoff("Alpha Cutoff",Float) = 0.5

        [Toggle(_EMISSION)]_EnableEmission("Enable Emission",Float) = 0.0
        _EmissionMap("Emission Map",2D) = "white"{} 
        [HDR]_EmissionColor("Emission Color",Color) = (0,0,0,0)
    }
    SubShader {

        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalRenderPipeline" }
       
        HLSLINCLUDE

            #pragma shader_feature _NORMALMAP
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _EMISSION

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITION_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE

            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHMAP_ON
            #pragma multi_compile_fog


            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            //#include "Packages/com.unity.render-pipelines.universal/Shaders/UnlitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
            
            CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            float4 _BaseColor;
            float _Smoothness;
            //float4 _BumpMap_ST;
            float _BumpScale;
            float _Cutoff;
            float4 _EmissionColor;
            CBUFFER_END

            struct Attributes {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
                float2 lightmapUV    : TEXCOORD1;
                float4 color        : COLOR;
                float4 normalOS     : NORMAL;
                float4 tangentOS    : TANGENT;
            };
 
            struct Varyings {
                float4 positionCS  : SV_POSITION;
                float2 uv           : TEXCOORD0;
                float4 color        : COLOR;
                DECLARE_LIGHTMAP_OR_SH(lightmapUV,vertexSH,1);
            #ifdef REQUIRES_WORLD_SPACE_POS_INTERPOLATOR
                float3 positionWS   : TEXCOORD2;
            #endif
                float3 normalWS     : TEXCOORD3;
            #ifdef _NORMALMAP
                float4 tangentWS    : TEXCOORD4;
            #endif
                float3 viewDirWS    : TEXCOORD5;
                half4 fogFactorAndVertexLight : TEXCOORD6;
            #ifdef REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR
                float4 shadowCoord  :TEXCOORD7;
            #endif
            };

            #if SHADER_LIBRARY_VERSION_MAJOR < 9
                float3 GetWorldSpaceViewDir(float3 positionWS)
                {
                    if(unity_OrthoParams.w == 0)
                    {
                        // Perspective
                        return _WorldSpaceCameraPos - positionWS;
                    }
                    else
                    {
                        // Orthographic
                        float4x4 viewMat = GetWorldToViewMatrix();
                        return viewMat[2].xyz;
                    }
                }
            #endif

            InputData InitializeInputData(Varyings IN, half3 NormalTS)
            {
                InputData inputData = (InputData)0;
                
                #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
                    inputData.positionWS = IN.positionWS;
                #endif
                                
                    half3 viewDirWS = SafeNormalize(IN.viewDirWS);
                #ifdef _NORMALMAP
                    float sgn = IN.tangentWS.w; // should be either +1 or -1
                    float3 bitangent = sgn * cross(IN.normalWS.xyz, IN.tangentWS.xyz);
                    inputData.normalWS = TransformTangentToWorld(normalTS, half3x3(IN.tangentWS.xyz, bitangent.xyz, IN.normalWS.xyz));
                #else
                    inputData.normalWS = IN.normalWS;
                #endif
                
                    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
                    inputData.viewDirectionWS = viewDirWS;
                
                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                    inputData.shadowCoord = IN.shadowCoord;
                #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
                    inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
                #else
                    inputData.shadowCoord = float4(0, 0, 0, 0);
                #endif
                
                    inputData.fogCoord = IN.fogFactorAndVertexLight.x;
                    inputData.vertexLighting = IN.fogFactorAndVertexLight.yzw;
                    inputData.bakedGI = SAMPLE_GI(IN.lightmapUV, IN.vertexSH, inputData.normalWS);
                    return inputData;
            }

            SurfaceData InitializeSurfaceData(Varyings IN)
            {
                SurfaceData surfaceData = (SurfaceData)0;
                // 数字0会自动初始化结构体数据为0。
                    
                half4 albedoAlpha = SampleAlbedoAlpha(IN.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
                surfaceData.alpha = Alpha(albedoAlpha.a, _BaseColor, _Cutoff);
                surfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb * IN.color.rgb;

                surfaceData.smoothness = _Smoothness;
                surfaceData.normalTS = SampleNormal(IN.uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
                surfaceData.emission = SampleEmission(IN.uv, _EmissionColor.rgb, TEXTURE2D_ARGS(_EmissionMap, sampler_EmissionMap));
                surfaceData.occlusion = 1;
                return surfaceData;

            }
            
        ENDHLSL

        UsePass "Universal Render Pipeline/Unlit/DepthOnly"
        Pass {
            Name "ForwardBase"
            Tags { "LightMode"="UniversalForward" }
           
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
           
            
 
            // TEXTURE2D(_BaseMap);
            // SAMPLER(sampler_BaseMap);
           
            Varyings vert(Attributes IN) 
            {
                Varyings OUT;

                // 顶点位置
                VertexPositionInputs positionInputs = GetVertexPositionInputs(IN.positionOS.xyz);
                OUT.positionCS = positionInputs.positionCS;
                // Or this :
                //OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
            #ifdef REQUIRES_WORLD_SPACE_POS_INTERPOLATOR
                OUT.positionWS = positionInputs.positionWS;
            #endif

                // 观察方向
                OUT.viewDirWS = GetWorldSpaceViewDir(positionInputs.positionWS);
                // 法线和切线
                VertexNormalInputs normalInputs = GetVertexNormalInputs(IN.normalOS.xyz);
                OUT.normalWS = normalInputs.normalWS;
            #ifdef _NORMALMAP
                real sign = IN.tangentOS.w * GetOddNegativeScale();
                OUT.tangentWS = half4(normalInputs.tangentWS.xyz,sign);
            #endif

                // UVs & 顶点色
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                OUT.color = IN.color;

                //顶点光照 & 雾
                half3 vertexLight = VertexLighting(positionInputs.positionWS,normalInputs.normalWS);
                half fogFactor = ComputeFogFactor(positionInputs.positionCS.z);
                OUT.fogFactorAndVertexLight = half4(fogFactor,vertexLight);

                //烘培光照 & 球谐函数（没有烘培灯光情况下的环境光照）
            #ifdef LIGHTMPA_ON
                OUTPUT_LIGHMAP_UV(IN.lightmapUV,unity_LightmapST,OUT.lightmapUV);
            #endif
                OUTPUT_SH(OUT.normalWS.xyz,OUT.vertexSH);

                //阴影坐标
            #ifdef REQuIRES_VERTEX_SHADOW_COORD_INTERPOLATOR
                OUT.shadowCoord = GetShadowCoord(positionInputs);
            #endif

                return OUT;
            }
           
            half4 frag(Varyings IN) : SV_Target {
                // half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);
                // half4 color = baseMap * _BaseColor * IN.color;

                // float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS.xyz);
                // Light light = GetMainLight(shadowCoord);

                // half3 diffuse = LightingLambert(light.color,light.direction,IN.normalWS);
               
                // return half4(color.rgb * diffuse * light.shadowAttenuation,color.a);
                SurfaceData surfaceData = InitializeSurfaceData(IN);
                InputData inputData = InitializeInputData(IN, surfaceData.normalTS);
                            
                half4 color = UniversalFragmentPBR(inputData, surfaceData);                
                color.rgb = MixFog(color.rgb, inputData.fogCoord);
                color.a = saturate(color.a);
            
                return color;
            }
            ENDHLSL
        }
    }
}