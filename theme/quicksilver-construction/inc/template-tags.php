<?php

if (!defined('ABSPATH')) {
    exit;
}

function qsc_cta_url(array $cta): string
{
    if (array_key_exists('targetPageKey', $cta) && is_string($cta['targetPageKey'])) {
        return qsc_url_for_page_key($cta['targetPageKey']);
    }

    if (array_key_exists('href', $cta) && is_string($cta['href'])) {
        return $cta['href'];
    }

    throw new RuntimeException('QuickSilver CTA must include targetPageKey or href.');
}

function qsc_render_cta(array $cta, string $className): void
{
    $label = qsc_required($cta, 'label');
    if (!is_string($label) || $label === '') {
        throw new RuntimeException('QuickSilver CTA label must be a non-empty string.');
    }

    printf(
        '<a class="%s" href="%s">%s</a>',
        esc_attr($className),
        esc_url(qsc_cta_url($cta)),
        esc_html($label)
    );
}

function qsc_render_image(array $asset, string $className, string $loading = 'lazy'): void
{
    printf(
        '<img class="%s" src="%s" width="%d" height="%d" alt="%s" loading="%s">',
        esc_attr($className),
        esc_url(qsc_asset_url($asset)),
        qsc_asset_width($asset),
        qsc_asset_height($asset),
        esc_attr(qsc_asset_alt($asset)),
        esc_attr($loading)
    );
}

function qsc_render_decorative_image(array $asset, string $className, string $loading = 'lazy'): void
{
    printf(
        '<img class="%s" src="%s" width="%d" height="%d" alt="" loading="%s" aria-hidden="true">',
        esc_attr($className),
        esc_url(qsc_asset_url($asset)),
        qsc_asset_width($asset),
        qsc_asset_height($asset),
        esc_attr($loading)
    );
}

function qsc_render_section_text(array $section): void
{
    if (array_key_exists('heading', $section) && is_string($section['heading']) && $section['heading'] !== '') {
        printf('<h2>%s</h2>', esc_html($section['heading']));
    }

    if (array_key_exists('body', $section) && is_string($section['body']) && $section['body'] !== '') {
        printf('<p>%s</p>', esc_html($section['body']));
    }
}
