<?php

error_reporting(E_ALL ^ E_DEPRECATED);

require_once __DIR__ . '/../vendor/autoload.php';

use Klein\Klein;
use Klein\Request;
use Klein\Response;

$klein = new Klein();
$loader = new \Twig\Loader\FilesystemLoader(__DIR__ . '/../templates');
$twig = new \Twig\Environment($loader, [
    'cache' => __DIR__ . '/../twig_cache',
]);

$klein->respond('GET', '/', function (Request $request, Response $response) use ($twig) {
    $request_link = $request->paramsGet()->get('link', null);
    if ($request_link === null) {
        $response->body('Missing link to render');
        return;
    }

    $test_html = file_get_contents(__DIR__ . '/assets/test_main.html');
    $renderer = new \Ekgame\PhpBrowser\HtmlToImageRenderer();
    $image = $renderer->render($test_html, 930);
    $areas = $renderer->getAreas();

    return $twig->render('index.html.twig', [
        'image' => $image->toPng()->toDataUri(),
        'areas' => array_map(function ($item) {
            $raw_link = $item->getContext()['href'];
            return [
                'x1' => $item->getArea()->getX(),
                'y1' => $item->getArea()->getY(),
                'x2' => $item->getArea()->getX() + $item->getArea()->getWidth(),
                'y2' => $item->getArea()->getY() + $item->getArea()->getHeight(),
                'href' => $raw_link,
                'alt' => $raw_link,
            ];
        }, $areas)
    ]);
});

$klein->onHttpError(function ($code, Klein $router) {
    switch ($code) {
        case 404:
            $router->response()->redirect('/');
            break;
        case 405:
            $router->response()->body('Method not allowed');
            break;
        default:
            $router->response()->body('An error occurred');
    }
});

$klein->dispatch();