<?php

namespace Ekgame\PhpBrowser;
use Ekgame\PhpBrowser\Layout\Rectangle;

class ClickableArea
{
    private Rectangle $area;
    private string $action;
    private array $context = [];

    public function __construct(Rectangle $area, string $action, array $context = [])
    {
        $this->area = $area;
        $this->action = $action;
        $this->context = $context;
    }

    public function getArea(): Rectangle
    {
        return $this->area;
    }

    public function getAction(): string
    {
        return $this->action;
    }

    public function getContext(): array
    {
        return $this->context;
    }
}