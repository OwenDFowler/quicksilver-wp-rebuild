<?php

get_header();
?>

<main id="main-content" class="site-main">
    <section class="hero">
        <div class="hero__content">
            <p class="eyebrow">Whidbey Island Construction</p>
            <h1>Quality Construction Services Built on Craftsmanship and Reliability</h1>
            <p>
                QuickSilver Construction provides dependable residential construction and site services built on
                quality craftsmanship, clear communication, and attention to detail.
            </p>
            <div class="hero__actions">
                <a class="button button--primary" href="<?php echo esc_url(home_url('/contact/')); ?>">Request a Quote</a>
                <a class="button button--secondary" href="<?php echo esc_url(home_url('/projects/')); ?>">View Work</a>
            </div>
        </div>
    </section>

    <section class="service-grid" aria-label="Core services">
        <article>
            <h2>New Construction</h2>
            <p>Residential builds, structural improvements, and custom projects planned for long-term value.</p>
        </article>
        <article>
            <h2>Remodels and Renovations</h2>
            <p>Practical upgrades, repairs, and finish work with clear communication from start to finish.</p>
        </article>
        <article>
            <h2>Concrete and Site Work</h2>
            <p>Groundwork, slabs, grading, and preparation for dependable construction outcomes.</p>
        </article>
    </section>
</main>

<?php
get_footer();
