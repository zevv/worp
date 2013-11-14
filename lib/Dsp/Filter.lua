
-- 
-- The Filter module is a basic audio filter with configurable frequency, resonance and gain.
-- A number of different filter types are provided:
--
-- * hp: High pass
-- * lp: Low pass
-- * bp: Band pass
-- * bs: Band stop (aka, Notch)
-- * ls: Low shelf
-- * hs: High shelf
-- * ap: All pass
-- * eq: Peaking EQ filter
--
-- The code is based on a document from Robert Bristow-Johnson, check the original
-- at [http://www.musicdsp.org/files/Audio-EQ-Cookbook.txt] for more details
-- about the filter implementation
--

function Dsp:Filter(init)

	local fs = 44100
	local a0, a1, a2, b0, b1, b2
	local x0, x1, x2 = 0, 0, 0
	local y0, y1, y2 = 0, 0, 0

	local type, f, Q, gain

	return Dsp:Mod({
		description = "Biquad filter",
		controls = {
			fn_update = function()
				local w0 = 2 * math.pi * (f / fs)
				local alpha = math.sin(w0) / (2*Q)
				local cos_w0 = math.cos(w0)
				local A = math.pow(10, gain/40)

				if type == "hp" then
					b0, b1, b2 = (1 + cos_w0)/2, -(1 + cos_w0), (1 + cos_w0)/2
					a0, a1, a2 = 1 + alpha, -2*cos_w0, 1 - alpha

				elseif type == "lp" then
					b0, b1, b2 = (1 - cos_w0)/2, 1 - cos_w0, (1 - cos_w0)/2
					a0, a1, a2 = 1 + alpha, -2*cos_w0, 1 - alpha

				elseif type == "bp" then
					b0, b1, b2 = Q*alpha, 0, -Q*alpha
					a0, a1, a2 = 1 + alpha, -2*cos_w0, 1 - alpha

				elseif type == "bs" then
					b0, b1, b2 = 1, -2*cos_w0, 1
					a0, a1, a2 = 1 + alpha, -2*cos_w0, 1 - alpha

				elseif type == "ls" then
					local ap1, am1, tsAa = A+1, A-1, 2 * math.sqrt(A) * alpha
					local am1_cos_w0, ap1_cos_w0 = am1 * cos_w0, ap1 * cos_w0
					b0, b1, b2 = A*( ap1 - am1_cos_w0 + tsAa ), 2*A*( am1 - ap1_cos_w0 ), A*( ap1 - am1_cos_w0 - tsAa )
					a0, a1, a2 = ap1 + am1_cos_w0 + tsAa, -2*( am1 + ap1_cos_w0 ), ap1 + am1_cos_w0 - tsAa

				elseif type == "hs" then
					local ap1, am1, tsAa = A+1, A-1, 2 * math.sqrt(A) * alpha
					local am1_cos_w0, ap1_cos_w0 = am1 * cos_w0, ap1 * cos_w0
					b0, b1, b2 = A*( ap1 + am1_cos_w0 + tsAa ), -2*A*( am1 + ap1_cos_w0 ), A*( ap1 + am1_cos_w0 - tsAa )
					a0, a1, a2 = ap1 - am1_cos_w0 + tsAa, 2*( am1 - ap1_cos_w0 ), ap1 - am1_cos_w0 - tsAa

				elseif type == "eq" then
					b0, b1, b2 = 1 + alpha*A, -2*cos_w0, 1 - alpha*A
					a0, a1, a2 = 1 + alpha/A, -2*cos_w0, 1 - alpha/A

				elseif type == "ap" then
					b0, b1, b2 = 1 - alpha, -2*cos_w0, 1 + alpha
					a0, a1, a2 = 1 + alpha, -2*cos_w0, 1 - alpha

				else
					error("Unsupported filter type " .. type)
				end
			end,
			{
				id = "type",
				description = "Filter type",
				type = "enum",
				options =  { "lp", "hp", "bp", "bs", "ls", "hs", "eq", "ap" },
				default = "lp",
				fn_set = function(val) type = val end
			}, {
				id = "f",
				description = "Frequency",
				max = 20000,
				log = true,
				unit = "Hz",
				default = 440,
				fn_set = function(val) f = val end
			}, {
				id = "Q",
				description = "Resonance",
				min = 0.1,
				max = 100,
				log = true,
				default = 1,
				fn_set = function(val) Q = val end
			}, {
				id = "gain",
				description = "Shelf/EQ filter gain",
				min = -60,
				max = 60,
				unit = "dB",
				default = 0,
				fn_set = function(val) gain = val end
			}
		},

		fn_gen = function(x0)
			y2, y1 = y1, y0
			y0 = (b0 / a0) * x0 + (b1 / a0) * x1 + (b2 / a0) * x2 - (a1 / a0) * y1 - (a2 / a0) * y2
			x2, x1 = x1, x0
			return y0
		end
	}, init)

end

-- vi: ft=lua ts=3 sw=3
