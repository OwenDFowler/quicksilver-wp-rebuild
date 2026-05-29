<?php

if (!defined('ABSPATH')) {
    exit;
}

function qsc_site_data(): array
{
    static $data = null;

    if (is_array($data)) {
        return $data;
    }

    $path = get_template_directory() . '/inc/generated/site-data.php';
    if (!is_readable($path)) {
        throw new RuntimeException('Missing generated QuickSilver theme data. Run scripts/generate-theme-data.ps1 before packaging or deploying the theme.');
    }

    $loaded = require $path;
    if (!is_array($loaded)) {
        throw new RuntimeException('Generated QuickSilver theme data must return an array.');
    }

    $data = $loaded;
    return $data;
}

function qsc_required(array $source, string $key)
{
    if (!array_key_exists($key, $source)) {
        throw new RuntimeException("Missing required QuickSilver data key: $key");
    }

    return $source[$key];
}

function qsc_site_identity(): array
{
    $identity = qsc_required(qsc_site_data(), 'siteIdentity');
    if (!is_array($identity)) {
        throw new RuntimeException('QuickSilver siteIdentity must be an array.');
    }

    return $identity;
}

function qsc_navigation_items(): array
{
    $navigation = qsc_required(qsc_site_data(), 'navigation');
    if (!is_array($navigation)) {
        throw new RuntimeException('QuickSilver navigation must be an array.');
    }

    return $navigation;
}

function qsc_home_page(): array
{
    $homePage = qsc_required(qsc_site_data(), 'homePage');
    if (!is_array($homePage)) {
        throw new RuntimeException('QuickSilver homePage must be an array.');
    }

    return $homePage;
}

function qsc_route_for_page_key(string $pageKey): string
{
    $routes = qsc_required(qsc_site_data(), 'routeByPageKey');
    if (!is_array($routes) || !array_key_exists($pageKey, $routes)) {
        throw new RuntimeException("Missing route for QuickSilver pageKey: $pageKey");
    }

    return (string) $routes[$pageKey];
}

function qsc_url_for_page_key(string $pageKey): string
{
    return home_url(qsc_route_for_page_key($pageKey));
}

function qsc_media(): array
{
    $media = qsc_required(qsc_site_data(), 'media');
    if (!is_array($media)) {
        throw new RuntimeException('QuickSilver media must be an array.');
    }

    return $media;
}

function qsc_logo_asset(): array
{
    $logo = qsc_required(qsc_media(), 'logo');
    if (!is_array($logo)) {
        throw new RuntimeException('QuickSilver logo media must be an array.');
    }

    return $logo;
}

function qsc_home_hero_assets(): array
{
    $hero = qsc_required(qsc_media(), 'homeHero');
    if (!is_array($hero) || count($hero) === 0) {
        throw new RuntimeException('QuickSilver home hero media must contain at least one asset.');
    }

    return $hero;
}

function qsc_home_still_asset(string $slot): array
{
    $assets = qsc_required(qsc_media(), 'homeStill');
    if (!is_array($assets) || !array_key_exists($slot, $assets) || !is_array($assets[$slot])) {
        throw new RuntimeException("Missing QuickSilver homepage still-design asset: $slot.");
    }

    return $assets[$slot];
}

function qsc_home_value_asset(string $slot): array
{
    $assets = qsc_required(qsc_media(), 'homeValues');
    if (!is_array($assets) || !array_key_exists($slot, $assets) || !is_array($assets[$slot])) {
        throw new RuntimeException("Missing QuickSilver homepage values asset: $slot.");
    }

    return $assets[$slot];
}

function qsc_asset_url(array $asset): string
{
    $path = qsc_required($asset, 'path');
    if (!is_string($path) || $path === '' || str_starts_with($path, '/') || str_contains($path, '..')) {
        throw new RuntimeException('QuickSilver media asset has an invalid theme-relative path.');
    }

    return get_template_directory_uri() . '/' . ltrim($path, '/');
}

function qsc_asset_alt(array $asset): string
{
    $alt = qsc_required($asset, 'alt');
    if (!is_string($alt)) {
        throw new RuntimeException('QuickSilver media asset alt must be a string.');
    }

    return $alt;
}

function qsc_asset_width(array $asset): int
{
    $width = qsc_required($asset, 'width');
    if (!is_int($width) || $width <= 0) {
        throw new RuntimeException('QuickSilver media asset width must be a positive integer.');
    }

    return $width;
}

function qsc_asset_height(array $asset): int
{
    $height = qsc_required($asset, 'height');
    if (!is_int($height) || $height <= 0) {
        throw new RuntimeException('QuickSilver media asset height must be a positive integer.');
    }

    return $height;
}
