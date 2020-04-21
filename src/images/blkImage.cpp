/*
 *  blkImage.cpp
 *  openc2e
 *
 *  Created by Alyssa Milburn on Tue May 25 2004.
 *  Copyright (c) 2004 Alyssa Milburn. All rights reserved.
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 */

#include "openc2e.h"
#include "blkImage.h"
#include "endianlove.h"
#include <cassert>
#include <iostream>

void blkImage::readHeader(std::istream &in) {
	uint32_t flags; uint16_t width, height, spritecount;
	in.read((char *)&flags, 4); flags = swapEndianLong(flags);
	is_565 = (flags & 0x01);
	in.read((char *)&width, 2); width = swapEndianShort(width);
	in.read((char *)&height, 2); height = swapEndianShort(height);
	totalwidth = width * 128; totalheight = height * 128;
	in.read((char *)&spritecount, 2); m_numframes = swapEndianShort(spritecount);
	
	assert(m_numframes == (unsigned int) (width * height));	

	widths = new uint16_t[m_numframes];
	heights = new uint16_t[m_numframes];
	offsets = new uint32_t[m_numframes];

	for (unsigned int i = 0; i < m_numframes; i++) {
		in.read((char *)&offsets[i], 4); offsets[i] = swapEndianLong(offsets[i]) + 4;
		in.read((char *)&widths[i], 2); widths[i] = swapEndianShort(widths[i]); assert(widths[i] == 128);
		in.read((char *)&heights[i], 2); heights[i] = swapEndianShort(heights[i]); assert(heights[i] == 128);
	}
}

blkImage::blkImage(std::ifstream &in, std::string n) : creaturesImage(n) {
	imgformat = if_16bit;

	readHeader(in);
	
	buffers = new void *[m_numframes];
	
	for (unsigned int i = 0; i < m_numframes; i++) {
		buffers[i] = new char[2 * widths[i] * heights[i]];
		in.seekg(offsets[i]);
		readmany16le(in, (uint16_t*)buffers[i], widths[i] * heights[i]);
	}
}

blkImage::~blkImage() {
	delete[] widths;
	delete[] heights;
	for (unsigned int i = 0; i < m_numframes; i++) {
		delete[] (char*)buffers[i];
	}
	delete[] buffers;
	delete[] offsets;
}

/* vim: set noet: */
