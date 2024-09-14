<?php

namespace Ekgame\PhpBrowser\Style;

use Ekgame\PhpBrowser\DomNode;

interface StyleResolver
{
    public function resolve(DomNode $style): NodeStylesBag;
}