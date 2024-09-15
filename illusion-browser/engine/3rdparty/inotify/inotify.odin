// +build linux
package inotify

import "core:c"
import "core:os"

foreign import libc "system:c"

IN_ACCESS :: 0x001
IN_MODIFY :: 0x002
IN_ATTRIB :: 0x004
IN_CLOSE_WRITE :: 0x008
IN_CLOSE_NOWRITE :: 0x010
IN_OPEN :: 0x020
IN_MOVED_FROM :: 0x040
IN_MOVED_TO :: 0x080
IN_CREATE :: 0x100
IN_DELETE :: 0x200
IN_DELETE_SELF :: 0x400
IN_MOVE_SELF :: 0x800

IN_UNMOUNT :: 0x2000 // Backing fs unmounted
IN_Q_OVERFLOW :: 0x4000 // Event queue overflow
IN_IGNORED :: 0x8000 // File was ignored

IN_CLOSE :: IN_CLOSE_WRITE | IN_CLOSE_NOWRITE
IN_MOVE :: IN_MOVED_FROM | IN_MOVED_TO

IN_ONLY_DIR :: 0x01000000
IN_DONT_FOLLOW :: 0x02000000
IN_EXCL_UNLINK :: 0x04000000
IN_MASK_CREATE :: 0x10000000
IN_MASK_ADD :: 0x20000000
IN_ISDIR :: 0x40000000
IN_ONESHOT :: 0x80000000

#assert(size_of(Event) == 16)
Event :: struct {
    wd:     os.Handle,
    mask:   u32,
    cookie: u32,
    length: u32,
    name:   [0]c.char,
}

@(link_prefix = "inotify_")
foreign libc {
    init :: proc() -> os.Handle ---
    init1 :: proc(flags: c.int) -> os.Handle ---

    add_watch :: proc(fd: os.Handle, pathname: cstring, mask: u32) -> os.Handle ---
    rm_watch :: proc(fd: os.Handle, wd: os.Handle) -> c.int ---
}
