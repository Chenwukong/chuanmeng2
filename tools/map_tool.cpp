// map_tool.cpp — 命令行工具：从 .map 文件导出遮罩 BMP 和障碍物 BMP
// 编译方式（Windows MSVC）:
//   cd D:\Godot\传梦之路1.5\新建游戏项目\tools
//   cl /EHsc /Fe:map_tool.exe map_tool.cpp
// 用法: map_tool.exe xxx.map 输出目录/

#define _CRT_SECURE_NO_WARNINGS
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <vector>
#include <string>
#include <algorithm>
#include <cstdarg>

typedef unsigned char byte;
typedef unsigned short ushort;
typedef unsigned uint;

// ── libjpeg/compress.c 里的 LZSS decompress ──
static int decompress_lzss(void *in, unsigned in_len, void *out) {
    byte *op = (byte*)out, *ip = (byte*)in;
    unsigned t; byte *m_pos;

    if (*ip > 17) {
        t = *ip++ - 17;
        if (t < 4) goto match_next;
        do *op++ = *ip++; while (--t > 0);
        goto first_literal_run;
    }
    while (1) {
        t = *ip++;
        if (t >= 16) goto match;
        if (t == 0) { while (*ip == 0) { t += 255; ip++; } t += 15 + *ip++; }
        *(uint*)op = *(uint*)ip; op += 4; ip += 4;
        if (--t > 0) {
            if (t >= 4) { do { *(uint*)op = *(uint*)ip; op+=4; ip+=4; t-=4; } while (t>=4); if(t>0) do *op++=*ip++; while(--t>0); }
            else do *op++ = *ip++; while (--t > 0);
        }
first_literal_run:
        t = *ip++;
        if (t >= 16) goto match;
        m_pos = op - 0x0801 - (t>>2) - (*ip++ << 2);
        *op++ = *m_pos++; *op++ = *m_pos++; *op++ = *m_pos;
        goto match_done;
        while (1) {
match:
            if (t >= 64) { m_pos = op-1 - ((t>>2)&7) - (*ip++<<3); t=(t>>5)-1; goto copy_match; }
            else if (t >= 32) { t&=31; if(t==0){while(*ip==0){t+=255;ip++;}t+=31+*ip++;} m_pos=op-1 - ((*(ushort*)ip)>>2); ip+=2; }
            else if (t >= 16) { m_pos=op-((t&8)<<11); t&=7; if(t==0){while(*ip==0){t+=255;ip++;}t+=7+*ip++;} m_pos-=(*(ushort*)ip)>>2; ip+=2; if(m_pos==op) goto eof_found; m_pos-=0x4000; }
            else { m_pos=op-1-(t>>2)-(*ip++<<2); *op++=*m_pos++; *op++=*m_pos; goto match_done; }
            if (t>=6&&(op-m_pos)>=4) { *(uint*)op=*(uint*)m_pos; op+=4;m_pos+=4;t-=2; do{*(uint*)op=*(uint*)m_pos;op+=4;m_pos+=4;t-=4;}while(t>=4); if(t>0)do*op++=*m_pos++;while(--t>0); }
            else { copy_match: *op++=*m_pos++; *op++=*m_pos++; do*op++=*m_pos++; while(--t>0); }
match_done: t=ip[-2]&3; if(t==0) break; match_next: do*op++=*ip++;while(--t>0); t=*ip++;
        }
    }
eof_found: return (int)(op-(byte*)out);
}

static std::string ffmt(const char* f, ...) { char b[512]; va_list a; va_start(a,f); vsnprintf(b,sizeof(b),f,a); va_end(a); return b; }

static bool read_file(const char* p, std::vector<byte>& o) {
    FILE* f=fopen(p,"rb"); if(!f)return false; fseek(f,0,SEEK_END); long z=ftell(f); fseek(f,0,SEEK_SET); o.resize(z); fread(o.data(),1,z,f); fclose(f); return true;
}
static uint r32(const byte*& p) { uint v=*(uint*)p; p+=4; return v; }

static void write_bmp(const char* path, int w, int h, const byte* rgba) {
    FILE* f=fopen(path,"wb"); if(!f) return;
    int s=((w*3+3)/4)*4, is=s*h;
    byte hdr[54]={}; hdr[0]='B';hdr[1]='M'; *(int*)(hdr+2)=54+is; *(int*)(hdr+10)=54;
    *(int*)(hdr+14)=40; *(int*)(hdr+18)=w; *(int*)(hdr+22)=h; *(short*)(hdr+26)=1; *(short*)(hdr+28)=24;
    fwrite(hdr,1,54,f); std::vector<byte> row(s);
    for(int y=h-1;y>=0;--y){for(int x=0;x<w;++x){int i=(y*w+x)*4;row[x*3+0]=rgba[i+2];row[x*3+1]=rgba[i+1];row[x*3+2]=rgba[i+0];}fwrite(row.data(),1,s,f);}
    fclose(f);
}

