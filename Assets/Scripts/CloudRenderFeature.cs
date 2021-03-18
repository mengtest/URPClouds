using UnityEngine.Rendering.Universal;

namespace UnityEngine.Experiemntal.Rendering.Universal
{
    public class CloudRenderFeature : ScriptableRendererFeature
    {
        [System.Serializable]
        public class BlitSettings
        {
            public Material blitMaterial = null;
        }

        public BlitSettings settings = new BlitSettings();

        CloudRenderPass _cloudRenderPass;

        public override void Create()
        {
            _cloudRenderPass = new CloudRenderPass(settings.blitMaterial, name);
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            var src = renderer.cameraColorTarget;
            var dest = RenderTargetHandle.CameraTarget;

            if (settings.blitMaterial == null)
            {
                Debug.LogWarningFormat("Missing Blit Material. {0} blit pass will not execute. Check for missing reference in the assigned renderer.", GetType().Name);
                return;
            }

            _cloudRenderPass.Setup(src, dest);
            renderer.EnqueuePass(_cloudRenderPass);
        }
    }
}

