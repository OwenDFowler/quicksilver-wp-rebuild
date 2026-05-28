(function () {
    'use strict';

    var header = document.querySelector('.site-header');
    var menuToggle = document.querySelector('.menu-toggle');
    var menu = document.getElementById('primary-menu');
    var hero = document.querySelector('[data-hero-slider]');
    var reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    function setHeaderState() {
        if (!header) {
            return;
        }

        header.classList.toggle('is-stuck', window.scrollY > 8);
    }

    function closeMenu() {
        if (!menuToggle || !menu) {
            return;
        }

        menuToggle.setAttribute('aria-expanded', 'false');
        menu.classList.remove('is-open');
    }

    function bindMenu() {
        if (!menuToggle || !menu) {
            return;
        }

        menuToggle.addEventListener('click', function () {
            var isOpen = menuToggle.getAttribute('aria-expanded') === 'true';
            menuToggle.setAttribute('aria-expanded', String(!isOpen));
            menu.classList.toggle('is-open', !isOpen);
        });

        menu.addEventListener('click', function (event) {
            if (event.target.closest('a')) {
                closeMenu();
            }
        });

        document.addEventListener('keydown', function (event) {
            if (event.key === 'Escape') {
                closeMenu();
            }
        });
    }

    function bindHero() {
        if (!hero || reduceMotion) {
            return;
        }

        var slides = Array.prototype.slice.call(hero.querySelectorAll('.hero__image'));
        if (slides.length < 2) {
            return;
        }

        var current = 0;
        window.setInterval(function () {
            slides[current].classList.remove('is-active');
            current = (current + 1) % slides.length;
            slides[current].classList.add('is-active');
        }, 5200);
    }

    function bindReveals() {
        var items = Array.prototype.slice.call(document.querySelectorAll('.reveal'));
        if (!items.length) {
            return;
        }

        if (reduceMotion || !('IntersectionObserver' in window)) {
            items.forEach(function (item) {
                item.classList.add('is-visible');
            });
            return;
        }

        var observer = new IntersectionObserver(function (entries) {
            entries.forEach(function (entry) {
                if (entry.isIntersecting) {
                    entry.target.classList.add('is-visible');
                    observer.unobserve(entry.target);
                }
            });
        }, { threshold: 0.14 });

        items.forEach(function (item) {
            observer.observe(item);
        });
    }

    bindMenu();
    bindHero();
    bindReveals();
    setHeaderState();
    window.addEventListener('scroll', setHeaderState, { passive: true });
}());
