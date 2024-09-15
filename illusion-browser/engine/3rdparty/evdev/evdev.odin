//+build linux
package evdev

import "core:os"

foreign import evdev "system:evdev"

@(link_prefix = "libevdev_")
foreign evdev {
    new_from_fd :: proc(fd: os.Handle, dev: ^^libevdev) -> Err ---
    get_id_bustype :: proc(dev: ^libevdev) -> u16 ---
    get_id_vendor :: proc(dev: ^libevdev) -> u16 ---
    get_id_product :: proc(dev: ^libevdev) -> u16 ---
    has_event_pending :: proc(dev: ^libevdev) -> i32 ---
    next_event :: proc(dev: ^libevdev, flags: libevdev_read_flag, ev: ^input_event) -> i32 ---
    get_abs_flat :: proc(dev: ^libevdev, code: u32) -> i32 ---
    get_name :: proc(dev: ^libevdev) -> cstring ---
    get_abs_info :: proc(dev: ^libevdev, code: u32) -> ^input_absinfo ---
    get_uniq :: proc(dev: ^libevdev) -> cstring ---
    get_phys :: proc(dev: ^libevdev) -> cstring ---
    free :: proc(dev: ^libevdev) ---
    has_event_type :: proc(dev: ^libevdev, type: u32) -> bool ---
    has_event_code :: proc(dev: ^libevdev, type: u32, code: u32) -> bool ---
    get_fd :: proc(dev: ^libevdev) -> os.Handle ---
}
