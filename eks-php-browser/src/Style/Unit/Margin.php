<?php

namespace Ekgame\PhpBrowser\Style\Unit;

class Margin
{
    private Measurement $top;
    private Measurement $right;
    private Measurement $bottom;
    private Measurement $left;

    public function __construct(Measurement $top, Measurement $right, Measurement $bottom, Measurement $left)
    {
        $this->top = $top;
        $this->right = $right;
        $this->bottom = $bottom;
        $this->left = $left;
    }

    public function getTop(): Measurement
    {
        return $this->top;
    }

    public function getRight(): Measurement
    {
        return $this->right;
    }

    public function getBottom(): Measurement
    {
        return $this->bottom;
    }

    public function getLeft(): Measurement
    {
        return $this->left;
    }
}