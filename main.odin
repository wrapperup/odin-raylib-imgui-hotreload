package game

import "core:dynlib"
import "core:fmt"
import "core:os"
import "core:sys/windows"
import "core:time"
import imgui_rl "deps:imgui_impl_raylib"
import imgui "deps:odin-imgui"
import rl "vendor:raylib"

dll_loaded := false

main :: proc() {
	game_api, game_api_ok := load_game_api()

	if !game_api_ok {
		fmt.println("Failed to load Game API")
		return
	}

	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(800, 600, "alluvium")

	imgui_ctx := imgui.CreateContext(nil)

	imgui_rl.init()
	game_api.init(imgui_ctx)

	for {
		imgui_rl.process_events()
		imgui_rl.new_frame()
		imgui.NewFrame()
		rl.BeginDrawing()

		if game_api.update() == false {
			break
		}

		imgui.Render()
		imgui.EndFrame()

		imgui_rl.render_draw_data(imgui.GetDrawData())
		rl.EndDrawing()

		last_game_write, last_game_write_err := os.last_write_time_by_name("game.dll")

		if last_game_write_err == os.ERROR_NONE && game_api.lib_write_time != last_game_write {
			if dll_loaded {
				fmt.println("Hotreload: new dll written, load new dll...")
				// Unload old game API, keep game memory
				game_memory := game_api.memory()
				unload_game_api(game_api)

				// block on new game.dll load
				new_game_api, new_game_api_ok := load_game_api()

				game_api = new_game_api
				game_api.hot_reloaded(game_memory, imgui_ctx)
			}
		}
	}

	game_api.shutdown()

	imgui_rl.shutdown()
	rl.CloseWindow()

	imgui.DestroyContext(nil)

	unload_game_api(game_api)
}

GameAPI :: struct {
	init:           proc(_: ^imgui.Context),
	update:         proc() -> bool,
	shutdown:       proc(),
	memory:         proc() -> rawptr,
	hot_reloaded:   proc(_: rawptr, _: rawptr),
	lib:            dynlib.Library,
	lib_write_time: os.File_Time,
}

load_game_api :: proc() -> (GameAPI, bool) {
	game_dll_name := "game.dll"
	new_dll_name := "game_hotreload.dll"

	game_dll_name_long := windows.L("game.dll")
	new_dll_name_long := windows.L("game_hotreload.dll")

	MOVEFILE_WRITE_THROUGH: windows.DWORD : 8

	for {
		copy_success := windows.CopyFileW(game_dll_name_long, new_dll_name_long, false)
		if !copy_success {
			fmt.println("Failed to copy game.dll to", new_dll_name)
			time.sleep(time.Millisecond * 100)
			continue
		}

		break
	}

	lib, lib_ok := dynlib.load_library(new_dll_name)

	if !lib_ok {
		panic("Failed to load game library. Panic!!")
	}

	lib_last_write, lib_last_write_err := os.last_write_time_by_name(game_dll_name)

	if lib_last_write_err != os.ERROR_NONE {
		panic("Could not fetch last write date of game.dll")
	}

	api := GameAPI {
		init           = cast(proc(
			_: ^imgui.Context,
		))(dynlib.symbol_address(lib, "game_init") or_else nil),
		update         = cast(proc(
		) -> bool)(dynlib.symbol_address(lib, "game_update") or_else nil),
		shutdown       = cast(proc())(dynlib.symbol_address(lib, "game_shutdown") or_else nil),
		memory         = cast(proc(
		) -> rawptr)(dynlib.symbol_address(lib, "game_memory") or_else nil),
		hot_reloaded   = cast(proc(
			_: rawptr,
			_: rawptr,
		))(dynlib.symbol_address(lib, "game_hot_reloaded") or_else nil),
		lib            = lib,
		lib_write_time = lib_last_write,
	}

	if api.init == nil ||
	   api.update == nil ||
	   api.shutdown == nil ||
	   api.memory == nil ||
	   api.hot_reloaded == nil {
		dynlib.unload_library(api.lib)
		fmt.println("Game DLL is missing required procedure")
		return {}, false
	}

	dll_loaded = true

	return api, true
}

unload_game_api :: proc(api: GameAPI) {
	if api.lib != nil {
		dynlib.unload_library(api.lib)
	}

	dll_loaded = false
}
