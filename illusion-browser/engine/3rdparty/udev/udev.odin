package udev

import "core:sys/linux"

foreign import udev_lib "system:udev"

@(link_prefix = "udev_")
foreign udev_lib {
    new :: proc() -> ^udev ---
    monitor_new_from_netlink :: proc(udev: ^udev, name: cstring) -> ^udev_monitor ---
    monitor_filter_add_match_subsystem_devtype :: proc(udev_monitor: ^udev_monitor, subsystem: cstring, device_type: cstring) -> i32 ---
    monitor_enable_receiving :: proc(udev_monitor: ^udev_monitor) -> i32 ---
    monitor_get_fd :: proc(udev_monitor: ^udev_monitor) -> linux.Fd ---
    enumerate_new :: proc(udev: ^udev) -> ^udev_enumerate ---
    enumerate_add_match_subsystem :: proc(enumerate: ^udev_enumerate, subsystem: cstring) -> i32 ---
    enumerate_add_match_property :: proc(enumerate: ^udev_enumerate, property: cstring, value: cstring) -> i32 ---
    enumerate_scan_devices :: proc(enumerate: ^udev_enumerate) -> i32 ---
    enumerate_get_list_entry :: proc(enumerate: ^udev_enumerate) -> ^udev_list_entry ---
    list_entry_get_name :: proc(list_entry: ^udev_list_entry) -> cstring ---
    list_entry_get_value :: proc(list_entry: ^udev_list_entry) -> cstring ---
    device_new_from_syspath :: proc(udev: ^udev, syspath: cstring) -> ^udev_device ---
    device_unref :: proc(dev: ^udev_device) -> ^udev_device ---
    enumerate_unref :: proc(enumerate: ^udev_enumerate) -> ^udev_enumerate ---
    list_entry_get_next :: proc(list_entry: ^udev_list_entry) -> ^udev_list_entry ---
    enumerate_add_match_parent :: proc(enumerate: ^udev_enumerate, parent: ^udev_device) -> i32 ---
    device_get_sysname :: proc(dev: ^udev_device) -> cstring ---
    device_get_syspath :: proc(dev: ^udev_device) -> cstring ---
    device_get_devtype :: proc(dev: ^udev_device) -> cstring ---
    device_get_devpath :: proc(dev: ^udev_device) -> cstring ---
    device_get_property_value :: proc(dev: ^udev_device, key: cstring) -> cstring ---
    monitor_receive_device :: proc(udev_monitor: ^udev_monitor) -> ^udev_device ---
    device_get_action :: proc(udev_device: ^udev_device) -> cstring ---
    device_get_devnum :: proc(dev: ^udev_device) -> dev_t ---
    device_get_devnode :: proc(dev: ^udev_device) -> cstring ---
    device_get_sysattr_value :: proc(dev: ^udev_device, attr: cstring) -> cstring ---
    device_get_parent :: proc(dev: ^udev_device) -> ^udev_device ---
    device_get_parent_with_subsystem_devtype :: proc(dev: ^udev_device, subsystem: cstring, devtype: cstring) -> ^udev_device ---
    device_get_subsystem :: proc(dev: ^udev_device) -> cstring ---
    device_get_properties_list_entry :: proc(dev: ^udev_device) -> ^udev_list_entry ---
    device_get_sysattr_list_entry :: proc(dev: ^udev_device) -> ^udev_list_entry ---
    device_get_tags_list_entry :: proc(dev: ^udev_device) -> ^udev_list_entry ---
    device_get_current_tags_list_entry :: proc(dev: ^udev_device) -> ^udev_list_entry ---
}
