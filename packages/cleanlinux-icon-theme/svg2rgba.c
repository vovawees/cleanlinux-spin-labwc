/* svg2rgba: draws an SVG with NanoSVG at the sizes asked, for the icon theme of the labwc spin.
 *
 *   svg2rgba IN.svg RRGGBB|- SIZE...
 *
 * For every SIZE it writes SIZE x SIZE pixels to stdout, 4 bytes each (RGBA, not premultiplied),
 * the image scaled to fit and centred. With a colour every pixel gets it and keeps its alpha: a
 * symbolic icon, which GTK recolours with the text colour of the theme. icons.py makes the PNGs:
 * the build machine needs a C compiler and Python, no libpng.
 *
 * SPDX-License-Identifier: MIT
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define NANOSVG_IMPLEMENTATION
#define NANOSVG_ALL_COLOR_KEYWORDS
#include "nanosvg.h"
#define NANOSVGRAST_IMPLEMENTATION
#include "nanosvgrast.h"

int main(int argc, char **argv)
{
	if (argc < 4) {
		fprintf(stderr, "usage: svg2rgba IN.svg RRGGBB|- SIZE...\n");
		return 2;
	}
	unsigned long color = 0;
	int recolor = strcmp(argv[2], "-") != 0;
	if (recolor) {
		char *end;
		color = strtoul(argv[2], &end, 16);
		if (strlen(argv[2]) != 6 || *end) {
			fprintf(stderr, "svg2rgba: bad colour %s (RRGGBB)\n", argv[2]);
			return 2;
		}
	}
	NSVGimage *image = nsvgParseFromFile(argv[1], "px", 96.0f);
	if (!image || !(image->width > 0.0f) || !(image->height > 0.0f)) {
		fprintf(stderr, "svg2rgba: %s: not an SVG image with a size\n", argv[1]);
		return 1;
	}
	NSVGrasterizer *rast = nsvgCreateRasterizer();
	if (!rast) {
		fprintf(stderr, "svg2rgba: out of memory\n");
		return 1;
	}
	for (int a = 3; a < argc; a++) {
		int s = atoi(argv[a]);
		if (s < 1 || s > 4096) {
			fprintf(stderr, "svg2rgba: bad size %s\n", argv[a]);
			return 2;
		}
		size_t n = (size_t)s * (size_t)s;
		unsigned char *pixels = calloc(n, 4);
		if (!pixels) {
			fprintf(stderr, "svg2rgba: out of memory\n");
			return 1;
		}
		float sx = (float)s / image->width, sy = (float)s / image->height, scale = sx < sy ? sx : sy;
		nsvgRasterize(rast, image, ((float)s - image->width * scale) / 2.0f,
			      ((float)s - image->height * scale) / 2.0f, scale, pixels, s, s, s * 4);
		for (size_t i = 0; recolor && i < n; i++) {
			pixels[i * 4] = (unsigned char)(color >> 16);
			pixels[i * 4 + 1] = (unsigned char)(color >> 8);
			pixels[i * 4 + 2] = (unsigned char)color;
		}
		if (fwrite(pixels, 4, n, stdout) != n) {
			perror("svg2rgba: stdout");
			return 1;
		}
		free(pixels);
	}
	nsvgDeleteRasterizer(rast);
	nsvgDelete(image);
	return fflush(stdout) == 0 ? 0 : 1;
}
