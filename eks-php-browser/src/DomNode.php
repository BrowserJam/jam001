<?php

namespace Ekgame\PhpBrowser;
use Ekgame\PhpBrowser\Style\ComputedStyles;
use Ekgame\PhpBrowser\Style\NodeStylesBag;

class DomNode
{
    private string $tag;

    /** @var array<string, string> */
    private array $attributes;

    private ?DomNode $parent = null;

    /** @var DomNode[] */
    private array $children;

    private ?NodeStylesBag $styles = null;

    private ?ComputedStyles $computedStyles = null;

    public function __construct(string $tag, array $attributes = [])
    {
        $this->tag = strtolower($tag);
        $this->attributes = $attributes;
        $this->children = [];
    }

    public function setParent(?DomNode $parent): void
    {
        $this->parent = $parent;
    }

    public function addChild(DomNode $node): void
    {
        $node->setParent($this);
        $this->children[] = $node;
    }

    public function removeChild(DomNode $node): void
    {
        $index = array_search($node, $this->children, true);
        if ($index === false) {
            throw new \RuntimeException('Node not found in children.');
        }

        unset($this->children[$index]);

        if ($node->getParent() === $this) {
            $node->setParent(null);
        }
    }

    public function getTag(): string
    {
        return $this->tag;
    }
    
    public function getAttributes(): array
    {
        return $this->attributes;
    }

    public function getAttribute(string $name): ?string
    {
        return $this->attributes[$name] ?? null;
    }

    public function setAttribute(string $name, string $value): void
    {
        $this->attributes[$name] = $value;
    }

    public function getParent(): ?DomNode
    {
        return $this->parent;
    }

    /** @return DomNode[] */
    public function getChildren(): array
    {
        return $this->children;
    }

    public function getStyles(): NodeStylesBag
    {
        if ($this->styles === null) {
            throw new \RuntimeException('Styles not set.');
        }
        
        return $this->styles;
    }

    public function setStyles(NodeStylesBag $styles): void
    {
        $this->styles = $styles;
    }

    public function getComputedStyles(): ComputedStyles
    {
        if ($this->computedStyles === null) {
            throw new \RuntimeException('Computed styles not set.');
        }

        return $this->computedStyles;
    }

    public function setComputedStyles(ComputedStyles $computedStyles): void
    {
        $this->computedStyles = $computedStyles;
    }

    public function resolveTextNode(): ?DomNode
    {
        $current = $this;
        while ($current->getTag() !== '#text') {
            if (count($current->getChildren()) === 0) {
                return null;
            }

            $current = $current->getChildren()[0];
        }

        return $current;
    }
}