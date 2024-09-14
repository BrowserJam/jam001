<?php

namespace Ekgame\PhpBrowser\Layout;

use Ekgame\PhpBrowser\DomNode;
use Ekgame\PhpBrowser\Style\ComputedStyles;
use Intervention\Image\Interfaces\FontInterface;

class LayoutNode
{
    private ComputedStyles $computed_styles;
    private ?string $text = null;
    private ?FontInterface $font = null;

    private ?int $x = null;
    private ?int $y = null;
    private ?int $width = null;
    private ?int $height = null;

    private int $vertical_offset = 0;

    private bool $has_size = true;
    
    private ?DomNode $backing_node;

    private ?LayoutNode $parent;

    /** @var LayoutNode[] */
    private array $children = [];

    /** @var Rectangle[] */
    private $hit_boxes = [];

    public function __construct(ComputedStyles $computed_styles, ?string $text = null, ?DomNode $backing_node = null)
    {
        $this->backing_node = $backing_node;
        $this->computed_styles = $computed_styles;
        $this->text = $text;
    }

    public function getText(): ?string
    {
        return $this->text;
    }

    public function setParent(LayoutNode $parent): void
    {
        $this->parent = $parent;
    }

    public function addChild(LayoutNode $node): void
    {
        $this->children[] = $node;
    }

    public function getBackingNode(): ?DomNode
    {
        return $this->backing_node;
    }

    public function getParent(): ?LayoutNode
    {
        return $this->parent;
    }

    /** @return LayoutNode[] */
    public function getChildren(): array
    {
        return $this->children;
    }

    public function getChildrenWithLookahead(): array
    {
        $results = [];

        for ($i = 0; $i < count($this->children); $i++) {
            $current = $this->children[$i];
            $next = $this->children[$i + 1] ?? null;
            $results[] = [$current, $next];
        }

        return $results;
    }

    public function getComputedStyles(): ComputedStyles
    {
        return $this->computed_styles;
    }

    public function getX(): ?int
    {
        return $this->x;
    }

    public function getY(): ?int
    {
        return $this->y;
    }

    public function getWidth(): ?int
    {
        return $this->width;
    }

    public function getHeight(): ?int
    {
        return $this->height;
    }

    public function setPosition(?int $x, ?int $y): void
    {
        if ($x !== null) {
            $this->x = $x;
        }

        if ($y !== null) {
            $this->y = $y;
        }
    }

    public function setWidth(int $width): void
    {
        $this->width = $width;
    }

    public function setHeight(int $height): void
    {
        $this->height = $height;
    }

    public function setDimensions(?int $width, ?int $height): void
    {
        if ($width !== null) {
            $this->width = $width;
        }

        if ($height !== null) {
            $this->height = $height;
        }
    }

    public function setFont(FontInterface $font): void
    {
        $this->font = $font;
    }

    public function isValidForBasicRendering(): bool
    {
        if ($this->x === null || $this->y === null) {
            return false;
        }

        foreach ($this->children as $child) {
            if (!$child->isValidForBasicRendering()) {
                return false;
            }
        }

        return true;
    }

    public function getFont(): FontInterface
    {
        if ($this->font === null) {
            throw new \RuntimeException('Font not set.');
        }

        return $this->font;
    }

    public function getVerticalOffset(): int
    {
        return $this->vertical_offset;
    }

    public function setVerticalOffset(int $offset): void
    {
        $this->vertical_offset = $offset;
    }

    public function hasSize(): bool
    {
        return $this->has_size;
    }

    public function setHasSize(bool $has_size): void
    {
        $this->has_size = $has_size;
    }

    /** @return Rectangle[] */
    public function getHitBoxes(): array
    {
        return $this->hit_boxes;
    }

    /** @param Rectangle[] $hit_boxes */
    public function setHitBoxes(array $hit_boxes): void
    {
        $this->hit_boxes = $hit_boxes;
    }

    /** @return LayoutNode[] */
    public function collectSizedElements(): array
    {
        if ($this->hasSize()) {
            return [$this];
        }

        $elements = [];

        foreach ($this->children as $child) {
            $elements = array_merge($elements, $child->collectSizedElements());
        }

        return $elements;
    }

    public function toRectangle(): Rectangle
    {
        if ($this->x === null || $this->y === null || $this->width === null || $this->height === null) {
            throw new \RuntimeException('Node has no dimensions');
        }

        return new Rectangle($this->x, $this->y, $this->width, $this->height);
    }
}