<!doctype html>
<html <?php language_attributes(); ?>>
<head>
    <meta charset="<?php echo esc_attr(get_bloginfo('charset')); ?>">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <?php wp_head(); ?>
</head>
<body <?php body_class(); ?>>
<?php wp_body_open(); ?>

<?php
$identity = qsc_site_identity();
$phone = qsc_required($identity, 'phone');
$email = qsc_required($identity, 'email');
$address = qsc_required($identity, 'mailingAddress');
$primaryCta = qsc_required($identity, 'primaryCta');
$logo = qsc_logo_asset();
?>

<a class="skip-link" href="#main-content"><?php esc_html_e('Skip to content', 'quicksilver-construction'); ?></a>

<header class="site-header">
    <div class="site-header__top">
        <span><?php echo esc_html__('Location:', 'quicksilver-construction') . ' ' . esc_html($address['line1'] . ' ' . $address['cityStateZip']); ?></span>
        <a href="<?php echo esc_url($phone['href']); ?>"><?php esc_html_e('Call Us:', 'quicksilver-construction'); ?> <?php echo esc_html($phone['display']); ?></a>
        <a href="<?php echo esc_url($email['href']); ?>"><?php esc_html_e('Mail:', 'quicksilver-construction'); ?> <?php echo esc_html($email['display']); ?></a>
    </div>

    <div class="site-header__main">
        <a class="brand" href="<?php echo esc_url(home_url('/')); ?>" aria-label="<?php echo esc_attr(get_bloginfo('name')); ?>">
            <img
                class="brand__logo"
                src="<?php echo esc_url(qsc_asset_url($logo)); ?>"
                width="<?php echo esc_attr((string) qsc_asset_width($logo)); ?>"
                height="<?php echo esc_attr((string) qsc_asset_height($logo)); ?>"
                alt="<?php echo esc_attr(qsc_asset_alt($logo)); ?>"
            >
        </a>

        <button class="menu-toggle" type="button" aria-controls="primary-menu" aria-expanded="false">
            <span class="menu-toggle__bar"></span>
            <span class="menu-toggle__bar"></span>
            <span class="menu-toggle__bar"></span>
            <span class="screen-reader-text"><?php esc_html_e('Menu', 'quicksilver-construction'); ?></span>
        </button>

        <nav id="primary-menu" class="site-nav" aria-label="<?php esc_attr_e('Primary navigation', 'quicksilver-construction'); ?>">
            <ul class="site-nav__list">
                <?php foreach (qsc_navigation_items() as $item) : ?>
                    <li>
                        <a href="<?php echo esc_url(qsc_url_for_page_key($item['pageKey'])); ?>">
                            <?php echo esc_html($item['label']); ?>
                        </a>
                    </li>
                <?php endforeach; ?>
            </ul>
        </nav>

        <?php qsc_render_cta($primaryCta, 'quote-link'); ?>
    </div>
</header>
