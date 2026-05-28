<?php

get_header();

$homePage = qsc_home_page();
$sections = qsc_required($homePage, 'sections');
$heroImages = qsc_home_hero_assets();
$overviewImage = qsc_home_visual_asset(0);
$ctaImage = qsc_home_visual_asset(1);
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
                    <p class="eyebrow"><?php esc_html_e('Whidbey Island Construction', 'quicksilver-construction'); ?></p>
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
            <section class="section section--split reveal">
                <div class="section__media">
                    <?php qsc_render_image($overviewImage, 'section__image'); ?>
                </div>
                <div class="section__content">
                    <?php qsc_render_section_text($section); ?>
                    <ul class="check-list">
                        <?php foreach (qsc_required($section, 'items') as $item) : ?>
                            <li><?php echo esc_html($item); ?></li>
                        <?php endforeach; ?>
                    </ul>
                </div>
            </section>
        <?php elseif ($type === 'card-grid') : ?>
            <section class="section reveal">
                <div class="section__intro">
                    <h2><?php echo esc_html(qsc_required($section, 'heading')); ?></h2>
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
                    <article>
                        <span><?php echo esc_html(str_pad((string) ($index + 1), 2, '0', STR_PAD_LEFT)); ?></span>
                        <h3><?php echo esc_html(qsc_required($item, 'title')); ?></h3>
                        <p><?php echo esc_html(qsc_required($item, 'body')); ?></p>
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
                <div class="project-cta__image">
                    <?php qsc_render_image($ctaImage, 'section__image'); ?>
                </div>
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
