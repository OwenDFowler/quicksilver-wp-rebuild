<?php
$identity = qsc_site_identity();
$phone = qsc_required($identity, 'phone');
$email = qsc_required($identity, 'email');
$address = qsc_required($identity, 'mailingAddress');
$logo = qsc_logo_asset();
?>

<footer class="site-footer">
    <div class="site-footer__inner">
        <div class="site-footer__brand">
            <img
                class="site-footer__logo"
                src="<?php echo esc_url(qsc_asset_url($logo)); ?>"
                width="<?php echo esc_attr((string) qsc_asset_width($logo)); ?>"
                height="<?php echo esc_attr((string) qsc_asset_height($logo)); ?>"
                alt="<?php echo esc_attr(qsc_asset_alt($logo)); ?>"
                loading="lazy"
            >
            <p><?php echo esc_html(qsc_required($identity, 'footerSummary')); ?></p>
        </div>

        <nav class="site-footer__nav" aria-label="<?php esc_attr_e('Footer navigation', 'quicksilver-construction'); ?>">
            <?php foreach (qsc_navigation_items() as $item) : ?>
                <a href="<?php echo esc_url(qsc_url_for_page_key($item['pageKey'])); ?>"><?php echo esc_html($item['label']); ?></a>
            <?php endforeach; ?>
        </nav>

        <address class="site-footer__contact">
            <span><?php echo esc_html($address['line1']); ?></span>
            <span><?php echo esc_html($address['cityStateZip']); ?></span>
            <a href="<?php echo esc_url($phone['href']); ?>"><?php echo esc_html($phone['display']); ?></a>
            <a href="<?php echo esc_url($email['href']); ?>"><?php echo esc_html($email['display']); ?></a>
        </address>
    </div>

    <div class="site-footer__legal">
        <?php echo esc_html(qsc_required($identity, 'copyrightText')); ?>
    </div>
</footer>

<?php wp_footer(); ?>
</body>
</html>
