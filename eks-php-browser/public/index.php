<?php

error_reporting(E_ALL ^ E_DEPRECATED);

require_once __DIR__ . '/../vendor/autoload.php';

use Klein\Klein;
use Klein\Request;
use Klein\Response;
use League\Uri\Uri;
use League\Uri\UriResolver;

$klein = new Klein();
$loader = new \Twig\Loader\FilesystemLoader(__DIR__ . '/../templates');
$twig = new \Twig\Environment($loader, [
    'cache' => false,//__DIR__ . '/../twig_cache',
]);

$default_link = 'https://info.cern.ch/hypertext/WWW/TheProject.html';

$klein->respond('GET', '/', function (Request $request, Response $response) use ($twig, $default_link) {
    $request_link = $request->paramsGet()->get('link', null);
    $page_width = (int)$request->paramsGet()->get('width', 800);
    if ($page_width === null) {
        $page_width = 800;
    }

    if ($page_width < 100 || $page_width > 2000) {
        $page_width = 800;
    }

    $createBrowserLink = function (string $url) use ($page_width) {
        $link = '/?width='.$page_width;
        $link .= '&link='.urlencode($url);
        return $link;
    };
    
    if ($request_link === null) {
        $response->redirect($createBrowserLink($default_link));
        return;
    }

    if (!str_starts_with($request_link, 'https://info.cern.ch/')) {
        $response->redirect($createBrowserLink($default_link));
        return;
    }

    // $html = file_get_contents(__DIR__ . '/assets/test_main.html');
    $html = file_get_contents($request_link);
    $renderer = new \Ekgame\PhpBrowser\HtmlToImageRenderer();
    $image = $renderer->render($html, $page_width);
    $areas = $renderer->getAreas();

    $base_uri = Uri::createFromString($request_link);
    return $twig->render('index.html.twig', [
        'current_link' => $base_uri->toString(),
        'current_width' => $page_width,
        'image' => $image->toPng()->toDataUri(),
        'areas' => array_map(function ($item) use ($base_uri, $createBrowserLink) {
            $raw_link = $item->getContext()['href'];
            $relative_uri = Uri::createFromString($raw_link);
            $absolute_uri = UriResolver::resolve($relative_uri, $base_uri);
            return [
                'x1' => $item->getArea()->getX(),
                'y1' => $item->getArea()->getY(),
                'x2' => $item->getArea()->getX() + $item->getArea()->getWidth(),
                'y2' => $item->getArea()->getY() + $item->getArea()->getHeight(),
                'href' => $createBrowserLink($absolute_uri->toString()),
                'alt' => $absolute_uri->toString(),
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