<?php

namespace Ekgame\PhpBrowser\Style;

use Ekgame\PhpBrowser\DomNode;
use Ekgame\PhpBrowser\Style\Unit\Display;
use Ekgame\PhpBrowser\Style\Unit\FontStyle;
use Ekgame\PhpBrowser\Style\Unit\FontWeight;
use Ekgame\PhpBrowser\Style\Unit\Margin;
use Ekgame\PhpBrowser\Style\Unit\Measurement;
use Ekgame\PhpBrowser\Style\Unit\Padding;
use Ekgame\PhpBrowser\Style\Unit\SizeUnit;
use Ekgame\PhpBrowser\Style\Unit\TextDecoration;

class UserAgentStyleResolver implements StyleResolver
{
    private NodeStylesBag $default_styles;
    private array $styles_by_tag = [];

    public function __construct()
    {
        $this->default_styles = new NodeStylesBag();

        $this->styles_by_tag['body'] = NodeStylesBag::create(function (NodeStylesBag $bag) {
            $bag->display = Display::BLOCK;
            $bag->color = 'black';
            $bag->font_size = new Measurement(15, SizeUnit::PX);
            $bag->padding = Padding::from(8, SizeUnit::PX);
            $bag->line_height = new Measurement(1.25, SizeUnit::EM);
        });

        $this->styles_by_tag['h1'] = NodeStylesBag::create(function (NodeStylesBag $bag) {
            $bag->display = Display::BLOCK;
            $bag->font_size = new Measurement(2.1, SizeUnit::EM);
            $bag->margin = new Margin(
                top: new Measurement(0.67, SizeUnit::EM),
                right: new Measurement(0, SizeUnit::PX),
                bottom: new Measurement(0.67, SizeUnit::EM),
                left: new Measurement(0, SizeUnit::PX),
            );
            $bag->font_weight = FontWeight::BOLD;
        });

        $this->styles_by_tag['h2'] = NodeStylesBag::create(function (NodeStylesBag $bag) {
            $bag->display = Display::BLOCK;
            $bag->font_size = new Measurement(1.5, SizeUnit::EM);
            $bag->margin = new Margin(
                top: new Measurement(0.83, SizeUnit::EM),
                right: new Measurement(0, SizeUnit::PX),
                bottom: new Measurement(0.83, SizeUnit::EM),
                left: new Measurement(0, SizeUnit::PX),
            );
            $bag->font_weight = FontWeight::BOLD;
        });

        $this->styles_by_tag['p'] = NodeStylesBag::create(function (NodeStylesBag $bag) {
            $bag->display = Display::BLOCK;
            $bag->font_size = new Measurement(1, SizeUnit::EM);
            $bag->margin = new Margin(
                top: new Measurement(1, SizeUnit::EM),
                right: new Measurement(0, SizeUnit::PX),
                bottom: new Measurement(1, SizeUnit::EM),
                left: new Measurement(0, SizeUnit::PX),
            );
        });

        $this->styles_by_tag['ul'] = NodeStylesBag::create(function (NodeStylesBag $bag) {
            $bag->display = Display::BLOCK;
            $bag->margin = new Margin(
                top: new Measurement(1, SizeUnit::EM),
                right: new Measurement(0, SizeUnit::PX),
                bottom: new Measurement(1, SizeUnit::EM),
                left: new Measurement(0, SizeUnit::PX),
            );
            $bag->padding = new Padding(
                top: new Measurement(0, SizeUnit::PX),
                right: new Measurement(0, SizeUnit::PX),
                bottom: new Measurement(0, SizeUnit::PX),
                left: new Measurement(40, SizeUnit::PX),
            );
        });

        $this->styles_by_tag['l1'] = NodeStylesBag::create(function (NodeStylesBag $bag) {
            $bag->display = Display::BLOCK;
        });

        $this->styles_by_tag['a'] = NodeStylesBag::create(function (NodeStylesBag $bag) {
            $bag->display = Display::INLINE;
            $bag->color = 'rgb(0, 0, 238)';
            $bag->text_decoration = TextDecoration::UNDERLINE;
        });

        $this->styles_by_tag['dl'] = NodeStylesBag::create(function (NodeStylesBag $bag) {
            $bag->display = Display::BLOCK;
            $bag->margin = new Margin(
                top: new Measurement(1, SizeUnit::EM),
                right: new Measurement(0, SizeUnit::PX),
                bottom: new Measurement(1, SizeUnit::EM),
                left: new Measurement(0, SizeUnit::PX),
            );
        });

        $this->styles_by_tag['dt'] = NodeStylesBag::create(function (NodeStylesBag $bag) {
            $bag->display = Display::BLOCK;
        });

        $this->styles_by_tag['dd'] = NodeStylesBag::create(function (NodeStylesBag $bag) {
            $bag->display = Display::BLOCK;
            $bag->margin = new Margin(
                top: new Measurement(0, SizeUnit::PX),
                right: new Measurement(0, SizeUnit::PX),
                bottom: new Measurement(0, SizeUnit::PX),
                left: new Measurement(40, SizeUnit::PX),
            );
        });

        $this->styles_by_tag['#text'] = NodeStylesBag::create(function (NodeStylesBag $bag) {
            $bag->display = Display::INLINE;
        });

        $this->styles_by_tag['address'] = NodeStylesBag::create(function (NodeStylesBag $bag) {
            $bag->display = Display::BLOCK;
            $bag->font_style = FontStyle::ITALIC;
        });

        $this->styles_by_tag['strong'] = NodeStylesBag::create(function (NodeStylesBag $bag) {
            $bag->display = Display::INLINE;
            $bag->font_weight = FontWeight::BOLD;
        });

        $this->styles_by_tag['b'] = NodeStylesBag::create(function (NodeStylesBag $bag) {
            $bag->display = Display::INLINE;
            $bag->font_weight = FontWeight::BOLD;
        });

        $this->styles_by_tag['i'] = NodeStylesBag::create(function (NodeStylesBag $bag) {
            $bag->display = Display::INLINE;
            $bag->font_style = FontStyle::ITALIC;
        });

        $this->styles_by_tag['hr'] = NodeStylesBag::create(function (NodeStylesBag $bag) {
            $bag->display = Display::BLOCK;
            $bag->margin = new Margin(
                top: new Measurement(0.5, SizeUnit::EM),
                right: new Measurement(0, SizeUnit::PX),
                bottom: new Measurement(0.5, SizeUnit::EM),
                left: new Measurement(0, SizeUnit::PX),
            );
        });
    }

    public function resolve(DomNode $style): NodeStylesBag
    {
        $tag = strtolower($style->getTag());
        return $this->styles_by_tag[$tag] ?? $this->default_styles;
    }
}