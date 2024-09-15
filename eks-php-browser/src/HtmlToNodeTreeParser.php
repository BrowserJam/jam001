<?php

namespace Ekgame\PhpBrowser;

use Ekgame\PhpBrowser\Style\DomNodeStyleCalculator;
use Ekgame\PhpBrowser\Style\Unit\Display;
use PHPHtmlParser\Dom\Node\AbstractNode;
use PHPHtmlParser\Dom\Node\HtmlNode;
use PHPHtmlParser\Dom\Node\TextNode;

class HtmlToNodeTreeParser
{
    public function parse(string $html): DomNode
    {
        $dom = new \PHPHtmlParser\Dom;
        $dom->loadStr($html);

        $body = $dom->find('body')[0] ?? $dom->find('BODY')[0] ?? null;

        if (!$body) {
            throw new \RuntimeException('No body tag found in the HTML.');
        }
        
        $root_node = $this->parseNode($body);
        if ($root_node === null) {
            throw new \RuntimeException('Root node is empty.');
        }

        $this->fixUnclosedTags($root_node);

        $styleCalculator = new DomNodeStyleCalculator();
        $styleCalculator->calculate($root_node);

        $this->normalizeWhitespace($root_node);

        return $root_node;
    }

    private function parseNode(AbstractNode $node): ?DomNode
    {
        if ($node instanceof TextNode) {
            $text = $node->text();
            
            if (trim($text) === '') {
                return null;
            }

            return new DomNode('#text', [
                'text' => $node->text(),
            ]);
        } 
        else if ($node instanceof HtmlNode) {
            $attributes = [];
            foreach ($node->getAttributes() as $name => $value) {
                $attributes[$name] = $value ?: '';
            }

            $new_node = new DomNode($node->getTag()->name(), $attributes);

            foreach ($node->getChildren() as $child) {
                $child_node = $this->parseNode($child);
                if ($child_node === null) {
                    continue;
                }
                
                $new_node->addChild($child_node);
            }

            return $new_node;
        }

        throw new \RuntimeException('Unknown node type: ' . get_class($node));
    }

    

    private function fixUnclosedTags(DomNode $node)
    {
        // The library i'm using doesn't handle auto-closing tags correctly.
        // This function fixes that by moving children of auto-closing tags to the parent.

        foreach ($node->getChildren() as $moved) {
            $this->fixUnclosedTags($moved);
        }

        $auto_closing_tags = [
            'p' => [
                'address', 'article', 'aside', 'blockquote', 'details', 'dialog', 'div', 'dl', 'fieldset',
                'figcaption', 'figure', 'footer', 'form', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'header',
                'hgroup', 'hr', 'main', 'menu', 'nav', 'ol', 'p', 'pre', 'search', 'section', 'table', 'ul',
            ],
            'dt' => ['dt', 'dd'],
            'dd' => ['dt', 'dd'],
        ];

        $is_self_closing = in_array($node->getTag(), array_keys($auto_closing_tags), true);

        if ($is_self_closing && $node->getParent() !== null) {
            $closed_by = $auto_closing_tags[$node->getTag()];

            $should_close = false;
            $children = $node->getChildren();

            for ($i = 0; $i < count($children); $i++) {
                $child = $children[$i];
                $should_close = $should_close || in_array($child->getTag(), $closed_by, true);

                if (!$should_close) {
                    continue;
                }

                $node->removeChild($child);
                $node->getParent()->addChild($child);
            }
        }
    }

    private function normalizeWhitespace(DomNode $node)
    {
        if ($node->getComputedStyles()->display !== Display::BLOCK) {
            return;
        }

        $groups = $this->getConsecutiveInlineNodes($node);

        /** @var DomNode[] $group */
        foreach ($groups as $group) {
            $start_node = $group[0]->resolveTextNode();
            if ($start_node) {
                $start_node->setAttribute('text', ltrim($start_node->getAttribute('text')));
            }

            $end_node = $group[count($group) - 1]->resolveTextNode();
            if ($end_node) {
                $end_node->setAttribute('text', rtrim($end_node->getAttribute('text')));
            }
        }

        foreach ($node->getChildren() as $child) {
            if ($node->getComputedStyles()->display === Display::BLOCK) {
                $this->normalizeWhitespace($child);
            }
        }
    }

    private function getConsecutiveInlineNodes(DomNode $node): array
    {
        $groups = [];
        $nodes = [];
        $children = $node->getChildren();

        for ($i = 0; $i < count($children); $i++) {
            $child = $children[$i];

            if ($child->getComputedStyles()->display === Display::INLINE) {
                $nodes[] = $child;
            } else {
                if (count($nodes) > 0) {
                    $groups[] = $nodes;
                    $nodes = [];
                }
            }
        }

        if (count($nodes) > 0) {
            $groups[] = $nodes;
        }

        return $groups;
    }
}