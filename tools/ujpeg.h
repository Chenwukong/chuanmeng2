// uJPEG (MicroJPEG) -- KeyJ's Small Baseline JPEG Decoder
// based on NanoJPEG -- KeyJ's Tiny Baseline JPEG Decoder
// version 1.3.5 (2016-11-14)
// Copyright (c) 2009-2016 Martin J. Fiedler <martin.fiedler@gmx.net>
// MIT license - see ujpeg.cpp for full text
#pragma once
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct { uint8_t* data; int size; int width, height; int components; } ujpeg_t;
int ujpeg_decode(ujpeg_t* jpeg, const uint8_t* data, int size);
void ujpeg_get_image(ujpeg_t* jpeg, uint8_t* out, int stride, int format);
void ujpeg_free(ujpeg_t* jpeg);
#ifdef __cplusplus
}
#endif
