<?php

namespace Ekgame\PhpBrowser\Layout;
use Ekgame\PhpBrowser\DomNode;
use Ekgame\PhpBrowser\Style\ComputedStyles;
use Ekgame\PhpBrowser\Style\Unit\Display;
use Ekgame\PhpBrowser\Style\Unit\FontStyle;
use Ekgame\PhpBrowser\Style\Unit\FontWeight;
use Intervention\Image\Drivers\Gd\FontProcessor;
use Intervention\Image\Interfaces\FontInterface;
use Intervention\Image\Typography\FontFactory;

class LayoutCalculator
{
    private int $page_width;
    private FontProcessor $fontProcessor;

    public function __construct(int $page_width)
    {
        $this->page_width = $page_width;
        $this->fontProcessor = new FontProcessor();
    }

    public function layoutRootNode(DomNode $root_node): LayoutNode
    {
        $layoutNode = $this->convertDomToLayout($root_node);
        $layoutNode->setPosition(0, 0);
        $layoutNode->setWidth($this->page_width);

        $this->layoutBlockNode($layoutNode);

        return $layoutNode;
    }

    private function layoutBlockNode(LayoutNode $node)
    {
        $full_width = $node->getWidth();
        if (!$full_width) {
           throw new \RuntimeException('Block node must have a width as this point');
        }

        $node_styles = $node->getComputedStyles();

        $base_x = $node_styles->padding_left;
        $base_y = $node_styles->padding_top;

        $x_offset = 0;
        $y_offset = 0;

        $available_width = $full_width - $node_styles->padding_left - $node_styles->padding_right;
        $last_vertical_margin = 9999999;

        foreach ($node->getChildrenWithLookahead() as [$child, $next]) {
            $child_styles = $child->getComputedStyles();

            if ($child_styles->display === Display::BLOCK) {
                $x_offset = 0;
                $top_margin = max(0, $child_styles->margin_top - $last_vertical_margin);

                $child->setPosition(
                    $base_x + $x_offset + $child_styles->margin_left,
                    $base_y + $y_offset + $top_margin
                );

                $child->setWidth(
                    $available_width - $child_styles->margin_left - $child_styles->margin_right
                );

                $this->layoutBlockNode($child);

                $y_offset += $child->getHeight() + $top_margin + $child_styles->margin_bottom;
                $last_vertical_margin = $child_styles->margin_bottom;
            }
            else if ($child_styles->display === Display::INLINE) {
                $child->setPosition($base_x, $base_y);
                $child->setHasSize(false);
                $next_display = $next?->getComputedStyles()?->display ?: Display::BLOCK;
                $this->layoutInlineNode(
                    node: $child,
                    available_width: $available_width,
                    x_offset: $x_offset,
                    y_offset: $y_offset,
                    force_new_line: $next_display === Display::BLOCK,
                );
                $last_vertical_margin = 0;
            }
            else {
                throw new \RuntimeException('Unsupported display type: ' . $child_styles->display);
            }
        }

        $node->setHeight(
            $y_offset + $node_styles->padding_bottom
        );
    }

    private function layoutInlineNode(
        LayoutNode $node,
        int $available_width,
        int &$x_offset,
        int &$y_offset,
        bool $force_new_line = false,
    ): LayoutNode
    {
        $node->setDimensions(0, 0);
        $last_palaced = null;

        foreach ($node->getChildren() as $child) {
            $child_styles = $child->getComputedStyles();

            if ($child_styles->display === Display::BLOCK) {
                throw new \RuntimeException('block child in inline node not supported');
            }
            
            if ($child_styles->display === Display::INLINE && $child->getText() === null) {
                $child->setPosition(0, 0);
                $child->setHasSize(false);
                $placed = $this->layoutInlineNode($child, $available_width, $x_offset, $y_offset);
                if ($placed) {
                    $last_palaced = $placed;
                }
                
                continue;
            }

            if ($x_offset + $child->getWidth() > $available_width) {
                $x_offset = 0;
                $y_offset += $child_styles->margin_top + $child_styles->margin_bottom + $child->getHeight();
            }

            $child->setPosition(
                x: $x_offset + $child_styles->padding_left,
                y: $y_offset + $child_styles->padding_top,
            );

            $x_offset += $child->getWidth() + $child_styles->padding_left + $child_styles->padding_right;
            $last_palaced = $child;
        }

        // Use the last child to move to the next line
        if ($last_palaced !== null && $force_new_line) {
            $styles = $last_palaced->getComputedStyles();
            $x_offset = 0;
            $y_offset += $styles->margin_top + $last_palaced->getHeight() + $styles->margin_bottom;
        }

        $hit_boxes = $this->calculateInlineHitBoxes($node);
        $node->setHitBoxes($hit_boxes);

        return $last_palaced;
    }

