<?php

namespace Ekgame\PhpBrowser\Style\Unit;

class Measurement
{
    private float $size;
    private SizeUnit $unit;

    public function __construct(float $size, SizeUnit $unit)
    {
        $this->size = $size;
        $this->unit = $unit;
    }

    public function getSize(): float
    {
        return $this->size;
    }

    public function getUnit(): SizeUnit
    {
        return $this->unit;
    }

    public function apply(float $previous): float
    {
        if ($this->unit === SizeUnit::PX) {
            return $this->size;
        }

        if ($this->unit === SizeUnit::EM) {
            return $this->size * $previous;
        }

        throw new \Exception('Unknown unit');
    }
}