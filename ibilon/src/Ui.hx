import java.awt.font.TextLayout;
import java.awt.Font;
import java.awt.RenderingHints;
import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.Dimension;
import java.awt.Graphics;
import java.javax.swing.JFrame;
import java.javax.swing.JPanel;
import java.lang.Runnable;
import java.lang.Thread;

private inline var WIDTH = 1800;
private inline var HEIGHT = 600;

class Ui implements Runnable {
	public static function render(title:String, layout:Array<Block>):Void {
		var ui = new Ui(title, layout);
		new Thread(ui).start();
	}

	private var painter:Painter;

	private function new(title:String, layout:Array<Block>) {
		var window = new JFrame();
		var content = window.getContentPane();

		this.painter = new Painter(layout);
		content.add(this.painter);
		content.setPreferredSize(new Dimension(WIDTH, HEIGHT));

		window.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
		window.pack();
		window.setResizable(false);
		window.setTitle(title + " - Browser");
		window.setLocationRelativeTo(null);
		window.setVisible(true);
	}

	public function run() {
		this.painter.repaint();
	}
}

private class Painter extends JPanel {
	private var blocks:Array<Block>;

	public function new(blocks:Array<Block>) {
		super(true);
		this.blocks = blocks;
	}

	@:overload
	override function paint(g:Graphics) {
		var g:Graphics2D = cast g;
		g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);

		g.setColor(Color.WHITE);
		g.fillRect(0, 0, WIDTH, HEIGHT);
		g.setColor(Color.BLACK);

		var frc = g.getFontRenderContext();
		var font_plain = new Font("Arial", Font.PLAIN, 18);
		var font_header = new Font("Arial", Font.BOLD, 36);
		var font = font_plain;
		var underline = false;

		var x = 0.0;
		var y = 36.0;
		var height = 0.0;

		for (block in this.blocks) {
			switch (block) {
				case Default:
					g.setColor(Color.BLACK);
					font = font_plain;
					underline = false;

				case Header:
					font = font_header;

				case Link(_):
					g.setColor(Color.BLUE);
					underline = true;

				case Row(margin):
					x = margin ? 40.0 : 0.0;
					y += height + 4;
					height = 0.0;

				case Text(text):
					x += 2;
					var layout = new TextLayout(text, font, frc);
					var bounds = layout.getBounds();
					layout.draw(g, x, y);

					if (underline) {
						var underline_y = Std.int(y + layout.getDescent() - 3);
						g.drawLine(Std.int(x), underline_y, Std.int(x + bounds.getWidth()), underline_y);
					}

					x += bounds.getWidth() + 2;
					height = bounds.getHeight() > height ? bounds.getHeight() : height;
			}
		}
	}
}
