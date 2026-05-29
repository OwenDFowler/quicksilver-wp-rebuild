<?php

if (!defined('ABSPATH')) {
    exit;
}

require_once get_template_directory() . '/inc/theme-data.php';
require_once get_template_directory() . '/inc/template-tags.php';

function qsc_theme_setup(): void
{
    add_theme_support('title-tag');
    add_theme_support('post-thumbnails');
    add_theme_support('html5', ['comment-list', 'comment-form', 'search-form', 'gallery', 'caption', 'style', 'script']);

    register_nav_menus([
        'primary' => __('Primary Navigation', 'quicksilver-construction'),
    ]);
}
add_action('after_setup_theme', 'qsc_theme_setup');

function qsc_theme_asset_version(string $relativePath): string
{
    $path = get_template_directory() . '/' . ltrim($relativePath, '/');
    if (!is_readable($path)) {
        throw new RuntimeException("Missing QuickSilver theme asset: $relativePath");
    }

    return (string) filemtime($path);
}

function qsc_enqueue_assets(): void
{
    wp_enqueue_style(
        'qsc-site',
        get_template_directory_uri() . '/assets/css/site.css',
        [],
        qsc_theme_asset_version('assets/css/site.css')
    );

    wp_enqueue_script(
        'qsc-interactions',
        get_template_directory_uri() . '/assets/js/interactions.js',
        [],
        qsc_theme_asset_version('assets/js/interactions.js'),
        true
    );
    wp_script_add_data('qsc-interactions', 'defer', true);
}
add_action('wp_enqueue_scripts', 'qsc_enqueue_assets');
