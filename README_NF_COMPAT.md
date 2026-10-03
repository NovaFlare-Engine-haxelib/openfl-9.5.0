# NovaFlare additive compatibility interfaces

Restores legacy Shader compilation and NativeWindow construction/close behavior. The build macro only appends missing interfaces and never rewrites existing shader methods. The added depth command is accepted only when explicitly called and no longer injected into legacy Flixel batches. Existing command enum order and existing shader/render implementations are retained. Optional sensor and multi-buffer APIs remain unsupported stubs.

The earlier broad integration changed existing behavior and is superseded by this repair. Compatibility additions must preserve existing NF calls, defaults and update/render/audio paths. Unsupported additions may return a neutral result instead of replacing a legacy implementation.

Windows x64 and Android ARMv7/ARM64/x86_64 native Lime binaries have been rebuilt. The full game targets Windows x64 and Android ARM64. Visual gameplay acceptance is performed manually by the project owner.
