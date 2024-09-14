<?php

namespace Ekgame\PhpBrowser;

use Ekgame\PhpBrowser\Layout\LayoutCalculator;
use Ekgame\PhpBrowser\Layout\LayoutNode;
use Ekgame\PhpBrowser\Layout\Rectangle;
use Ekgame\PhpBrowser\Style\Unit\TextDecoration;
use Intervention\Image\Geometry\Factories\LineFactory;
use Intervention\Image\ImageManager;
use Intervention\Image\Drivers\Gd\Driver;
use Intervention\Image\Interfaces\ImageInterface;

class HtmlToImageRenderer
{
    private ImageManager $imageManager;
    private $areas = [];

    public function __construct()
    {
        $this->imageManager = new ImageManager(new Driver());
    }

    public function render(string $html, int $page_width): ImageInterface
    {
        $parser = new HtmlToNodeTreeParser();
        $rootNode = $parser->parse($html);

        $layoutEngine = new LayoutCalculator($page_width);
        $rootLayoutNode = $layoutEngine->layoutRootNode($rootNode);

        if (!$rootLayoutNode->isValidForBasicRendering()) {
            throw new \RuntimeException('Not all elements have been laid out');
        }

        $image = $this->imageManager->create(
            $rootLayoutNode->getWidth(),
            $rootLayoutNode->getHeight(),
        );

        $image->fill('white');

        $this->renderNode(
            $rootLayoutNode, 
            $image, 
            $rootLayoutNode->getX(), 
            $rootLayoutNode->getY(),
        );

        return $image;
    }

    private function renderNode(LayoutNode $node, ImageInterface $image, int $offset_x, int $offset_y)
    {
        if ($node->getBackingNode()?->getTag() === 'a' && $node->getBackingNode()->getAttribute('href') !== null) {
            $hit_boxes = $node->getHitBoxes();
            foreach ($hit_boxes as $hit_box) {
                $rectangle = new Rectangle(
                    $offset_x + $hit_box->getX(),
                    $offset_y + $hit_box->getY(),
                    $hit_box->getWidth(),
                    $hit_box->getHeight(),
                );

                $this->areas[] = new ClickableArea(
                    $rectangle,
                    'open_link',
                    [
                        'href' => $node->getBackingNode()->getAttribute('href')
                    ],
                );
            }
        }

        if ($node->getText() !== null && trim($node->getText()) !== '') {
            if ($node->getComputedStyles()->text_decoration == TextDecoration::UNDERLINE) {
                $image->drawLine(function (LineFactory $line) use ($node, $offset_x, $offset_y) {
                    $line->color($node->getParent()->getFont()->color());
                    $line->width(1);
                    $x = $offset_x + $node->getX();
                    $y = $offset_y + $node->getY() + $node->getHeight() - $node->getVerticalOffset() - 2;
                    $w = $node->getWidth();
                    $line->from($x, $y);
                    $line->to($x + $w, $y);
                });
            }

            $image->text(
                $node->getText(), 
                $offset_x + $node->getX(), 
                $offset_y + $node->getY() + $node->getVerticalOffset(),
                $node->getParent()->getFont(),
            );

            return;
        }

        foreach ($node->getChildren() as $child) {
            $this->renderNode(
                $child, 
                $image, 
                $offset_x + $node->getX(), 
                $offset_y + $node->getY(),
            );
        }
    }

    /** @return ClickableArea[] */
    public function getAreas(): array
    {
        return $this->areas;
    }
}