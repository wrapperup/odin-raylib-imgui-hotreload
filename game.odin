package game

import "core:fmt"
import noise "core:math/noise"

import rl "vendor:raylib"

import imgui_rl "deps:imgui_impl_raylib"
import imgui "deps:odin-imgui"
import "core:slice"

GameMemory :: struct {
	some_state: int,
}

g_mem: ^GameMemory

@(export)
game_init :: proc(imgui_ctx: ^imgui.Context) {
	g_mem = new(GameMemory)
	imgui.SetCurrentContext(imgui_ctx)

	io := imgui.GetIO()

	// io.IniFilename = nil
	// io.LogFilename = nil

	io.ConfigFlags = {.DockingEnable, .ViewportsEnable}
	font_config: imgui.FontConfig = {}

	font_config.FontDataOwnedByAtlas = true
	font_config.OversampleH = 6
	font_config.OversampleV = 6
	font_config.GlyphMaxAdvanceX = max(f32)
	font_config.RasterizerMultiply = 1.4
	font_config.RasterizerDensity = 1.0
	font_config.EllipsisChar = cast(imgui.Wchar)(max(u16))

	font_config.PixelSnapH = false
	font_config.GlyphOffset = {0.0, -1.0}

	imgui.FontAtlas_AddFontFromFileTTF(
		io.Fonts,
		"C:\\Windows\\Fonts\\segoeui.ttf",
		18.0,
		&font_config,
	)

	font_config.MergeMode = true

	ICON_MIN_FA: u16 : 0xe005
	ICON_MAX_FA: u16 : 0xf8ff

	@(static)
	FA_RANGES: [3]u16 = {ICON_MIN_FA, ICON_MAX_FA, 0}

	font_config.RasterizerMultiply = 1.0
	font_config.GlyphOffset = {0.0, -1.0}

	imgui.FontAtlas_AddFontFromFileTTF(io.Fonts, "assets/fa-regular-400.ttf", 14.0, &font_config, slice.as_ptr(FA_RANGES[:]))

	font_config.MergeMode = false

	imgui_rl.build_font_atlas()

	configure_imgui()
}

@(export)
game_update :: proc() -> bool {
	if rl.WindowShouldClose() {
		return false
	}

	game_loop()

	return true
}

@(export)
game_shutdown :: proc() {
	free(g_mem)
}

@(export)
game_memory :: proc() -> rawptr {
	return g_mem
}

@(export)
game_hot_reloaded :: proc(mem: ^GameMemory, imgui_context: ^imgui.Context) {
	g_mem = mem
	imgui.SetCurrentContext(imgui_context)
	configure_imgui()
}

Entity :: struct {
	pos: [2]i32,
	vel: [2]i32,
}

World :: struct {
	grid: [100][100]u8,
}

State :: struct {
	accum_frametimes:      [100]f32,
	accum_frametime_index: int,
	entities:              []Entity,
	world:                 World,
}

game_state: ^State = nil
noise_seed: i64 = 0

game_loop :: #force_inline proc() {
	rl.ClearBackground(rl.BLUE)

	viewport := imgui.GetMainViewport()
	imgui.SetNextWindowPos(viewport.Pos)
	imgui.SetNextWindowSize(viewport.Size)
	imgui.SetNextWindowViewport(viewport._ID)
	imgui.SetNextWindowBgAlpha(0.0)

	imgui.PushStyleVar(.WindowRounding, 0.0)
	imgui.PushStyleVar(.WindowBorderSize, 0.0)
	imgui.PushStyleVarImVec2(.WindowPadding, {0.0, 0.0})
	imgui.Begin(
		"DockSpace Demo",
		nil,
		 {
			.MenuBar,
			.NoDocking,
			.NoTitleBar,
			.NoCollapse,
			.NoResize,
			.NoMove,
			.NoBringToFrontOnFocus,
			.NoNavFocus,
		},
	)

	imgui.PopStyleVar(3)

	imgui.BeginMenuBar()

	if imgui.BeginMenu("File") {
		imgui.MenuItem("(demo menu)", nil, false, false)
		if (imgui.MenuItem("New")) {}
		if (imgui.MenuItem("Open", "Ctrl+O")) {}
		if (imgui.BeginMenu("Open Recent")) {
			imgui.MenuItem("fish_hat.c")
			imgui.MenuItem("fish_hat.inl")
			imgui.MenuItem("fish_hat.h")
			if (imgui.BeginMenu("More..")) {
				imgui.MenuItem("Hello")
				imgui.MenuItem("Sailor")
				imgui.EndMenu()
			}
			imgui.EndMenu()
		}
		if (imgui.MenuItem("Save", "Ctrl+S")) {}
		if (imgui.MenuItem("Save As..")) {}

		imgui.Separator()

		if (imgui.MenuItem("Quit", "Alt+F4")) {
			rl.CloseWindow()
		}

		imgui.EndMenu()
	}

	imgui.EndMenuBar()

	dockspace_id := imgui.GetID("MyDockspace")
	imgui.DockSpace(dockspace_id, {0.0, 0.0}, {.PassthruCentralNode})

	imgui.ShowDemoWindow(nil)


	imgui.End()
}

