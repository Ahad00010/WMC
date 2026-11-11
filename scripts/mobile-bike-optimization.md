# Mobile bike model

`bike-mobile-low.glb` is derived from the existing `bike-mobile.glb` using glTF Transform 4.5.1 with meshoptimizer simplification. It retains the original materials, textures, and named wheel nodes. The original file remains in use for desktop opponents.

```sh
gltf-transform weld bike-mobile.glb /tmp/bike-weld.glb
gltf-transform simplify /tmp/bike-weld.glb bike-mobile-low.glb --ratio 0.2 --error 0.02
```
