<?php

namespace Ekgame\PhpBrowser\Layout;

class Rectangle
{
    private float $x;
    private float $y;
    private float $width;
    private float $height;

    public function __construct(float $x, float $y, float $width, float $height)
    {
        $this->x = $x;
        $this->y = $y;
        $this->width = $width;
        $this->height = $height;
    }

    public function getX(): float
    {
        return $this->x;
    }

    public function getY(): float
    {
        return $this->y;
    }

    public function getWidth(): float
    {
        return $this->width;
    }

    public function getHeight(): float
    {
        return $this->height;
    }

    public function setX(float $x): void
    {
        $this->x = $x;
    }

    public function setY(float $y): void
    {
        $this->y = $y;
    }

    public function setWidth(float $width): void
    {
        $this->width = $width;
    }

    public function setHeight(float $height): void
    {
        $this->height = $height;
    }

    public function expand(Rectangle $rectangle): Rectangle
    {
        $x = min($this->x, $rectangle->getX());
        $y = min($this->y, $rectangle->getY());
        $width = max($this->x + $this->width, $rectangle->getX() + $rectangle->getWidth()) - $x;
        $height = max($this->y + $this->height, $rectangle->getY() + $rectangle->getHeight()) - $y;
        return new Rectangle($x, $y, $width, $height);
    }

    public function intersects(Rectangle $rectangle): bool
    {
        return $this->x < $rectangle->getX() + $rectangle->getWidth()
            && $this->x + $this->width > $rectangle->getX()
            && $this->y < $rectangle->getY() + $rectangle->getHeight()
            && $this->y + $this->height > $rectangle->getY();
    }
}