    private function calculateInlineHitBoxes(LayoutNode $node): array
    {
        if ($node->getComputedStyles()->display !== Display::INLINE) {
            throw new \RuntimeException('Only inline nodes are supported');
        }

        $hit_boxes = [];

        /** @var ?Rectangle $current_hit_box */
        $current_hit_box = null;

        $current_x = 0;

        $sized_elements = $node->collectSizedElements();
        foreach ($sized_elements as $element) {
            $current_rectangle = $element->toRectangle();
            if ($current_hit_box === null) {
                $current_hit_box = $current_rectangle;
                $current_x = $current_rectangle->getX();
                continue;
            }

            if ($current_rectangle->getX() > $current_x) {
                $current_hit_box = $current_hit_box->expand($current_rectangle);
                $current_x = $current_rectangle->getX();
                continue;
            }

            if ($current_rectangle->getX() == $current_x && $current_hit_box->intersects($current_rectangle)) {
                $current_hit_box = $current_hit_box->expand($current_rectangle);
                continue;
            }

            $hit_boxes[] = $current_hit_box;
            $current_hit_box = $current_rectangle;
            $current_x = $current_rectangle->getX();
        }

        if ($current_hit_box !== null) {
            $hit_boxes[] = $current_hit_box;
        }

        return $hit_boxes;
    }

    private function splitTextSegments(string $text): array
    {
        // $text = trim($text);
        $text = preg_replace('/\s+/', ' ', $text);
        $segments = explode(' ', $text);

        foreach ($segments as $i => $segment) {
            $segments[$i] = $segment . ' ';
        }

        $segments[count($segments) - 1] = rtrim($segments[count($segments) - 1]);

        return $segments;
    }

    private function convertDomToLayout(DomNode $node): LayoutNode
    {
        if ($node->getTag() === '#text') {
            $computed_styles = $node->getComputedStyles();
            $text_node = new LayoutNode($computed_styles, null, $node);

            $font = $this->resolveFont($computed_styles);
            $text_node->setFont($font);

            $height = $computed_styles->line_height->apply($computed_styles->font_size);
            $physical_height = $this->fontProcessor->boxSize('Ij', $font)->height();
            
            $segments = $this->splitTextSegments($node->getAttribute('text') ?? '');
            foreach ($segments as $segment) {
                $segment_node = new LayoutNode($computed_styles, $segment);
                $width = $this->fontProcessor->boxSize($segment, $font)->width();
                
                $segment_node->setDimensions($width, $height);
                $segment_node->setVerticalOffset(($height - $physical_height) / 2);
                $segment_node->setParent($text_node);
                $text_node->addChild($segment_node);
            }

            return $text_node;
        }

        $layoutNode = new LayoutNode($node->getComputedStyles(), null, $node);

        foreach ($node->getChildren() as $child) {
            $childLayoutNode = $this->convertDomToLayout($child);
            $childLayoutNode->setParent($layoutNode);
            $layoutNode->addChild($childLayoutNode);
        }

        return $layoutNode;
    }

    private function resolveFont(ComputedStyles $styles): FontInterface
    {
        return call_user_func(new FontFactory(function(FontFactory $font) use ($styles) {
            $font->file($this->resolveFontPath($styles));
            $font->size($styles->font_size);
            $font->color($styles->color);
            $font->align('left');
            $font->valign('top');
        }));
    }

    private function resolveFontPath(ComputedStyles $styles): string
    {
        $path = __DIR__ . '/../Fonts/times-new-roman';

        if ($styles->font_weight === FontWeight::BOLD) {
            $path .= '-bold';
        }

        if ($styles->font_style === FontStyle::ITALIC) {
            $path .= '-italic';
        }

        return $path.'.ttf';
    }
}