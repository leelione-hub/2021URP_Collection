## URP内置函数记录（URP12.1）

#### 用TEXTURE2D(textureName)和SAMPLER(samplerName)来声明纹理和采样器，用TEXTURE2D_PARAM(textureName, samplerName)来声明你的函数中的参数，用TEXTURE2D_ARGS(textureName, samplerName)宏来调用你的函数
- 在SufaceInput.hlsl中定义了这么一个方法
```
    half4 SampleAlbedoAlpha(float2 uv, TEXTURE2D_PARAM(albedoAlphaMap, sampler_albedoAlphaMap))
    {
        return half4(SAMPLE_TEXTURE2D(albedoAlphaMap, sampler_albedoAlphaMap, uv));
    }
```
- 我们在调用的时候就可以这样使用   
` half4 albedoAlpha = SampleAlbedoAlpha(IN.uv,TEXTURE2D_ARGS(_BaseMap,sampler_BaseMap));`