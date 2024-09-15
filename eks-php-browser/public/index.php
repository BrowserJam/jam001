<?php

error_reporting(E_ALL ^ E_DEPRECATED);

require_once __DIR__ . '/../vendor/autoload.php';

use Klein\Klein;
use Klein\Request;
use Klein\Response;
use League\Uri\Uri;
use League\Uri\UriResolver;

$twig = new \Twig\Environment(
    new \Twig\Loader\FilesystemLoader(__DIR__ . '/../templates'),
    ['cache' => false,/*__DIR__ . '/../twig_cache'*/],
);

$klein = new Klein();


$default_link = 'https://info.cern.ch/hypertext/WWW/TheProject.html';

function createBrowserLink(string $url, int $page_width) {
    $link = '/?width='.$page_width;
    $link .= '&link='.urlencode($url);
    return $link;
};

function generateResponse(string $html, int $page_width, string $current_link)
{
    global $twig;

    $renderer = new \Ekgame\PhpBrowser\HtmlToImageRenderer();
    $image = $renderer->render($html, $page_width);
    $areas = $renderer->getAreas();

    $base_uri = Uri::createFromString($current_link);
    return $twig->render('index.html.twig', [
        'current_link' => $base_uri->toString(),
        'current_width' => $page_width,
        'image' => $image->toPng()->toDataUri(),
        'areas' => array_map(function ($item) use ($base_uri, $page_width) {
            $raw_link = $item->getContext()['href'];
            $relative_uri = Uri::createFromString($raw_link);
            $absolute_uri = UriResolver::resolve($relative_uri, $base_uri);
            return [
                'x1' => $item->getArea()->getX(),
                'y1' => $item->getArea()->getY(),
                'x2' => $item->getArea()->getX() + $item->getArea()->getWidth(),
                'y2' => $item->getArea()->getY() + $item->getArea()->getHeight(),
                'href' => createBrowserLink($absolute_uri->toString(), $page_width),
                'alt' => $absolute_uri->toString(),
            ];
        }, $areas)
    ]);
}

function generateErrorResponse(string $message, int $page_width, string $current_link)
{
    global $twig;
    $html = $twig->render('error.html.twig', ['error' => $message]);
    return generateResponse($html, $page_width, $current_link);
}

$klein->respond('GET', '/', function (Request $request, Response $response) use ($twig, $default_link) {
    $request_link = $request->paramsGet()->get('link', null);
    $page_width = (int)$request->paramsGet()->get('width', 900);
    if ($page_width === null) {
        $page_width = 900;
    }

    if ($request_link === null) {
        $response->redirect(createBrowserLink($default_link, $page_width));
        return;
    }

    if ($page_width < 100 || $page_width > 2000) {
        return generateErrorResponse(
            'Invalid page width, only values between 100 and 2000 are allowed.',
            $page_width,
            $request_link
        );
    }

    if (!str_starts_with($request_link, 'https://info.cern.ch/') && !str_starts_with($request_link, 'http://info.cern.ch/')) {
        return generateErrorResponse(
            'Can not browse that page, only pages from <a href="https://info.cern.ch/">https://info.cern.ch/</a> are allowed.',
            $page_width,
            $request_link
        );
    }

    try {
        $client = new \GuzzleHttp\Client();
        $response = $client->request('GET', $request_link);
        $html = $response->getBody()->getContents();
        return generateResponse($html, $page_width, $request_link);
    } catch (\GuzzleHttp\Exception\GuzzleException $e) {
        return generateErrorResponse('Failed to fetch the page: '.$e->getMessage(), $page_width, $request_link);
    } catch (\RuntimeException $e) {
        return generateErrorResponse('Failed to display the page: '.$e->getMessage(), $page_width, $request_link);
    }
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