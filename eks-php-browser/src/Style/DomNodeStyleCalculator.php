<?php

namespace Ekgame\PhpBrowser\Style;
use Ekgame\PhpBrowser\DomNode;
use Ekgame\PhpBrowser\Style\ComputedStyles;
use Ekgame\PhpBrowser\Style\StyleResolver;
use Ekgame\PhpBrowser\Style\UserAgentStyleResolver;

class DomNodeStyleCalculator
{
    private StyleResolver $style_resolver;

    public function __construct()
    {
        $this->style_resolver = new UserAgentStyleResolver();
    }
    
    public function calculate(DomNode $root_node): void
    {
        $this->resolveStyles($root_node);
        $this->computeStyles($root_node);
    }

    private function resolveStyles(DomNode $node)
    {
        $node->setStyles($this->style_resolver->resolve($node));

        foreach ($node->getChildren() as $child) {
            $this->resolveStyles($child);
        }
    }

    private function computeStyles(DomNode $node)
    {
        $parent_styles = $node->getParent()?->getComputedStyles() ?: new ComputedStyles();
        $computed_styles = $node->getStyles()->collapse($parent_styles);
        $node->setComputedStyles($computed_styles);

        foreach ($node->getChildren() as $child) {
            $this->computeStyles($child);
        }
    }
}