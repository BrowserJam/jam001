const std = @import("std");
const dvui = @import("dvui");
const parser = @import("./parser.zig");

const Backend = @import("SDLBackend");

var gpa_instance = std.heap.GeneralPurposeAllocator(.{}){};
const gpa = gpa_instance.allocator();

const vsync = true;
var html_text = std.ArrayList(u8).init(gpa);
var html_doc: ?parser.Document = null;

/// - dvui renders the whole application
/// - render frames only when needed
pub fn main() !void {
    defer _ = gpa_instance.deinit();
    defer _ = html_text.deinit();

    // init SDL backend (creates and owns OS window)
    var backend = try Backend.initWindow(.{
        .allocator = gpa,
        .size = .{ .w = 800.0, .h = 600.0 },
        .min_size = .{ .w = 250.0, .h = 350.0 },
        .vsync = vsync,
        .title = "DVUI SDL Standalone Example",
    });
    defer backend.deinit();

    // init dvui Window (maps onto a single OS window)
    var win = try dvui.Window.init(@src(), gpa, backend.backend(), .{});
    defer win.deinit();

    main_loop: while (true) {

        // beginWait coordinates with waitTime below to run frames only when needed
        const nstime = win.beginWait(backend.hasEvent());

        // marks the beginning of a frame for dvui, can call dvui functions after this
        try win.begin(nstime);

        // send all SDL events to dvui for processing
        const quit = try backend.addAllEvents(&win);
        if (quit) break :main_loop;

        // if dvui widgets might not cover the whole window, then need to clear
        // the previous frame's render
        _ = Backend.c.SDL_SetRenderDrawColor(backend.renderer, 0, 0, 0, 255);
        _ = Backend.c.SDL_RenderClear(backend.renderer);

        // both dvui and SDL drawing
        try gui_frame();

        // marks end of dvui frame, don't call dvui functions after this
        // - sends all dvui stuff to backend for rendering, must be called before renderPresent()
        const end_micros = try win.end(.{});

        // cursor management
        backend.setCursor(win.cursorRequested());

        // render frame to OS
        backend.renderPresent();

        // waitTime and beginWait combine to achieve variable framerates
        const wait_event_micros = win.waitTime(end_micros, null);
        backend.waitEventTimeout(wait_event_micros);
    }
}

fn gui_frame() !void {
    var scroll = try dvui.scrollArea(@src(), .{}, .{ .expand = .both, .color_fill = .{ .name = .fill_window } });
    defer scroll.deinit();

    var search = try dvui.textEntry(@src(), .{}, .{ .expand = .horizontal });
    const url = search.getText();
    search.deinit();
    if (try dvui.button(@src(), "Search", .{}, .{})) {
        // TODO: fetch html
        std.debug.print("GET: {s}\n", .{url});
        var client = std.http.Client{ .allocator = gpa };
        const options = std.http.Client.FetchOptions;
        html_text.shrinkAndFree(0);
        const status = try client.fetch(.{ .location = options.Location{ .url = url }, .method = .GET, .response_storage = options.ResponseStorage{ .dynamic = &html_text } });
        html_doc = try parser.parse(html_text.items, gpa);
        std.debug.print("STATUS: {}\n", .{status.status});
    }
    if (html_doc) |doc| {
        try render_html(doc);
    }
}

fn render_html(html: parser.Document) !void {
    for (html.nodes.items) |node| {
        if (node.tag == .text) {
            var t = try dvui.textLayout(@src(), .{}, .{ .expand = .horizontal });
            try t.addText(node.capture, .{});
            t.deinit();
        }
    }
}
