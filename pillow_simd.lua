
--Pillow SIMD Lua binding.
--Written by Cosmin Apreutesei. Public Domain.

local ffi = require'ffi'
local C = ffi.load'pillow_simd'

ffi.cdef[[

typedef struct _pillow_simd_image_t pillow_simd_image_t;

pillow_simd_image_t* pillow_simd_image_create_for_data(
	char *data, char* mode, int w, int h, int stride, int bottom_up);

void pillow_simd_image_free(pillow_simd_image_t*);

int    pillow_simd_image_width  (Imaging im);
int    pillow_simd_image_height (Imaging im);
char*  pillow_simd_image_mode   (Imaging im);
char** pillow_simd_image_rows   (Imaging im);

pillow_simd_image_t* pillow_simd_resample(
	pillow_simd_image_t* im, int w, int h, int filter);

]]

local pil = {}

local function ptr(p) return p ~= nil and p or nil end

local modes = {
	rgbx8 = 'RGB',
	rgba8 = 'RGBA',
	cmyk8 = 'CMYK',
	yccx8 = 'YCbCr', --not in bitmap module
	labx8 = 'Lab', --not in bitmap module
}

local formats = {}
for k,v in pairs(modes) do formats[v] = k end

function pil.image(bmp)
	local mode = assert(modes[bmp.format], 'unsupported format')
	return assert(ptr(C.pillow_simd_image_create_for_data(
		bmp.data, mode, bmp.w, bmp.h, bmp.stride, bmp.bottom_up and 1 or 0)))
end

local function resize(im, w, h, filter)
	return assert(ptr(C.pillow_simd_resample(
		im, w, h, assert(filters[filter], 'unknown filter'))))
end

local function to_bitmap(im)
	local w = im:width()
	local h = im:height()
	local stride = w * 4
	return {
		format = formats[im:mode()],
		w = w, h = h, stride = stride, size = stride * h,
		rows = im:rows(),
	}
end

ffi.metatype('pillow_simd_image_t', {__index = {
	free = C.pillow_simd_image_free,
	rows = C.pillow_simd_image_rows,
	w    = C.pillow_simd_image_width,
	h    = C.pillow_simd_image_height,
	mode = function(im) return ffi.string(C.pillow_simd_image_mode(im)) end,
	bitmap = to_bitmap,
	resize = resize,
}})


--self-test ------------------------------------------------------------------

if not ... then

local function resize_image(src_path, dst_path, max_w, max_h)

	local fs = require'fs'
	local box2d = require'box2d'
	local libjpeg = require'libjpeg'

	--load.
	local f = assert(fs.open(src_path, 'r'), 'not_found')
	local read = f:buffered_read()
	local img = assert(libjpeg.open{read = read})
	local w, h = box2d.fit(img.w, img.h, max_w, max_h)
	local sn = math.ceil(glue.clamp(math.max(w / img.w, h / img.h) * 8, 1, 8))
	bmp = assert(img:load{
		accept = {rgba8 = true},
		scale_num = sn,
		scale_denom = 8,
	})
	f:close()

	--resize.
	local w, h = box2d.fit(bmp.w, bmp.h, max_w, max_h)
	local img1 = pil.image(bmp)
	local img2 = img1:resize(w, h)
	img1:free()
	local bmp = img2:bitmap()

	--save.
	local tmp_path = dst_path..'.tmp'
	mkdirs(tmp_path)
	local f = assert(fs.open(tmp_path, 'w'))
	finally(function() if f then f:close() end end)
	local function write(buf, len)
		assert(f:write(buf, len) == len)
	end
	assert(libjpeg.save{
		bitmap = bmp,
		write = write,
		quality = 90,
	})
	f:close()

end

resize_image('', '', 200, 200)

end
