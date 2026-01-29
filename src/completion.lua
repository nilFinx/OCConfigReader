---@class kext
local kext = {
	Arch = "Any", -- sometimes x86_64, etc. abnormal.
	BundlePath = "Example.kext",
	Comment = "V6.9.0 | IAMNOTANOCATUSER", -- normally BundlePath or user specified
	Enabled = true,
	ExecutablePath = "Contents/MacOS/Example", --can be empty
	MaxKernel = "12.34.5",
	MinKernel = "5.43.21",
	PlistPath = "Contents/Info.plist", -- Almost always this
}