<?php

namespace Ekgame\PhpBrowser\Style;
use Ekgame\PhpBrowser\Style\Unit\Display;
use Ekgame\PhpBrowser\Style\Unit\FontStyle;
use Ekgame\PhpBrowser\Style\Unit\FontWeight;
use Ekgame\PhpBrowser\Style\Unit\Measurement;
use Ekgame\PhpBrowser\Style\Unit\SizeUnit;
use Ekgame\PhpBrowser\Style\Unit\TextDecoration;


class ComputedStyles
{
    public Display $display = Display::BLOCK;
    public string $color = 'black';
    public float $font_size = 16;
    public Measurement $line_height;
    public FontWeight $font_weight = FontWeight::NORMAL;
    public FontStyle $font_style = FontStyle::NORMAL;
    public TextDecoration $text_decoration = TextDecoration::NONE;

    public float $margin_top = 0;
    public float $margin_right = 0;
    public float $margin_bottom = 0;
    public float $margin_left = 0;

    public float $padding_top = 0;
    public float $padding_right = 0;
    public float $padding_bottom = 0;
    public float $padding_left = 0;

    public function __construct()
    {
        $this->line_height = new Measurement(18, SizeUnit::PX);
    }
}