int main(int argc, char** argv) {
    if(argc<3){printf("用法: map_tool.exe <地图.map> <输出目录>\n");return 1;}
    const char* mp=argv[1],*od=argv[2];
    std::vector<byte> d; if(!read_file(mp,d)){printf("无法打开 %s\n",mp);return 1;}
    const byte* p=d.data(); uint fl=r32(p),mw=r32(p),mh=r32(p);
    if(fl!=0x4D312E30&&fl!=0x5850414D){printf("格式错误 0x%X\n",fl);return 1;}
    int is_m10=(fl==0x4D312E30),bw=(mw+319)/320,bh=(mh+239)/240,bc=bw*bh;
    std::vector<uint> bo(bc); for(int i=0;i<bc;i++) bo[i]=r32(p);

    uint mso=0; int mc=0; std::vector<uint> md;
    if(is_m10){mso=r32(p); const byte* sv=p; p=d.data()+mso; mc=r32(p); md.resize(mc); for(int i=0;i<mc;i++) md[i]=r32(p); p=sv;}
    printf("地图 %ux%u 遮罩%d\n",mw,mh,mc);

    // 遮罩
    for(int mi=0;mi<mc;mi++){p=d.data()+md[mi]; int rx=r32(p),ry=r32(p),rw=r32(p),rh=r32(p),ds=r32(p);
        if(ds<=0||rw<=0||rh<=0)continue;
        int aw=((rw+3)/4)*4; std::vector<byte> raw(ds); memcpy(raw.data(),p,ds); p+=ds;
        std::vector<byte> dec((aw*rh)/4+16); int dl=decompress_lzss(raw.data(),ds,dec.data());
        std::vector<byte> rgba(rw*rh*4,0); int ok=0;
        for(int y=0;y<rh;y++)for(int x=0;x<rw;x++){int bi=(y*aw+x)*2,byi=bi>>3;
            if(byi<dl&&((dec[byi]>>(bi&7))&3)==3){int i=(y*rw+x)*4;rgba[i]=255;rgba[i+1]=50;rgba[i+2]=50;rgba[i+3]=140;ok++;}
        }
        if(ok>0){std::string fn=ffmt("%s/mask_%04d_%dx%d_x%d_y%d.bmp",od,mi,rw,rh,rx,ry);write_bmp(fn.c_str(),rw,rh,rgba.data());}
    }

    // 障碍物
    int cc=16,cr=12,cpx=20,ow=bw*cc,oh=bh*cr;
    std::vector<byte> og(ow*oh,0);
    for(int bi=0;bi<bc;bi++){p=d.data()+bo[bi]; int nr=r32(p); if(is_m10&&nr>0)p+=nr*4;
        while(p<d.data()+d.size()){uint tg=r32(p),sz=r32(p);
            if(tg==0x43454C4C){int br=bi/bw,bc2=bi%bw,bs=br*cr*ow+bc2*cc;
                for(int cy=0;cy<cr&&cy<(int)sz/cc;cy++)for(int cx=0;cx<cc;cx++){int si=cy*cc+cx;if(si>=(int)sz)break;
                    byte v=p[si];int gi=bs+cy*ow+cx;if(gi<(int)og.size()) og[gi]=(v!=0&&v!=2)?1:0;}p+=sz;break;}
            else if(tg==0){if(sz>0)p+=sz;break;}else{if(sz>0)p+=sz;}
        }
    }
    int fw=ow*cpx,fh=oh*cpx; std::vector<byte> ori(fw*fh*4,0);
    for(int gy=0;gy<oh;gy++)for(int gx=0;gx<ow;gx++)if(og[gy*ow+gx]!=0)
        for(int py=0;py<cpx;py++)for(int px=0;px<cpx;px++){int i=((gy*cpx+py)*fw+(gx*cpx+px))*4;ori[i]=0;ori[i+1]=0;ori[i+2]=255;ori[i+3]=90;}
    write_bmp(ffmt("%s/obstacles.bmp",od).c_str(),fw,fh,ori.data());
    printf("障碍物 %dx%d 完成\n",fw,fh); return 0;
}
