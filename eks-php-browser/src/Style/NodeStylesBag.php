<?php

namespace Ekgame\PhpBrowser\Style;

use Ekgame\PhpBrowser\Style\Unit\Display;
use Ekgame\PhpBrowser\Style\Unit\FontStyle;
use Ekgame\PhpBrowser\Style\Unit\FontWeight;
use Ekgame\PhpBrowser\Style\Unit\Margin;
use Ekgame\PhpBrowser\Style\Unit\Measurement;
use Ekgame\PhpBrowser\Style\Unit\Padding;
use Ekgame\PhpBrowser\Style\Unit\SizeUnit;
use Ekgame\PhpBrowser\Style\Unit\TextDecoration;

class NodeStylesBag
{
    // These may be inherited from parent nodes
    public ?string $color = null;
    public ?Measurement $font_size = null;
    public ?Measurement $line_height = null;
    public ?FontWeight $font_weight = null;
    public ?FontStyle $font_style = null;
    public ?TextDecoration $text_decoration = null;

    // These are always concrete values
    public Display $display = Display::BLOCK;
    public Margin $margin;
    public Padding $padding;

    public function __construct()
    {
        $this->margin = new Margin(
            new Measurement(0, SizeUnit::PX),
            new Measurement(0, SizeUnit::PX),
            new Measurement(0, SizeUnit::PX),
            new Measurement(0, SizeUnit::PX),
        );

        $this->padding = new Padding(
            new Measurement(0, SizeUnit::PX),
            new Measurement(0, SizeUnit::PX),
            new Measurement(0, SizeUnit::PX),
            new Measurement(0, SizeUnit::PX),
        );
    }

    public function collapse(ComputedStyles $parent): ComputedStyles
    {
        $styles = new ComputedStyles();

        // Nodes always have a concrete display type
        $styles->display = $this->display;

        // Inherit color from parent if not set
        $styles->color = $this->color !== null ? $this->color : $parent->color;

        // Inherit/scale/replace font-size from parent
        $styles->font_size = $this->safeApply($this->font_size, $parent->font_size);
        $styles->line_height = $this->line_height !== null ? $this->line_height : $parent->line_height;

        // Inherit font-weight, font-style and text-decoration from parent if not set
        $styles->font_weight = $this->font_weight !== null ? $this->font_weight : $parent->font_weight;
        $styles->font_style = $this->font_style !== null ? $this->font_style : $parent->font_style;
        $styles->text_decoration = $this->text_decoration !== null ? $this->text_decoration : $parent->text_decoration;

        // Apply margin, possibly scale with font-size
        $styles->margin_top = $this->safeApply($this->margin->getTop(), $styles->font_size);
        $styles->margin_right = $this->safeApply($this->margin->getRight(), $styles->font_size);
        $styles->margin_bottom = $this->safeApply($this->margin->getBottom(), $styles->font_size);
        $styles->margin_left = $this->safeApply($this->margin->getLeft(), $styles->font_size);

        // Apply padding, possibly scale with font-size
        $styles->padding_top = $this->safeApply($this->padding->getTop(), $styles->font_size);
        $styles->padding_right = $this->safeApply($this->padding->getRight(), $styles->font_size);
        $styles->padding_bottom = $this->safeApply($this->padding->getBottom(), $styles->font_size);
        $styles->padding_left = $this->safeApply($this->padding->getLeft(), $styles->font_size);

        return $styles;
    }

    private function safeApply(?Measurement $measurement, float $previous): float
    {
        return $measurement !== null ? $measurement->apply($previous) : $previous;
    }

    /**
     * Summary of create
     * @param callable(NodeStylesBag):void $callback
     * @return void
     */
    public static function create(callable $callback): NodeStylesBag
    {
        $bag = new NodeStylesBag();
        $callback($bag);
        return $bag;
    }
}