<?php

get_header();

$homePage = qsc_home_page();
$sections = qsc_required($homePage, 'sections');
$heroImages = qsc_home_hero_assets();
$qualityPrimaryImage = qsc_home_still_asset('qualityPrimary');
$qualityInsetImage = qsc_home_still_asset('qualityInset');
$ctaImage = qsc_home_still_asset('ctaBackground');
?>

<main id="main-content" class="site-main">
    <?php foreach ($sections as $section) : ?>
        <?php
        $type = qsc_required($section, 'type');
        ?>

        <?php if ($type === 'hero') : ?>
            <section class="hero" data-hero-slider>
                <div class="hero__images" aria-hidden="true">
                    <?php foreach ($heroImages as $index => $asset) : ?>
                        <img
                            class="hero__image<?php echo $index === 0 ? ' is-active' : ''; ?>"
                            src="<?php echo esc_url(qsc_asset_url($asset)); ?>"
                            width="<?php echo esc_attr((string) qsc_asset_width($asset)); ?>"
                            height="<?php echo esc_attr((string) qsc_asset_height($asset)); ?>"
                            alt=""
                            loading="<?php echo $index === 0 ? 'eager' : 'lazy'; ?>"
                        >
                    <?php endforeach; ?>
                </div>
                <div class="hero__content reveal">
                    <h1><?php echo esc_html(qsc_required($section, 'heading')); ?></h1>
                    <p><?php echo esc_html(qsc_required($section, 'body')); ?></p>
                    <div class="hero__actions">
                        <?php foreach (qsc_required($section, 'ctas') as $cta) : ?>
                            <?php qsc_render_cta($cta, 'button button--primary'); ?>
                        <?php endforeach; ?>
                    </div>
                </div>
            </section>
        <?php elseif ($type === 'image-text') : ?>
            <section class="section section--quality reveal">
                <div class="quality-media">
                    <?php qsc_render_image($qualityPrimaryImage, 'quality-media__primary'); ?>
                </div>
                <div class="section__content quality-copy">
                    <?php qsc_render_section_text($section); ?>
                    <ul class="check-list">
                        <?php foreach (qsc_required($section, 'items') as $item) : ?>
                            <li><?php echo esc_html($item); ?></li>
                        <?php endforeach; ?>
                    </ul>
                    <?php qsc_render_image($qualityInsetImage, 'quality-media__inset'); ?>
                </div>
            </section>
        <?php elseif ($type === 'card-grid') : ?>
            <section class="section section--services reveal">
                <div class="section__intro">
                    <?php qsc_render_section_text($section); ?>
                </div>
                <div class="card-grid">
                    <?php foreach (qsc_required($section, 'items') as $item) : ?>
                        <article class="service-card">
                            <span class="service-card__marker"></span>
                            <h3><?php echo esc_html(qsc_required($item, 'title')); ?></h3>
                            <p><?php echo esc_html(qsc_required($item, 'body')); ?></p>
                        </article>
                    <?php endforeach; ?>
                </div>
            </section>
        <?php elseif ($type === 'values-band') : ?>
            <section class="values-band reveal" aria-label="<?php esc_attr_e('QuickSilver values', 'quicksilver-construction'); ?>">
                <?php foreach (qsc_required($section, 'items') as $index => $item) : ?>
                    <?php
                    $valueTitle = qsc_required($item, 'title');
                    $mediaSlotKey = qsc_required($item, 'mediaSlotKey');
                    if (!is_string($mediaSlotKey) || $mediaSlotKey === '') {
                        throw new RuntimeException('QuickSilver values item mediaSlotKey must be a non-empty string.');
                    }

                    $valueImage = qsc_home_value_asset($mediaSlotKey);
                    ?>
                    <article
                        class="values-panel<?php echo $index === 0 ? ' is-default' : ''; ?>"
                        tabindex="0"
                        aria-label="<?php echo esc_attr($valueTitle); ?>"
                    >
                        <?php qsc_render_decorative_image($valueImage, 'values-panel__image'); ?>
                        <div class="values-panel__content">
                            <span><?php echo esc_html(str_pad((string) ($index + 1), 2, '0', STR_PAD_LEFT)); ?></span>
                            <h3><?php echo esc_html($valueTitle); ?></h3>
                            <p><?php echo esc_html(qsc_required($item, 'body')); ?></p>
                        </div>
                    </article>
                <?php endforeach; ?>
            </section>
        <?php elseif ($type === 'text-feature') : ?>
            <section class="section section--feature reveal">
                <div>
                    <p class="eyebrow"><?php esc_html_e('Reliable Local Workmanship', 'quicksilver-construction'); ?></p>
                    <?php qsc_render_section_text($section); ?>
                </div>
            </section>
        <?php elseif ($type === 'image-cta') : ?>
            <section class="project-cta reveal">
                <?php qsc_render_decorative_image($ctaImage, 'project-cta__background'); ?>
                <div class="project-cta__content">
                    <?php qsc_render_section_text($section); ?>
                    <div class="hero__actions">
                        <?php foreach (qsc_required($section, 'ctas') as $cta) : ?>
                            <?php qsc_render_cta($cta, 'button button--primary'); ?>
                        <?php endforeach; ?>
                    </div>
                </div>
            </section>
        <?php elseif ($type === 'license-banner') : ?>
            <section class="license-banner">
                <p><?php echo esc_html(qsc_required($section, 'text')); ?></p>
            </section>
        <?php else : ?>
            <?php throw new RuntimeException("Unsupported QuickSilver homepage section type: $type"); ?>
        <?php endif; ?>
    <?php endforeach; ?>
</main>

<?php
get_footer();
