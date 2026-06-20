// map2png.cpp - 将 0.1M/XPAM 格式 .map 地图块解码为 TGA
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <vector>
#include "tools/ujpeg_orig.h"

#define BLOCK_W 320
#define BLOCK_H 240

uint32_t read_u32(const uint8_t* d, int p) {
    return (uint32_t)d[p] | ((uint32_t)d[p + 1] << 8) | ((uint32_t)d[p + 2] << 16) | ((uint32_t)d[p + 3] << 24);
}

void write_tga(const char* path, const uint8_t* rgb, int w, int h) {
    FILE* f = fopen(path, "wb");
    if (!f) return;
    uint8_t hdr[18] = {0};
    hdr[2] = 2;
    hdr[12] = w & 0xFF; hdr[13] = (w >> 8) & 0xFF;
    hdr[14] = h & 0xFF; hdr[15] = (h >> 8) & 0xFF;
    hdr[16] = 24;
    fwrite(hdr, 1, 18, f);
    std::vector<uint8_t> bgr(w * h * 3);
    for (int i = 0; i < w * h; i++) {
        bgr[i * 3] = rgb[i * 3 + 2];
        bgr[i * 3 + 1] = rgb[i * 3 + 1];
        bgr[i * 3 + 2] = rgb[i * 3];
    }
    fwrite(bgr.data(), 1, w * h * 3, f);
    fclose(f);
}

void jpeg_repair(const uint8_t* Buffer, uint32_t inSize, uint8_t* outBuffer, uint32_t* outSize) {
    uint32_t TempNum = 0;
    uint16_t TempTimes = 0;
    uint32_t Temp = 0;
    bool break_while = false;
    const uint8_t* src = Buffer;

    while (!break_while && TempNum < inSize && *Buffer++ == 0xFF) {
        *outBuffer++ = 0xFF;
        TempNum++;
        switch (*Buffer) {
        case 0xD8:
            *outBuffer++ = 0xD8; Buffer++; TempNum++;
            break;
        case 0xA0:
            Buffer++; outBuffer--; TempNum++;
            break;
        case 0xC0:
            *outBuffer++ = 0xC0; Buffer++; TempNum++;
            memcpy(&TempTimes, Buffer, sizeof(uint16_t));
            for (int i = 0; i < TempTimes; i++) { *outBuffer++ = *Buffer++; TempNum++; }
            break;
        case 0xC4:
            *outBuffer++ = 0xC4; Buffer++; TempNum++;
            memcpy(&TempTimes, Buffer, sizeof(uint16_t));
            for (int i = 0; i < TempTimes; i++) { *outBuffer++ = *Buffer++; TempNum++; }
            break;
        case 0xDB:
            *outBuffer++ = 0xDB; Buffer++; TempNum++;
            memcpy(&TempTimes, Buffer, sizeof(uint16_t));
            for (int i = 0; i < TempTimes; i++) { *outBuffer++ = *Buffer++; TempNum++; }
            break;
        case 0xDA:
            *outBuffer++ = 0xDA;
            *outBuffer++ = 0x00;
            *outBuffer++ = 0x0C;
            Buffer++; TempNum++;
            memcpy(&TempTimes, Buffer, sizeof(uint16_t));
            Buffer++; TempNum++; Buffer++;
            for (int i = 2; i < TempTimes; i++) { *outBuffer++ = *Buffer++; TempNum++; }
            *outBuffer++ = 0x00; *outBuffer++ = 0x3F; *outBuffer++ = 0x00;
            Temp += 1;
            for (; TempNum < inSize - 2;) {
                if (*Buffer == 0xFF) {
                    *outBuffer++ = 0xFF; *outBuffer++ = 0x00;
                    Buffer++; TempNum++; Temp++;
                } else {
                    *outBuffer++ = *Buffer++; TempNum++;
                }
            }
            Temp--; outBuffer--; *outBuffer-- = 0xD9;
            break;
        case 0xD9:
            *outBuffer++ = 0xD9; TempNum++;
            break;
        case 0xE0:
            break_while = true;
            while (TempNum < inSize) { *outBuffer++ = *Buffer++; TempNum++; }
            break;
        default: break;
        }
    }
    Temp += inSize;
    *outSize = Temp;
}

int main(int argc, char** argv) {
    if (argc < 3) {
        fprintf(stderr, "Usage: tools/map2png.exe <map_file.map> <output_dir>\n");
        return 1;
    }

    FILE* f = fopen(argv[1], "rb");
    if (!f) { fprintf(stderr, "无法打开: %s\n", argv[1]); return 1; }
    fseek(f, 0, SEEK_END);
    long fsize = ftell(f);
    fseek(f, 0, SEEK_SET);
    std::vector<uint8_t> data(fsize);
    fread(data.data(), 1, fsize, f);
    fclose(f);

    char flag[5] = {0};
    memcpy(flag, data.data(), 4);
    int w = (int)read_u32(data.data(), 4);
    int h = (int)read_u32(data.data(), 8);
    int colNum = (w + BLOCK_W - 1) / BLOCK_W;
    int rowNum = (h + BLOCK_H - 1) / BLOCK_H;
    int blockNum = rowNum * colNum;
    printf("地图: %s %dx%d 块=%d 行=%d 列=%d\n", flag, w, h, blockNum, rowNum, colNum);

    int pos = 12;
    std::vector<uint32_t> blockOff(blockNum);
    for (int i = 0; i < blockNum; i++) { blockOff[i] = read_u32(data.data(), pos); pos += 4; }
    pos += 4;

    if (strcmp(flag, "0.1M") == 0) {
        int mc = (int)read_u32(data.data(), pos); pos += 4;
        pos += mc * 4;
    }

    int ok = 0, fail = 0;
    for (int bi = 0; bi < blockNum; bi++) {
        int p = (int)blockOff[bi];
        int eat = (int)read_u32(data.data(), p); p += 4;
        if (strcmp(flag, "0.1M") == 0) p += eat * 4;

        int jOff = 0, jSz = 0;
        bool found = false;
        for (int t = 0; t < 20; t++) {
            char tag[5] = {0};
            memcpy(tag, data.data() + p, 4);
            int sz = (int)read_u32(data.data(), p + 4);
            if (strcmp(tag, "GEPJ") == 0 || strcmp(tag, "2GPJ") == 0) {
                jOff = p + 8; jSz = sz; found = true; break;
            }
            p += 8 + sz;
        }
        if (!found) { fail++; continue; }

        uint8_t* jpeg = data.data() + jOff;
        std::vector<uint8_t> buf(jSz * 2 + 100);
        uint32_t repairedSz = 0;
        jpeg_repair(jpeg, (uint32_t)jSz, buf.data(), &repairedSz);
        buf.resize(repairedSz);

        ujImage img = ujCreate();
        img = ujDecode(img, buf.data(), (int)buf.size(), false);
        if (!img || !ujIsValid(img)) {
            // XPAM 或解码失败
            ujFree(img);
            // 重试 XPAM：前加 JPEG 头
            fail++; continue;
        }

        int iw = ujGetWidth(img), ih = ujGetHeight(img);
        std::vector<uint8_t> rgb(ujGetImageSize(img));
        ujGetImage(img, rgb.data());

        char out[512];
        snprintf(out, sizeof(out), "%s/block_%d.tga", argv[2], bi);
        write_tga(out, rgb.data(), iw, ih);
        ujFree(img);
        ok++;
    }

    printf("结果: 成功 %d / 失败 %d / 共 %d\n", ok, fail, blockNum);
    return ok > 0 ? 0 : 1;
}