configure_imgui :: proc() {
	io := imgui.GetIO()

	style := imgui.GetStyle()

	tone_text_1: imgui.Vec4 : {0.69, 0.69, 0.69, 1.0}
	tone_text_2: imgui.Vec4 : {0.69, 0.69, 0.69, 0.8}

	tone_1: imgui.Vec4 : {0.14, 0.16, 0.18, 1.0}
	tone_1_b := tone_1 * 1.2
	tone_1_e := tone_1 * 1.7
	tone_1_e_a := tone_1_e * 1.3
	tone_2: imgui.Vec4 : {0.11, 0.13, 0.15, 1.0}
	tone_2_b: imgui.Vec4 = tone_2 * [2]f32{0.7, 1.0}.xxxy
	tone_3: imgui.Vec4 : {0.08, 0.10, 0.12, 1.0}

	style.Colors[imgui.Col.Text] = tone_text_1
	style.Colors[imgui.Col.TextDisabled] = tone_text_2
	style.Colors[imgui.Col.WindowBg] = tone_1
	style.Colors[imgui.Col.ChildBg] = tone_2
	style.Colors[imgui.Col.PopupBg] = tone_2_b
	style.Colors[imgui.Col.Border] = tone_2
	style.Colors[imgui.Col.BorderShadow] = {0.0, 0.0, 0.0, 0.0}
	style.Colors[imgui.Col.FrameBg] = tone_3
	style.Colors[imgui.Col.FrameBgHovered] = tone_3
	style.Colors[imgui.Col.FrameBgActive] = tone_3
	style.Colors[imgui.Col.TitleBg] = tone_2
	style.Colors[imgui.Col.TitleBgActive] = tone_2
	style.Colors[imgui.Col.TitleBgCollapsed] = tone_2
	style.Colors[imgui.Col.MenuBarBg] = tone_2
	style.Colors[imgui.Col.ScrollbarBg] = tone_3
	style.Colors[imgui.Col.ScrollbarGrab] = tone_1_e
	style.Colors[imgui.Col.ScrollbarGrabHovered] = tone_1_e
	style.Colors[imgui.Col.ScrollbarGrabActive] = tone_1_e_a
	style.Colors[imgui.Col.CheckMark] = tone_1_e
	style.Colors[imgui.Col.SliderGrab] = tone_1_e
	style.Colors[imgui.Col.SliderGrabActive] = tone_1_e_a
	style.Colors[imgui.Col.Button] = tone_2
	style.Colors[imgui.Col.ButtonHovered] = tone_2
	style.Colors[imgui.Col.ButtonActive] = tone_3
	style.Colors[imgui.Col.Header] = tone_2
	style.Colors[imgui.Col.HeaderHovered] = tone_2
	style.Colors[imgui.Col.HeaderActive] = tone_2
	style.Colors[imgui.Col.Separator] = tone_2
	style.Colors[imgui.Col.SeparatorHovered] = tone_2
	style.Colors[imgui.Col.SeparatorActive] = tone_2
	style.Colors[imgui.Col.ResizeGrip] = {0.0, 0.0, 0.0, 0.0}
	style.Colors[imgui.Col.ResizeGripHovered] = {0.0, 0.0, 0.0, 0.0}
	style.Colors[imgui.Col.ResizeGripActive] = {0.0, 0.0, 0.0, 0.0}
	style.Colors[imgui.Col.Tab] = tone_2
	style.Colors[imgui.Col.TabHovered] = tone_1
	style.Colors[imgui.Col.TabActive] = tone_1
	style.Colors[imgui.Col.TabUnfocused] = tone_1
	style.Colors[imgui.Col.TabUnfocusedActive] = tone_1
	style.Colors[imgui.Col.PlotLines] = tone_1_e
	style.Colors[imgui.Col.PlotLinesHovered] = tone_2
	style.Colors[imgui.Col.PlotHistogram] = tone_1_e
	style.Colors[imgui.Col.PlotHistogramHovered] = tone_2
	style.Colors[imgui.Col.TableHeaderBg] = tone_2
	style.Colors[imgui.Col.TableBorderStrong] = tone_2
	style.Colors[imgui.Col.TableBorderLight] = tone_2
	style.Colors[imgui.Col.TableRowBg] = tone_2
	style.Colors[imgui.Col.TableRowBgAlt] = tone_1
	style.Colors[imgui.Col.TextSelectedBg] = tone_1_e
	style.Colors[imgui.Col.DragDropTarget] = tone_2
	style.Colors[imgui.Col.NavHighlight] = tone_2
	style.Colors[imgui.Col.NavWindowingHighlight] = tone_2
	style.Colors[imgui.Col.NavWindowingDimBg] = tone_2_b
	style.Colors[imgui.Col.ModalWindowDimBg] = tone_2_b * 0.5

	style.Colors[imgui.Col.DockingPreview] = {1.0, 1.0, 1.0, 0.5}
	style.Colors[imgui.Col.DockingEmptyBg] = {0.0, 0.0, 0.0, 0.0}

	style.WindowPadding = {10.00, 10.00}
	style.FramePadding = {5.00, 5.00}
	style.CellPadding = {2.50, 2.50}
	style.ItemSpacing = {5.00, 5.00}
	style.ItemInnerSpacing = {5.00, 5.00}
	style.TouchExtraPadding = {5.00, 5.00}
	style.IndentSpacing = 10
	style.ScrollbarSize = 15
	style.GrabMinSize = 10
	style.WindowBorderSize = 0
	style.ChildBorderSize = 0
	style.PopupBorderSize = 0
	style.FrameBorderSize = 0
	style.TabBorderSize = 0
	style.WindowRounding = 10
	style.ChildRounding = 5
	style.FrameRounding = 5
	style.PopupRounding = 5
	style.GrabRounding = 5
	style.ScrollbarRounding = 10
	style.LogSliderDeadzone = 5
	style.TabRounding = 5
	style.DockingSeparatorSize = 5
}
