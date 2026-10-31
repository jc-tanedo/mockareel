#!/usr/bin/env python3
"""Execute the production source-edit GLSL on a headless Mesa GLES context.

Optional Linux GPU smoke check. Requires libEGL with surfaceless Mesa support;
no Python packages, Android device, network or application media are needed.
"""
import ctypes as c
from pathlib import Path
import re


def main():
    source = (Path(__file__).resolve().parents[1] / 'android/app/src/main/kotlin/dev/mockareel/mockareel/MediaEditsEffect.kt').read_text()
    vertex = re.search(r'VERTEX = """(.*?)"""', source, re.S).group(1)
    fragment = re.search(r'private fun fragment\(\) = """(.*?)"""', source, re.S).group(1)
    fragment = '\n'.join(
        '\n'.join(f'uniform vec3 uSpot{i};' for i in range(8)) if '${' in line and 'uniform vec3' in line else
        '\n'.join(f'color = spot(color, p, uSpot{i});' for i in range(8)) if '${' in line else line
        for line in fragment.splitlines()
    )
    egl = c.CDLL('libEGL.so.1')
    egl.eglGetProcAddress.argtypes = [c.c_char_p]
    egl.eglGetProcAddress.restype = c.c_void_p

    def proc(name, result, *args):
        pointer = egl.eglGetProcAddress(name.encode())
        if not pointer:
            raise RuntimeError(f'{name} is unavailable')
        return c.CFUNCTYPE(result, *args)(pointer)

    ptr, integer, uint, flt = c.c_void_p, c.c_int, c.c_uint, c.c_float
    display = proc('eglGetPlatformDisplayEXT', ptr, uint, ptr, ptr)(0x31DD, None, None)
    major, minor = integer(), integer()
    assert proc('eglInitialize', uint, ptr, ptr, ptr)(display, c.byref(major), c.byref(minor))
    assert proc('eglBindAPI', uint, uint)(0x30A0)  # OpenGL ES
    attributes = (integer * 13)(0x3033, 1, 0x3040, 4, 0x3024, 8, 0x3023, 8, 0x3022, 8, 0x3021, 8, 0x3038)
    config, count = ptr(), integer()
    assert proc('eglChooseConfig', uint, ptr, ptr, ptr, integer, ptr)(display, attributes, c.byref(config), 1, c.byref(count)) and count.value
    surface = proc('eglCreatePbufferSurface', ptr, ptr, ptr, ptr)(display, config, (integer * 5)(0x3057, 64, 0x3056, 64, 0x3038))
    context = proc('eglCreateContext', ptr, ptr, ptr, ptr, ptr)(display, config, None, (integer * 3)(0x3098, 2, 0x3038))
    assert proc('eglMakeCurrent', uint, ptr, ptr, ptr, ptr)(display, surface, surface, context)

    def compile_shader(kind, text):
        shader = proc('glCreateShader', uint, uint)(kind)
        data = c.c_char_p(text.encode())
        proc('glShaderSource', None, uint, integer, ptr, ptr)(shader, 1, c.byref(data), None)
        proc('glCompileShader', None, uint)(shader)
        status = integer()
        proc('glGetShaderiv', None, uint, uint, ptr)(shader, 0x8B81, c.byref(status))
        if not status.value:
            log = c.create_string_buffer(16384)
            proc('glGetShaderInfoLog', None, uint, integer, ptr, ptr)(shader, len(log), None, log)
            raise AssertionError(log.value.decode())
        return shader

    program = proc('glCreateProgram', uint)()
    for kind, text in [(0x8B31, vertex), (0x8B30, fragment)]:
        proc('glAttachShader', None, uint, uint)(program, compile_shader(kind, text))
    proc('glLinkProgram', None, uint)(program)
    status = integer()
    proc('glGetProgramiv', None, uint, uint, ptr)(program, 0x8B82, c.byref(status))
    assert status.value, 'Shader link failed'
    proc('glUseProgram', None, uint)(program)
    uniform = proc('glGetUniformLocation', integer, uint, c.c_char_p)
    position = proc('glGetAttribLocation', integer, uint, c.c_char_p)(program, b'aPosition')
    vertices = (flt * 16)(-1, -1, 0, 1, 1, -1, 0, 1, -1, 1, 0, 1, 1, 1, 0, 1)
    proc('glEnableVertexAttribArray', None, uint)(position)
    proc('glVertexAttribPointer', None, uint, integer, uint, uint, integer, ptr)(position, 4, 0x1406, 0, 0, vertices)
    texture = uint()
    proc('glGenTextures', None, integer, ptr)(1, c.byref(texture))
    proc('glBindTexture', None, uint, uint)(0x0DE1, texture)
    for name, value in [(0x2801, 0x2601), (0x2800, 0x2601), (0x2802, 0x812F), (0x2803, 0x812F)]:
        proc('glTexParameteri', None, uint, uint, integer)(0x0DE1, name, value)
    pixels = bytes(component for y in range(64) for x in range(64)
                   for component in (x * 4, y * 4, (x * 17 + y * 23 + x * y * 11) % 256, 255))
    data = (c.c_ubyte * len(pixels)).from_buffer_copy(pixels)
    proc('glTexImage2D', None, uint, integer, integer, integer, integer, integer, uint, uint, ptr)(0x0DE1, 0, 0x1908, 64, 64, 0, 0x1908, 0x1401, data)
    proc('glUniform1i', None, integer, integer)(uniform(program, b'uSource'), 0)
    proc('glUniform2f', None, integer, flt, flt)(uniform(program, b'uSize'), 64, 64)
    spot_uniforms = [uniform(program, f'uSpot{i}'.encode()) for i in range(8)]
    assert all(location >= 0 for location in spot_uniforms)
    for location in spot_uniforms:
        proc('glUniform3f', None, integer, flt, flt, flt)(location, 0, 0, 0)
    proc('glViewport', None, integer, integer, integer, integer)(0, 0, 64, 64)

    def render(strength):
        proc('glUniform1f', None, integer, flt)(uniform(program, b'uStrength'), strength)
        proc('glDrawArrays', None, uint, integer, integer)(0x0005, 0, 4)
        output = (c.c_ubyte * len(pixels))()
        proc('glReadPixels', None, integer, integer, integer, integer, uint, uint, ptr)(0, 0, 64, 64, 0x1908, 0x1401, output)
        assert proc('glGetError', uint)() == 0, 'OpenGL error'
        return bytes(output)

    original = render(0)
    assert max(abs(a - b) for a, b in zip(original, pixels)) <= 1, 'Zero strength must preserve source pixels'
    distorted = render(.8)
    at = lambda x, y, channel=0: (y * 64 + x) * 4 + channel
    assert distorted[at(16, 32)] > original[at(16, 32)] + 8, 'Fisheye must magnify the center'
    assert abs(distorted[at(32, 32)] - original[at(32, 32)]) <= 2, 'Lens center must stay fixed'
    proc('glUniform3f', None, integer, flt, flt, flt)(spot_uniforms[0], .3, .25, .15)
    blurred = render(0)
    assert abs(blurred[at(19, 47, 2)] - original[at(19, 47, 2)]) > 20, 'Spot must blur its chosen source region'
    assert blurred[at(50, 50):at(50, 50) + 4] == original[at(50, 50):at(50, 50) + 4], 'Pixels outside spots must stay untouched'
    assert blurred[at(19, 16):at(19, 16) + 4] == original[at(19, 16):at(19, 16) + 4], 'Spot coordinates must use the editor top-left origin'
    proc('eglMakeCurrent', uint, ptr, ptr, ptr, ptr)(display, None, None, None)
    proc('eglDestroyContext', uint, ptr, ptr)(display, context)
    proc('eglDestroySurface', uint, ptr, ptr)(display, surface)
    proc('eglTerminate', uint, ptr)(display)
    print('Production GLSL compiled and rendered: identity, fisheye, blur isolation and coordinate orientation passed.')


if __name__ == '__main__':
    main()
