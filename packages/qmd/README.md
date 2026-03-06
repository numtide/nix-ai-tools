# qmd

Mini CLI search engine for your docs, knowledge bases, meeting notes, whatever. Uses current SOTA approaches while being all local.

## GPU Acceleration

qmd bundles [node-llama-cpp](https://github.com/withcatai/node-llama-cpp) which supports GPU acceleration for embeddings.

### CUDA (NVIDIA)

CUDA is supported on x86_64-linux. Enable it with the `cudaSupport` override:

```nix
qmd.override { cudaSupport = true; }
```

### Vulkan

Vulkan support is enabled by default on Linux for AMD/Intel GPUs. To disable it:

```nix
qmd.override { vulkanSupport = false; }
```

## Links

- [GitHub](https://github.com/tobi/qmd)
