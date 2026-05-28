<?php

if (!defined('ABSPATH')) {
    exit;
}

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

function qsc_enqueue_assets(): void
{
    $theme = wp_get_theme();

    wp_enqueue_style(
        'qsc-site',
        get_template_directory_uri() . '/assets/css/site.css',
        [],
        $theme->get('Version')
    );
}
add_action('wp_enqueue_scripts', 'qsc_enqueue_assets');
