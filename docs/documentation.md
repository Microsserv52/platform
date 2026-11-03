---
icon: lucide/book-open
---

# Documentation

This documentation is built using [Zensical](https://zensical.org/), a static site generator for documentation. It uses Markdown files to generate a static website with a clean and modern design.

For full documentation visit [zensical.org](https://zensical.org/docs/).

The content in this site is split into project guidance and service reference
pages. Service pages describe both the exercise contract and the implementation
status visible in this repository; they do not imply that an absent submodule
has already been implemented.

## Commands

* [`zensical new`][new] - Create a new project
* [`zensical serve`][serve] - Start local web server
* [`zensical build`][build] - Build your site

  [new]: https://zensical.org/docs/usage/new/
  [serve]: https://zensical.org/docs/usage/preview/
  [build]: https://zensical.org/docs/usage/build/

## Website

It is also possible to view the documentation online at the deployed github page: [https://microsserv52.github.io/platform/](https://microsserv52.github.io/platform/).

## Writing rules

- Keep endpoint examples valid JSON.
- Document authentication and all relevant success and error status codes.
- Link to the owning service and to related cross-service contracts.
- Mark planned behavior explicitly instead of presenting it as implemented.
