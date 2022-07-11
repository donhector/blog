---
title: "Moving away from Github Pages to Cloudflare Pages"
description: Some of the reasons why I moved
date: 2022-07-03T01:04:32+02:00
image: marc-olivier-jodoin-NqOInJ-ttqM-unsplash.jpg
hidden: false
comments: true
draft: false
tags: [
    "github",
    "github-pages",
    "github-actions",
    "cloudflare",
    "cloudflare-pages",
    "hugo",
]
categories: [
    "services",
]
links:
  - title: GitHub
    description: GitHub is the world's largest software development platform.
    website: https://github.com
    image: https://github.githubassets.com/images/modules/logos_page/GitHub-Mark.png
  - title: CloudFlare Pages
    description: Cloudflare Pages is a JAMstack platform for frontend developers to collaborate and deploy websites.
    website: https://pages.cloudflare.com/
    image: https://pages.cloudflare.com/resources/logo/logo.svg
---

## Intro

Up until recently I was hosting this [Hugo](https://gohugo.io/) based site using the free web hosting that Github provides to repos. This free hosting is what they call [Github Pages](https://pages.github.com/)

While free is better that nothing, it definitely has its limitations. One being not supporting Hugo based static sites out-of-the-box (I will add more in the [Reasons](#reasons) section)

That was not a big deal and with some work I got everything automatically and successfully built and deployed to *GH Pages*.

Then, since I was working on some [CloudFlare](https://www.cloudflare.com/) stuff (ie: [Zero Trust](https://www.cloudflare.com/products/zero-trust/)) for one of my side projects, I decided to give [CloudFlare Pages](https://pages.cloudflare.com/) a go at hosting my Hugo site, and in the end couldn't be happier with the experience and results.

{{<figure src="drake.jpg" title="GH Pages vs CF Pages">}}

## Reasons

Below are some of the reasons why I ditched *GH Pages* in favour of *CF Pages* for my *Hugo* site.

### No native integration with *Hugo*

- *Github Pages* have native integration for building *Jekyll* sites, but not *Hugo*.

  This means that you don't get auto-magic *Hugo* builds on every commit. You will have to build the site yourself using one of the following ways:

  - Option 1:

    - Build locally on your terminal: ie. `hugo --minify`
    - Commit the contents of the generated *./public*  folder to the *gh-pages* branch.
    - Push the changes

  - Option 2: <-- My preferred, since that's why CI/CD exists in this world!

    - Create a *Github Actions* workflow to build and push the *Hugo* site to the *gh-pages* branch. For example:

```yml
name: GH pages

on:
  push:
    branches:
      - main
  pull_request:
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          submodules: true
          fetch-depth: 0

      - name: Setup Hugo
        uses: peaceiris/actions-hugo@v2
        with:
          hugo-version: latest
          extended: true

      - name: Build
        run: hugo --minify
        env:
          HUGO_BASEURL: ${{ secrets.HUGO_BASEURL }}

      - name: Deploy to GH pages
        uses: peaceiris/actions-gh-pages@v3
        if: ${{ github.ref == 'refs/heads/main' }}
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./public
          cname: ${{ secrets.HUGO_BASEURL }}
```

  ***NOTE:*** One annoying part here was that as soon as you have *Github Pages* enabled in your repo (ie: *Settings -> Pages -> Source `gh-pages` branch*) Github creates an "internal" workflow called `pages-build-deployment` that you as a user, cannot tweak in any way nor delete. That workflow alone does not know how to handle Hugo sites, so it is pretty useless, hence the need of our own workflow to deal with Hugo sites.

  In CF pages you can pick from one of the multiple framework presets, including Hugo.

  {{<figure src="pages_settings_builds_deployments.png"  width="90%" title="Pages Build Configuration">}}

### Simpler custom domain setup

- Setting a custom apex domain for [Github pages](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site) requires adding 4 DNS *A* records pointing to Github's IP addresses (add another 4 *AAAA* if you are into IPv6) to your DNS providers. However, nobody guarantees those IPs will forever be the same...

- Some Github [documentation](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site) mentioned that a CNAME file gets automatically committed to your repo when you set your "Custom domain" in the Github Pages menu. That was not my case. So I had to create that CNAME file "myself" in the root of my `gh-pages` branch. Luckily `peaceiris/actions-gh-pages@v3` github action can take care of creating the file for you.

- Within Github Pages exists the concept of *user* pages, *organization* and *project* pages. Github allocates you the domain `<user>|<organization>.github.io`. If you have a repo named like `<user>|<organization>.github.io` in your account (which BTW, you can only have one as you are logged into just one account/organization), then Github would serve the repo at that domain. This is what they call *user* and *organization* pages. This is ok-ish... But I rather name my repo the way I want (ie. *myproject*) and not being forced to follow the `<user>|<organization>.github.io` convention. Github lets you do that too, name the repo the way you want, but then it won't serve your repo pages at `<user>|<organization>.github.io` but rather at `<user>|<organization>.github.io/myproject`. This is what they call *project* pages and your can have several of those under your `user` or `organization`. Personally I think it would be better if *project* pages were automatically served from a subdomain ie: `myproject.<user>|<organization>.github.io` as it would make things easier from a dns record management perspective, and would remove the need for adding CNAME files in your repos.

- The experience in *CF Pages* is much streamlined, couple of clicks and you are done. Specially if you also use *CloudFlare* as your DNS provider (I use [Porkbun](porkbun.com) as my registrar but then use *CloudFlare* nameservers so I manage all my domain's DNS records from the *CloudFlare* dashboard).

- Redirecting `www` subdomain to your apex domain it's also quite simple in *CloudFlare*.

  - Add an A record with name `www` pointing to `192.0.2.1` with Proxied status (orange cloud)

  - Add an AAAA record with name `www` pointing to `100::` with Proxied status (orange cloud)

  - Add a redirect rule for `www` to go to your `apex`. There are at least 3 ways to do this in CF:

    - Using a `_redirects` [file](https://developers.cloudflare.com/pages/platform/redirects)

    - Using a *Page Rule*. See [docs](https://developers.cloudflare.com/pages/how-to/www-redirect/)

    - Using *Bulk Redirects*. See [docs](https://developers.cloudflare.com/rules/bulk-redirects/)

    Of the 3 methods above, I prefer the *Bulk Redirect* for the following reasons:

    - I can centrally manage redirects for various *CloudFlare* websites in just one place, instead of committing a `_redirects` file in each of my repos.

    - CF only allows 3 free Pages Rules per website. I prefer to use them for more interesting things (ie caching related stuff) rather than burn one rule just to do a simple redirect (Bulk Redirects were explicitly designed to do redirects so they have a much more generous allowance: 5 redirect lists with up to 20 items each, that you can use in up to 15 rules)

    - Bulk Redirects rules can be enriched using expressions to do cools things such redirecting based on Geolocation.

    {{<figure src="dns.png" title="DNS records">}}
    {{<figure src="bulk_redirects.png" title="Bulk Redirects">}}
    {{<figure src="bulk_redirect_list.png" title="Bulk Redirect List">}}
    {{<figure src="bulk_redirect_list_content.png" title="Bulk Redirect List Content">}}

### No analytics

- Github offers nothing in terms of analytics for your published pages. *CloudFlare* Pages offers a "one click" integration with their free Web Analytics (*Account Name -> Analytics -> Web Analytics -> Your website*)

  {{<figure src="pages_settings_general.png" title="Pages Settings General">}}

  {{<figure src="pages_analytics.png" title="Web Analytics">}}

### Not as nice multi-environment setup

- It's much easier to have different environments such as `staging`, `testing`, etc, each mapped to its own branch, with each environment having its own custom dns pointing to it. By default *CF Pages* gives you a DNS record like `<uniqueid>.<projectname>.pages.dev` for every build. In addition, and this is the juicy part, it also gives you a DNS alias such `<projectname>.pages.dev` for what you decide is your production branch, and `<branch>.<projectname>.pages.dev` for any other branches in your repo. Then, using the `Custom domains` tab of your Pages `projectname` you can, with a couple clicks, assign a custom domain to your branch aliases (production or non-production):

  - Production environment (`main` branch of my repo):

      Custom domain -> CloudFlare created branch alias

      *example.com -> myproject.pages.dev*

  - Staging environment (`staging` branch of my repo):

      Custom domain -> CloudFlare created branch alias

      *staging.example.com -> staging.myproject.pages.dev*

    See [documentation](https://developers.cloudflare.com/pages/how-to/custom-branch-aliases/)

  {{<figure src="pages.png" title="Pages dashboard">}}
  {{<figure src="pages_custom_domains.png" title="Pages Custom Domains">}}
  {{<figure src="pages_env_vars.png" title="Pages Environment Variables">}}

### Not as nice build/deploy feedback

- Github considers your Github Pages as the `github-pages` *Environment*, and it will show in the right hand side of your repo's landing page whether the environment is Green or not. Additionally, since you'd be using a custom actions workflow like the one I posted earlier, it can report the workflow outcome as 'status check' on your pull requests.

- *CloudFlare*'s Pages does not create an Environment in Github, it instead reports feedback in the form of comments to your Pull Requests in Github. Additionally in the *CloudFlare* Pages website, it keeps a detailed history of all your deployments, their status and build logs.

  {{<figure src="pages_github_integration.png" title="Pages Github Integration">}}
  {{<figure src="pages_deployments.png" title="Pages Deployments">}}
  {{<figure src="pages_build_log.png" title="Pages Build Logs">}}

## Closing

I was quite pleased with the *CF Pages* experience and features. *CF Pages* adapted easily to my Hugo project, whereas in *GH Pages* it was my project that needed to adapt.

Thanks to integrations with other *CloudFlare* services such as Web Analytics, DNS, and Bulk Redirects, you have a holistic way to manage you site.

All in all, I'm pretty happy with the move. In addition you get nice PR comments in Github when your site is built and deployed.

If you are new to *CloudFlare* give them a try. The amount of value you can get from *CloudFlare*'s free services is simply amazing, and you don't even need a credit card to start using them. So zero billing surprises, not like in [AWS](https://www.lastweekinaws.com/blog/its-time-to-rethink-the-aws-free-tier/).
