<!doctype html>
<html <?php language_attributes(); ?>>
<head>
    <meta charset="<?php bloginfo('charset'); ?>">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <?php wp_head(); ?>
</head>
<body <?php body_class(); ?>>
<?php wp_body_open(); ?>

<a class="skip-link" href="#main-content"><?php esc_html_e('Skip to content', 'quicksilver-construction'); ?></a>

<header class="site-header">
    <div class="site-header__top">
        <span>PO Box 852 Langley, WA 98260</span>
        <a href="tel:+13603211969">Call Us: (360) 321-1969</a>
        <a href="mailto:Contact@TeamQSC.com">Contact@TeamQSC.com</a>
    </div>

    <div class="site-header__main">
        <a class="brand" href="<?php echo esc_url(home_url('/')); ?>" aria-label="<?php bloginfo('name'); ?>">
            <span class="brand__mark">QS</span>
            <span class="brand__text">
                <strong>QuickSilver</strong>
                <span>Construction</span>
            </span>
        </a>

        <nav class="site-nav" aria-label="<?php esc_attr_e('Primary navigation', 'quicksilver-construction'); ?>">
            <?php
            wp_nav_menu([
                'theme_location' => 'primary',
                'container' => false,
                'menu_class' => 'site-nav__list',
                'fallback_cb' => false,
            ]);
            ?>
        </nav>

        <a class="quote-link" href="<?php echo esc_url(home_url('/contact/')); ?>">Get A Quote</a>
    </div>
</header>
