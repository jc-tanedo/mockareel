package dev.mockareel.mockareel

import android.content.Context
import android.opengl.GLES20
import androidx.media3.common.VideoFrameProcessingException
import androidx.media3.common.util.GlProgram
import androidx.media3.common.util.GlUtil
import androidx.media3.common.util.Size
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BaseGlShaderProgram
import androidx.media3.effect.GlEffect
import androidx.media3.effect.GlShaderProgram

internal data class SpotSpec(val x: Float, val y: Float, val radius: Float)
internal data class MediaEditSpec(val strength: Float, val spots: List<SpotSpec>) {
    companion object {
        fun from(data: Map<String, Any>, video: Boolean = false): MediaEditSpec {
            fun number(value: Any?, default: Float, min: Float, max: Float): Float {
                val n = (value as? Number)?.toFloat() ?: default
                require(n.isFinite()) { "Invalid media effect value" }
                return n.coerceIn(min, max)
            }
            val strength = (if (data["fisheye"] == true) number(data["strength"], .35f, 0f, 1f) else 0f) * (if (data["lens"] == "pincushion") -1 else 1)
            val raw = data["spots"] as? List<*> ?: emptyList<Any>()
            require(raw.size <= 8) { "Too many blur spots" }
            return MediaEditSpec(strength, (if (video) emptyList<Any>() else raw).map {
                val spot = it as Map<*, *>
                SpotSpec(number(spot["x"], .5f, 0f, 1f), number(spot["y"], .5f, 0f, 1f), number(spot["radius"], .1f, .025f, .3f))
            })
        }
    }
}

/** Processes source pixels before the template crops or composites any UI. */
@UnstableApi
internal class MediaEditsEffect(private val spec: MediaEditSpec) : GlEffect {
    override fun toGlShaderProgram(context: Context, useHdr: Boolean): GlShaderProgram =
        try { SourceShader(spec) } catch (e: Exception) { throw VideoFrameProcessingException(e) }
}

@UnstableApi
private class SourceShader(private val spec: MediaEditSpec) : BaseGlShaderProgram(false, 1) {
    private val program = GlProgram(VERTEX, fragment())
    init {
        program.setBufferAttribute("aPosition", GlUtil.getNormalizedCoordinateBounds(), 4)
        program.setFloatUniform("uStrength", spec.strength)
        for (i in 0..7) {
            val s = spec.spots.getOrNull(i)
            program.setFloatsUniform("uSpot$i", floatArrayOf(s?.x ?: 0f, s?.y ?: 0f, s?.radius ?: 0f))
        }
    }
    override fun configure(inputWidth: Int, inputHeight: Int): Size {
        program.setFloatsUniform("uSize", floatArrayOf(inputWidth.toFloat(), inputHeight.toFloat()))
        return Size(inputWidth, inputHeight)
    }
    override fun drawFrame(inputTexId: Int, presentationTimeUs: Long) {
        try {
            program.use()
            program.setSamplerTexIdUniform("uSource", inputTexId, 0)
            program.bindAttributesAndUniforms()
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
            GlUtil.checkGlError()
        } catch (e: Exception) { throw VideoFrameProcessingException(e, presentationTimeUs) }
    }
    override fun release() {
        super.release()
        try { program.delete() } catch (e: Exception) { throw VideoFrameProcessingException(e) }
    }
    companion object {
        private const val VERTEX = """
            attribute vec4 aPosition;
            varying vec2 vUv;
            void main() { gl_Position = aPosition; vUv = aPosition.xy * 0.5 + 0.5; }
        """
        // Separate vec3 uniforms avoid driver-specific limits for uniform arrays.
        private fun fragment() = """
            precision highp float;
            uniform sampler2D uSource;
            uniform vec2 uSize;
            uniform float uStrength;
            ${(0..7).joinToString("\n") { "uniform vec3 uSpot$it;" }}
            varying vec2 vUv;
            vec4 source(vec2 p) {
                vec2 q = (p - 0.5) * uSize;
                float r2 = min(dot(q, q) / dot(uSize * 0.5, uSize * 0.5), 1.0);
                float crop = uStrength < 0.0 ? 1.0 + abs(uStrength) * 0.55 : 1.0;
                vec2 warped = 0.5 + (p - 0.5) * (1.0 - uStrength * 0.55 * (1.0 - r2)) / crop;
                return texture2D(uSource, vec2(warped.x, 1.0 - warped.y));
            }
            vec4 spot(vec4 color, vec2 p, vec3 s) {
                if (s.z <= 0.0) return color;
                float shortSide = min(uSize.x, uSize.y);
                float d = length((p - s.xy) * uSize) / (s.z * shortSide);
                if (d >= 1.0) return color;
                vec2 stepSize = vec2(s.z * shortSide * 0.22) / uSize;
                vec4 blurred = vec4(0.0);
                float weight = 0.0;
                for (int y = -3; y <= 3; y++) {
                    for (int x = -3; x <= 3; x++) {
                        vec2 k = vec2(float(x), float(y));
                        float w = exp(-dot(k, k) / 4.5);
                        blurred += source(clamp(p + k * stepSize, 0.0, 1.0)) * w;
                        weight += w;
                    }
                }
                return mix(color, blurred / weight, 1.0 - smoothstep(0.82, 1.0, d));
            }
            void main() {
                vec2 p = vec2(vUv.x, 1.0 - vUv.y);
                vec4 color = source(p);
                ${(0..7).joinToString("\n") { "color = spot(color, p, uSpot$it);" }}
                gl_FragColor = color;
            }
        """
    }
}
